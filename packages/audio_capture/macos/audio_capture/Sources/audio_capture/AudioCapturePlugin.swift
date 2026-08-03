import AVFoundation
import Cocoa
import FlutterMacOS

public final class AudioCapturePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let capture = MacOSAudioCapture()
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AudioCapturePlugin()
    let methods = FlutterMethodChannel(name: "audio_capture", binaryMessenger: registrar.messenger)
    let events = FlutterEventChannel(name: "audio_capture/events", binaryMessenger: registrar.messenger)
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
      do {
        let availability = try capture.start()
        result([
          "systemAudioAvailable": availability.systemAudio,
          "microphoneAvailable": availability.microphone,
          "degradationReason": availability.degradationReason ?? NSNull()
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
      do { result(try capture.stop().path) }
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
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
        NSWorkspace.shared.open(url)
      }
      result(nil)
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
}
