import Foundation

/// Errors surfaced by macOS native recording. Kept dependency-free (no
/// AVFoundation) so the classification and every message can be exercised by a
/// standalone `swiftc` test on CI (Loop 9 R-08 hardening).
enum MacAudioError: LocalizedError {
  case alreadyRunning
  case notRunning
  case microphoneUnavailable
  case systemAudioUnavailable(OSStatus)

  var errorDescription: String? {
    switch self {
    case .alreadyRunning: return "录音已经开始。"
    case .notRunning: return "当前没有正在进行的录音。"
    case .microphoneUnavailable: return "麦克风不可用，请检查权限和输入设备。"
    case .systemAudioUnavailable: return "系统声音采集不可用。"
    }
  }
}

/// A lock-protected float sample ring buffer that bridges the system-audio
/// process tap (which delivers on a realtime audio thread) to the
/// `AVAudioSourceNode` consumer. When the consumer cannot keep up it drops the
/// oldest samples rather than ever blocking the audio thread.
final class AudioRingBuffer {
  var capacity: Int { storage.count }
  private var storage: [Float]
  private var writeIndex = 0
  private var readIndex = 0
  private var available = 0
  private let lock = NSLock()

  init(capacity: Int = 96_000) {
    storage = [Float](repeating: 0, count: capacity)
  }

  func write(_ samples: UnsafePointer<Float>, count: Int) {
    lock.lock(); defer { lock.unlock() }
    guard storage.count > 0 else { return }
    for index in 0..<count {
      storage[writeIndex] = samples[index]
      writeIndex = (writeIndex + 1) % storage.count
      if available == storage.count { readIndex = (readIndex + 1) % storage.count }
      else { available += 1 }
    }
  }

  func read(into output: UnsafeMutablePointer<Float>, count: Int) {
    lock.lock(); defer { lock.unlock() }
    let amount = min(count, available)
    for index in 0..<amount {
      output[index] = storage[readIndex]
      readIndex = (readIndex + 1) % storage.count
    }
    available -= amount
    if amount < count { for index in amount..<count { output[index] = 0 } }
  }

  func reset() {
    lock.lock(); writeIndex = 0; readIndex = 0; available = 0; lock.unlock()
  }
}

/// RMS amplitude helpers for the two level meters. `rms` is pure; the
/// AVAudioPCMBuffer wrapper lives beside the capture class that owns the taps.
enum AudioMeter {
  static func rms(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    return min(1, sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)))
  }
}

/// Accumulates low-level audio and flips `silent` only after a sustained quiet
/// run, so a single lull does not flicker the mute state. Returns a value only
/// when the silent state *changes* (used to avoid noisy re-emits).
final class SilenceDetector {
  private var accumulation = 0.0
  private var silent = false

  func update(level: Float, seconds: Double) -> Bool? {
    if level < 0.005 {
      accumulation += seconds
      if !silent && accumulation >= 2.5 { silent = true; return true }
    } else {
      accumulation = 0
      if silent { silent = false; return false }
    }
    return nil
  }

  func reset() { accumulation = 0; silent = false }
}