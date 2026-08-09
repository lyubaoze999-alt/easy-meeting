#include "audio_capture_plugin.h"

#include "drift_mixer.h"

#include <windows.h>

#include <mmdeviceapi.h>
#include <audioclient.h>
#include <ks.h>
#include <ksmedia.h>
#include <shellapi.h>

#include <algorithm>
#include <atomic>
#include <cmath>
#include <condition_variable>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <filesystem>
#include <fstream>
#include <future>
#include <functional>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

namespace audio_capture {
namespace {

constexpr UINT kAudioEventMessage = WM_APP + 0x4A1;
constexpr uint32_t kOutputSampleRate = 16000;

struct EventPayload {
  std::string type;
  flutter::EncodableValue value;
};

struct StartResult {
  bool microphone = false;
  bool system = false;
  std::string error;
};

std::string HResultMessage(HRESULT value) {
  char buffer[32];
  std::snprintf(buffer, sizeof(buffer), "Windows audio error 0x%08lx",
                static_cast<unsigned long>(value));
  return buffer;
}

std::string Utf8(const std::wstring& value) {
  if (value.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                       static_cast<int>(value.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string result(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.data(), static_cast<int>(value.size()),
                      result.data(), size, nullptr, nullptr);
  return result;
}

void WriteUint16(std::fstream& file, uint16_t value) {
  file.write(reinterpret_cast<const char*>(&value), sizeof(value));
}

void WriteUint32(std::fstream& file, uint32_t value) {
  file.write(reinterpret_cast<const char*>(&value), sizeof(value));
}

void WriteWavHeader(std::fstream& file, uint32_t data_length) {
  file.seekp(0);
  file.write("RIFF", 4);
  WriteUint32(file, 36 + data_length);
  file.write("WAVEfmt ", 8);
  WriteUint32(file, 16);
  WriteUint16(file, 1);
  WriteUint16(file, 1);
  WriteUint32(file, kOutputSampleRate);
  WriteUint32(file, kOutputSampleRate * 2);
  WriteUint16(file, 2);
  WriteUint16(file, 16);
  file.write("data", 4);
  WriteUint32(file, data_length);
}

// Reads the Windows microphone privacy consent from
// HKCU\...\CapabilityAccessManager\ConsentStore\microphone\Value.
// Returns true when the user has explicitly allowed microphone access, and
// false for Deny / Unspecified / missing key. This is the authoritative,
// non-hardcoded source (the previous implementation unconditionally reported
// granted=true, which the Loop 3 contract flags as a P1).
bool CheckMicrophonePermission() {
  const wchar_t* consent_path =
      L"Software\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\"
      L"ConsentStore\\microphone";
  HKEY key = nullptr;
  const LONG open =
      RegOpenKeyExW(HKEY_CURRENT_USER, consent_path, 0, KEY_READ, &key);
  if (open != ERROR_SUCCESS) {
    return false;
  }
  wchar_t value[64] = {0};
  DWORD size = sizeof(value);
  const LONG query = RegQueryValueExW(key, L"Value", nullptr, nullptr,
                                      reinterpret_cast<LPBYTE>(value), &size);
  RegCloseKey(key);
  if (query != ERROR_SUCCESS) {
    return false;
  }
  return wcscmp(value, L"Allow") == 0;
}

class CaptureSource {
 public:
  ~CaptureSource() { Reset(); }

  void Reset() {
    if (capture) capture->Release();
    if (client) client->Release();
    if (device) device->Release();
    if (format) CoTaskMemFree(format);
    capture = nullptr;
    client = nullptr;
    device = nullptr;
    format = nullptr;
  }

  IMMDevice* device = nullptr;
  IAudioClient* client = nullptr;
  IAudioCaptureClient* capture = nullptr;
  WAVEFORMATEX* format = nullptr;
};

HRESULT OpenSource(IMMDeviceEnumerator* enumerator, EDataFlow flow,
                   ERole role, bool loopback, CaptureSource* source) {
  HRESULT hr = enumerator->GetDefaultAudioEndpoint(flow, role, &source->device);
  if (FAILED(hr)) return hr;
  hr = source->device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, nullptr,
                                reinterpret_cast<void**>(&source->client));
  if (FAILED(hr)) return hr;
  hr = source->client->GetMixFormat(&source->format);
  if (FAILED(hr)) return hr;
  const DWORD flags = loopback ? AUDCLNT_STREAMFLAGS_LOOPBACK : 0;
  hr = source->client->Initialize(AUDCLNT_SHAREMODE_SHARED, flags, 1000000, 0,
                                  source->format, nullptr);
  if (FAILED(hr)) return hr;
  return source->client->GetService(
      __uuidof(IAudioCaptureClient),
      reinterpret_cast<void**>(&source->capture));
}

bool IsFloat(const WAVEFORMATEX* format) {
  if (format->wFormatTag == WAVE_FORMAT_IEEE_FLOAT) return true;
  if (format->wFormatTag != WAVE_FORMAT_EXTENSIBLE) return false;
  const auto* extensible = reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(format);
  return extensible->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT;
}

std::vector<int16_t> ConvertToMono16(const BYTE* data, UINT32 frames,
                                     DWORD flags,
                                     const WAVEFORMATEX* format) {
  const uint32_t channels = std::max<uint32_t>(1, format->nChannels);
  const uint32_t source_rate = std::max<uint32_t>(1, format->nSamplesPerSec);
  const size_t output_frames = std::max<size_t>(
      1, static_cast<size_t>(frames) * kOutputSampleRate / source_rate);
  std::vector<int16_t> output(output_frames, 0);
  if ((flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0 || data == nullptr) return output;
  const bool floating = IsFloat(format);
  const uint16_t bits = format->wBitsPerSample;
  for (size_t out = 0; out < output_frames; ++out) {
    const size_t frame = std::min<size_t>(
        frames - 1, out * static_cast<size_t>(source_rate) / kOutputSampleRate);
    double mixed = 0;
    for (uint32_t channel = 0; channel < channels; ++channel) {
      const size_t index = frame * channels + channel;
      if (floating && bits == 32) {
        mixed += reinterpret_cast<const float*>(data)[index];
      } else if (bits == 16) {
        mixed += reinterpret_cast<const int16_t*>(data)[index] / 32768.0;
      } else if (bits == 32) {
        mixed += reinterpret_cast<const int32_t*>(data)[index] / 2147483648.0;
      }
    }
    mixed = std::clamp(mixed / channels, -1.0, 1.0);
    output[out] = static_cast<int16_t>(mixed * 32767.0);
  }
  return output;
}

double Level(const std::vector<int16_t>& values) {
  if (values.empty()) return 0;
  double sum = 0;
  for (const auto value : values) {
    const double normalized = value / 32768.0;
    sum += normalized * normalized;
  }
  return std::min(
      1.0, std::sqrt(sum / static_cast<double>(values.size())));
}

}  // namespace

class WasapiRecorder {
 public:
  explicit WasapiRecorder(std::function<void(std::string, flutter::EncodableValue)> emit)
      : emit_(std::move(emit)) {}

  ~WasapiRecorder() { Stop(); }

  StartResult Start() {
    if (active_) return {false, false, "录音已经开始。"};
    wchar_t temp[MAX_PATH];
    if (GetTempPathW(MAX_PATH, temp) == 0) {
      return {false, false, "无法创建录音目录。"};
    }
    const auto directory = std::filesystem::path(temp) / L"EasyMeetingRecordings";
    std::filesystem::create_directories(directory);
    output_path_ = directory / (std::to_wstring(GetTickCount64()) + L".wav");
    output_.open(output_path_, std::ios::binary | std::ios::in |
                                   std::ios::out | std::ios::trunc);
    if (!output_) return {false, false, "无法创建录音文件。"};
    WriteWavHeader(output_, 0);
    data_length_ = 0;
    microphone_silent_seconds_ = 0;
    system_silent_seconds_ = 0;
    microphone_silent_ = false;
    system_silent_ = false;
    microphone_queue_.clear();
    system_queue_.clear();
    drift_mixer_.Reset();
    active_ = true;
    writing_ = true;
    std::promise<StartResult> promise;
    auto future = promise.get_future();
    capture_thread_ = std::thread([this, promise = std::move(promise)]() mutable {
      CaptureLoop(std::move(promise));
    });
    const auto result = future.get();
    if (!result.microphone) {
      active_ = false;
      if (capture_thread_.joinable()) capture_thread_.join();
      output_.close();
      return result;
    }
    writer_thread_ = std::thread([this] { WriterLoop(); });
    emit_("systemSilent", flutter::EncodableValue(!result.system));
    emit_("microphoneSilent", flutter::EncodableValue(false));
    return result;
  }

  void Pause() { writing_ = false; }
  void Resume() { if (active_) writing_ = true; }

  std::string Stop() {
    if (!active_) return Utf8(output_path_.wstring());
    writing_ = false;
    active_ = false;
    queue_ready_.notify_all();
    if (capture_thread_.joinable()) capture_thread_.join();
    if (writer_thread_.joinable()) writer_thread_.join();
    WriteWavHeader(output_, data_length_);
    output_.flush();
    output_.close();
    return Utf8(output_path_.wstring());
  }

 private:
  void CaptureLoop(std::promise<StartResult> promise) {
    const HRESULT com = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    IMMDeviceEnumerator* enumerator = nullptr;
    HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                  CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                  reinterpret_cast<void**>(&enumerator));
    if (FAILED(hr)) {
      promise.set_value({false, false, HResultMessage(hr)});
      if (SUCCEEDED(com)) CoUninitialize();
      return;
    }
    CaptureSource microphone;
    CaptureSource system_audio;
    hr = OpenSource(enumerator, eCapture, eCommunications, false, &microphone);
    if (FAILED(hr)) {
      enumerator->Release();
      promise.set_value({false, false, "麦克风不可用，请检查 Windows 隐私设置。"});
      microphone.Reset();
      system_audio.Reset();
      if (SUCCEEDED(com)) CoUninitialize();
      return;
    }
    bool has_system =
        SUCCEEDED(OpenSource(enumerator, eRender, eConsole, true,
                             &system_audio));
    enumerator->Release();
    hr = microphone.client->Start();
    if (FAILED(hr)) {
      promise.set_value({false, false, "麦克风启动失败，请检查输入设备。"});
      microphone.Reset();
      system_audio.Reset();
      if (SUCCEEDED(com)) CoUninitialize();
      return;
    }
    if (has_system && FAILED(system_audio.client->Start())) {
      system_audio.Reset();
      has_system = false;
    }
    promise.set_value({true, has_system, {}});
    while (active_) {
      Drain(&microphone, &microphone_queue_, "microphone");
      if (has_system) Drain(&system_audio, &system_queue_, "system");
      Sleep(8);
    }
    microphone.client->Stop();
    if (has_system) system_audio.client->Stop();
    microphone.Reset();
    system_audio.Reset();
    if (SUCCEEDED(com)) CoUninitialize();
  }

  void Drain(CaptureSource* source, std::deque<std::vector<int16_t>>* queue,
             const char* name) {
    UINT32 packet = 0;
    while (SUCCEEDED(source->capture->GetNextPacketSize(&packet)) && packet > 0) {
      BYTE* data = nullptr;
      UINT32 frames = 0;
      DWORD flags = 0;
      if (FAILED(source->capture->GetBuffer(&data, &frames, &flags, nullptr,
                                            nullptr))) return;
      auto converted = ConvertToMono16(data, frames, flags, source->format);
      source->capture->ReleaseBuffer(frames);
      const double level = Level(converted);
      emit_(std::string(name) + "Level", flutter::EncodableValue(level));
      UpdateSilence(name, level,
                    static_cast<double>(converted.size()) / kOutputSampleRate);
      {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        if (queue->size() >= 64) queue->pop_front();
        queue->push_back(std::move(converted));
      }
      queue_ready_.notify_one();
    }
  }

  void UpdateSilence(const std::string& name, double level, double seconds) {
    double* accumulation = name == "system" ? &system_silent_seconds_
                                             : &microphone_silent_seconds_;
    bool* silent = name == "system" ? &system_silent_ : &microphone_silent_;
    if (level < 0.005) {
      *accumulation += seconds;
      if (!*silent && *accumulation >= 2.5) {
        *silent = true;
        emit_(name + "Silent", flutter::EncodableValue(true));
      }
    } else {
      *accumulation = 0;
      if (*silent) {
        *silent = false;
        emit_(name + "Silent", flutter::EncodableValue(false));
      }
    }
  }

  void WriterLoop() {
    while (active_ || !microphone_queue_.empty()) {
      std::vector<int16_t> microphone;
      std::vector<int16_t> system_audio;
      {
        std::unique_lock<std::mutex> lock(queue_mutex_);
        queue_ready_.wait_for(lock, std::chrono::milliseconds(250), [this] {
          return !active_ || !microphone_queue_.empty();
        });
        if (microphone_queue_.empty()) continue;
        microphone = std::move(microphone_queue_.front());
        microphone_queue_.pop_front();
        // Drain every system block that has arrived so the drift mixer can
        // resample the system stream onto the mic timeline rather than pairing
        // one FIFO block against one mic block (which drifts over 45 min).
        while (!system_queue_.empty()) {
          auto block = std::move(system_queue_.front());
          system_queue_.pop_front();
          system_audio.insert(system_audio.end(), block.begin(), block.end());
        }
      }
      if (!writing_) continue;
      std::vector<int16_t> mixed;
      drift_mixer_.Mix(microphone, system_audio, &mixed);
      for (const int16_t output : mixed) {
        output_.write(reinterpret_cast<const char*>(&output), sizeof(output));
        data_length_ += static_cast<uint32_t>(sizeof(output));
      }
    }
  }

  std::function<void(std::string, flutter::EncodableValue)> emit_;
  std::atomic<bool> active_{false};
  std::atomic<bool> writing_{false};
  std::thread capture_thread_;
  std::thread writer_thread_;
  std::mutex queue_mutex_;
  std::condition_variable queue_ready_;
  std::deque<std::vector<int16_t>> microphone_queue_;
  std::deque<std::vector<int16_t>> system_queue_;
  DriftMixer drift_mixer_;
  std::filesystem::path output_path_;
  std::fstream output_;
  uint32_t data_length_ = 0;
  double microphone_silent_seconds_ = 0;
  double system_silent_seconds_ = 0;
  bool microphone_silent_ = false;
  bool system_silent_ = false;
};

void AudioCapturePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto methods = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "audio_capture",
      &flutter::StandardMethodCodec::GetInstance());
  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      registrar->messenger(), "audio_capture/events",
      &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<AudioCapturePlugin>(registrar);
  methods->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });
  event_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<>>(
          [plugin_pointer = plugin.get()](const auto* arguments, auto sink) {
            return plugin_pointer->OnListen(arguments, std::move(sink));
          },
          [plugin_pointer = plugin.get()](const auto* arguments) {
            return plugin_pointer->OnCancel(arguments);
          }));
  registrar->AddPlugin(std::move(plugin));
}

AudioCapturePlugin::AudioCapturePlugin(
    flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  if (registrar_) {
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleWindowProc(hwnd, message, wparam, lparam);
        });
  }
}

AudioCapturePlugin::~AudioCapturePlugin() {
  if (recorder_) recorder_->Stop();
  if (registrar_ && window_proc_id_ >= 0) {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
  }
}

void AudioCapturePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "start") {
    recorder_ = std::make_unique<WasapiRecorder>(
        [this](std::string type, flutter::EncodableValue value) {
          auto* payload = new EventPayload{std::move(type), std::move(value)};
          PostMessage(registrar_->GetView()->GetNativeWindow(),
                      kAudioEventMessage, 0,
                      reinterpret_cast<LPARAM>(payload));
        });
    const auto started = recorder_->Start();
    if (!started.microphone) {
      recorder_.reset();
      result->Error("start_failed", started.error);
      return;
    }
    flutter::EncodableMap value;
    value[flutter::EncodableValue("systemAudioAvailable")] =
        flutter::EncodableValue(started.system);
    value[flutter::EncodableValue("microphoneAvailable")] =
        flutter::EncodableValue(true);
    value[flutter::EncodableValue("degradationReason")] = started.system
        ? flutter::EncodableValue()
        : flutter::EncodableValue(
              "系统声音不可用，本次仅记录麦克风。");
    result->Success(flutter::EncodableValue(value));
  } else if (call.method_name() == "pause") {
    if (recorder_) recorder_->Pause();
    result->Success();
  } else if (call.method_name() == "resume") {
    if (recorder_) recorder_->Resume();
    result->Success();
  } else if (call.method_name() == "stop") {
    if (!recorder_) {
      result->Error("not_running", "当前没有正在进行的录音。");
      return;
    }
    const auto path = recorder_->Stop();
    recorder_.reset();
    result->Success(flutter::EncodableValue(path));
  } else if (call.method_name() == "permissionStatus") {
    // WASAPI loopback (system audio) capture on modern Windows is gated by the
    // same user microphone privacy consent, so the two report the same truth.
    const bool mic = CheckMicrophonePermission();
    flutter::EncodableMap value;
    value[flutter::EncodableValue("systemAudioGranted")] =
        flutter::EncodableValue(mic);
    value[flutter::EncodableValue("microphoneGranted")] =
        flutter::EncodableValue(mic);
    result->Success(flutter::EncodableValue(value));
  } else if (call.method_name() == "openPermissionSettings") {
    ShellExecuteW(nullptr, L"open", L"ms-settings:privacy-microphone", nullptr,
                  nullptr, SW_SHOWNORMAL);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

std::unique_ptr<flutter::StreamHandlerError<>> AudioCapturePlugin::OnListen(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<>>&& events) {
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<>> AudioCapturePlugin::OnCancel(
    const flutter::EncodableValue* arguments) {
  event_sink_.reset();
  return nullptr;
}

std::optional<LRESULT> AudioCapturePlugin::HandleWindowProc(
    HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  if (message != kAudioEventMessage) return std::nullopt;
  std::unique_ptr<EventPayload> payload(
      reinterpret_cast<EventPayload*>(lparam));
  if (event_sink_ && payload) {
    flutter::EncodableMap event;
    event[flutter::EncodableValue("type")] =
        flutter::EncodableValue(payload->type);
    event[flutter::EncodableValue("value")] = payload->value;
    event_sink_->Success(flutter::EncodableValue(event));
  }
  return 0;
}

}  // namespace audio_capture
