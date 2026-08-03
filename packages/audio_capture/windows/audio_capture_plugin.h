#ifndef FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

namespace audio_capture {

class WasapiRecorder;

class AudioCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  explicit AudioCapturePlugin(flutter::PluginRegistrarWindows* registrar = nullptr);
  ~AudioCapturePlugin() override;

  AudioCapturePlugin(const AudioCapturePlugin&) = delete;
  AudioCapturePlugin& operator=(const AudioCapturePlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  std::unique_ptr<flutter::StreamHandlerError<>> OnListen(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<>>&& events);
  std::unique_ptr<flutter::StreamHandlerError<>> OnCancel(
      const flutter::EncodableValue* arguments);
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message,
                                           WPARAM wparam, LPARAM lparam);

  flutter::PluginRegistrarWindows* registrar_;
  int window_proc_id_ = -1;
  std::unique_ptr<flutter::EventSink<>> event_sink_;
  std::unique_ptr<WasapiRecorder> recorder_;
};

}  // namespace audio_capture

#endif  // FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
