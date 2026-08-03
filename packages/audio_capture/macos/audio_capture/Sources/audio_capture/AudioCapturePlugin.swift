import AVFoundation
import Cocoa
import FlutterMacOS

public final class AudioCapturePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let capture = MacOSAudioCapture()
  private let pcmStreamHandler = PCMStreamHandler()
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioCapturePlugin()
    let methods = FlutterMethodChannel(name: "audio_capture", binaryMessenger: registrar.messenger)
    let events = FlutterEventChannel(name: "audio_capture/events", binaryMessenger: registrar.messenger)
    let pcmEvents = FlutterEventChannel(name: "audio_capture/pcm", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: methods)
    events.setStreamHandler(instance)
    pcmEvents.setStreamHandler(instance.pcmStreamHandler)
  }

  public override init() {
    super.init()
    capture.onEvent = { [weak self] type, value in
      DispatchQueue.main.async { self?.eventSink?(["type": type, "value": value]) }
    }
    capture.onPCMFrame = { [weak self] frame in
      self?.pcmStreamHandler.emit(frame)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      do {
        let availability = try capture.start()
        let degradationReason: Any
        if let reason = availability.degradationReason {
          degradationReason = reason
        } else {
          degradationReason = NSNull()
        }
        result([
          "systemAudioAvailable": availability.systemAudio,
          "microphoneAvailable": availability.microphone,
          "nativeSessionId": availability.sessionId,
          "degradationReason": degradationReason
        ])
      } catch {
        result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
      }
    case "pause":
      capture.pause()
      result(nil)
    case "resume":
      capture.resume()
      result(nil)
    case "stop":
      do {
        let path = try capture.stop().path
        // PCM callbacks were queued first; complete the method on the next
        // main-loop turn so Dart observes the terminal frame before stop().
        DispatchQueue.main.async { result(path) }
      }
      catch { result(FlutterError(code: "stop_failed", message: error.localizedDescription, details: nil)) }
    case "permissionStatus":
      let systemAudioGranted: Bool
      if #available(macOS 14.4, *) {
        systemAudioGranted = CGPreflightScreenCaptureAccess()
      } else {
        systemAudioGranted = false
      }
      result([
        "systemAudioGranted": systemAudioGranted,
        "microphoneGranted": AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
      ])
    case "openPermissionSettings":
      switch call.arguments as? String {
      case "microphone":
        requestMicrophonePermission(result: result)
      default:
        requestSystemAudioPermission(result: result)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func requestSystemAudioPermission(result: @escaping FlutterResult) {
    guard #available(macOS 14.4, *) else {
      result(nil)
      return
    }
    if CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() {
      result(nil)
      return
    }
    openPrivacySettings(pane: "Privacy_ScreenCapture")
    result(nil)
  }

  private func requestMicrophonePermission(result: @escaping FlutterResult) {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      result(nil)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { _ in
        DispatchQueue.main.async { result(nil) }
      }
    case .denied, .restricted:
      openPrivacySettings(pane: "Privacy_Microphone")
      result(nil)
    @unknown default:
      result(nil)
    }
  }

  private func openPrivacySettings(pane: String) {
    guard let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
    ) else { return }
    NSWorkspace.shared.open(url)
  }
}

private final class PCMStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  func emit(_ frame: NativePCMFrame) {
    let payload: [String: Any] = [
      "sessionId": frame.sessionId,
      "sequence": frame.sequence,
      "startSample": frame.startSample,
      "sampleRate": frame.sampleRate,
      "channels": frame.channels,
      "bytes": FlutterStandardTypedData(bytes: frame.bytes)
    ]
    if Thread.isMainThread {
      eventSink?(payload)
    } else {
      DispatchQueue.main.async { [weak self] in self?.eventSink?(payload) }
    }
  }
}
