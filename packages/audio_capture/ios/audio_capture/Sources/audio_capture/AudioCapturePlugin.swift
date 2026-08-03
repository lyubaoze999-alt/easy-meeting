import AVFoundation
import Flutter
import UIKit

public final class AudioCapturePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let capture = IOSAudioCapture()
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioCapturePlugin()
    let methods = FlutterMethodChannel(name: "audio_capture", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(name: "audio_capture/events", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
  }

  public override init() {
    super.init()
    capture.onEvent = { [weak self] type, value in
      DispatchQueue.main.async { self?.eventSink?(["type": type, "value": value]) }
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      requestMicrophoneIfNeeded { [weak self] granted in
        guard let self else { return }
        guard granted else {
          result(FlutterError(code: "microphone_denied", message: "麦克风权限未开启。", details: nil))
          return
        }
        do {
          try self.capture.start()
          result([
            "systemAudioAvailable": false,
            "microphoneAvailable": true,
            "degradationReason": "iPhone 和 iPad 不支持采集其他应用的系统声音，本次仅记录麦克风。"
          ])
        } catch {
          result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
        }
      }
    case "pause":
      capture.pause()
      result(nil)
    case "resume":
      capture.resume()
      result(nil)
    case "stop":
      do { result(try capture.stop().path) }
      catch { result(FlutterError(code: "stop_failed", message: error.localizedDescription, details: nil)) }
    case "permissionStatus":
      result([
        "systemAudioGranted": false,
        "microphoneGranted": AVAudioSession.sharedInstance().recordPermission == .granted
      ])
    case "openPermissionSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func requestMicrophoneIfNeeded(_ completion: @escaping (Bool) -> Void) {
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      completion(true)
    case .denied:
      completion(false)
    case .undetermined:
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async { completion(granted) }
      }
    @unknown default:
      completion(false)
    }
  }
}

private enum IOSAudioError: LocalizedError {
  case alreadyRunning
  case notRunning
  case microphoneUnavailable

  var errorDescription: String? {
    switch self {
    case .alreadyRunning: return "录音已经开始。"
    case .notRunning: return "当前没有正在进行的录音。"
    case .microphoneUnavailable: return "麦克风不可用，请检查权限和输入设备。"
    }
  }
}

private final class IOSAudioCapture {
  var onEvent: ((String, Any) -> Void)?

  private let engine = AVAudioEngine()
  private let fileLock = NSLock()
  private var outputFile: AVAudioFile?
  private var converter: AVAudioConverter?
  private var outputURL: URL?
  private var running = false
  private var writing = false
  private var silenceSeconds = 0.0
  private var silent = false

  func start() throws {
    guard !running else { throw IOSAudioError.alreadyRunning }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(
      .playAndRecord,
      mode: .spokenAudio,
      options: [.defaultToSpeaker, .allowBluetoothHFP]
    )
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let input = engine.inputNode
    let inputFormat = input.inputFormat(forBus: 0)
    guard inputFormat.channelCount > 0 else { throw IOSAudioError.microphoneUnavailable }

    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("EasyMeetingRecordings", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
    outputURL = url
    outputFile = try AVAudioFile(forWriting: url, settings: [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16_000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false
    ])

    input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
      self?.handle(buffer)
    }
    engine.prepare()
    do { try engine.start() }
    catch {
      input.removeTap(onBus: 0)
      outputFile = nil
      try? session.setActive(false, options: .notifyOthersOnDeactivation)
      throw error
    }
    silenceSeconds = 0
    silent = false
    running = true
    writing = true
    onEvent?("systemLevel", Float(0))
    onEvent?("systemSilent", true)
    onEvent?("microphoneSilent", false)
  }

  func pause() { writing = false }
  func resume() { if running { writing = true } }

  func stop() throws -> URL {
    guard running, let outputURL else { throw IOSAudioError.notRunning }
    writing = false
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    outputFile = nil
    converter = nil
    running = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    return outputURL
  }

  private func handle(_ buffer: AVAudioPCMBuffer) {
    let level = rms(buffer)
    onEvent?("microphoneLevel", level)
    let seconds = Double(buffer.frameLength) / max(1, buffer.format.sampleRate)
    if level < 0.005 {
      silenceSeconds += seconds
      if !silent && silenceSeconds >= 2.5 {
        silent = true
        onEvent?("microphoneSilent", true)
      }
    } else {
      silenceSeconds = 0
      if silent {
        silent = false
        onEvent?("microphoneSilent", false)
      }
    }
    guard writing else { return }
    write(buffer)
  }

  private func write(_ buffer: AVAudioPCMBuffer) {
    fileLock.lock()
    defer { fileLock.unlock() }
    guard let file = outputFile else { return }
    let target = file.processingFormat
    guard let activeConverter = converter ?? AVAudioConverter(from: buffer.format, to: target) else { return }
    converter = activeConverter
    let capacity = AVAudioFrameCount(
      Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate
    ) + 1024
    guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
    var supplied = false
    var conversionError: NSError?
    let status = activeConverter.convert(to: output, error: &conversionError) { _, state in
      if supplied {
        state.pointee = .noDataNow
        return nil
      }
      supplied = true
      state.pointee = .haveData
      return buffer
    }
    if status != .error && output.frameLength > 0 { try? file.write(from: output) }
  }

  private func rms(_ buffer: AVAudioPCMBuffer) -> Float {
    guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { return 0 }
    var sum: Float = 0
    let frames = Int(buffer.frameLength)
    for channel in 0..<Int(buffer.format.channelCount) {
      for frame in 0..<frames {
        let sample = channels[channel][frame]
        sum += sample * sample
      }
    }
    return min(1, sqrt(sum / Float(frames * max(1, Int(buffer.format.channelCount)))))
  }
}
