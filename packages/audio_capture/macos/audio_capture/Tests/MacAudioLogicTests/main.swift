import Foundation

/// Loop 9 native hardening unit tests for the dependency-free macOS audio
/// logic (MacAudioLogic.swift). Compiled and run with `swiftc` on CI exactly
/// like PCMFramePumpTests, so the silence detector, ring buffer, level meter
/// and error classification are exercised without needing a physical Mac
/// audio device / microphone permission.
private enum TestFailure: Error, CustomStringConvertible {
  case failed(String)

  var description: String {
    switch self {
    case .failed(let message): return message
    }
  }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  if !condition() { throw TestFailure.failed(message) }
}

private func testErrorClassification() throws {
  try require(MacAudioError.alreadyRunning.errorDescription == "录音已经开始。", "alreadyRunning message")
  try require(MacAudioError.notRunning.errorDescription == "当前没有正在进行的录音。", "notRunning message")
  try require(
    MacAudioError.microphoneUnavailable.errorDescription == "麦克风不可用，请检查权限和输入设备。",
    "microphoneUnavailable message"
  )
  try require(
    MacAudioError.systemAudioUnavailable(0).errorDescription == "系统声音采集不可用。",
    "systemAudioUnavailable message"
  )
}

private func testRingBufferOrderAndOverrun() throws {
  let ring = AudioRingBuffer(capacity: 8)
  var samples: [Float] = [1, 2, 3]
  samples.withUnsafeBufferPointer { ring.write($0.baseAddress!, count: 3) }
  var out = [Float](repeating: 0, count: 8)
  var read = ring.read(into: &out, count: 3)
  try require(out.prefix(3) == [1, 2, 3], "Ring buffer must return samples in order")
  try require(read == 3, "read should consume exactly the written count")

  // Write more than capacity: ring must drop the oldest, not block.
  var burst = [Float](repeating: 9, count: 12)
  burst.withUnsafeBufferPointer { ring.write($0.baseAddress!, count: 12) }
  out = [Float](repeating: 0, count: 12)
  read = ring.read(into: &out, count: 12)
  try require(read == 8, "ring capacity is 8, so only 8 samples should be readable after overrun")
  try require(
    Array(out.prefix(8)) == [9, 9, 9, 9, 9, 9, 9, 9],
    "overrun should keep the newest 8 samples"
  )
  // Reading beyond availability returns zero-fill.
  var tail = [Float](repeating: 1, count: 4)
  _ = ring.read(into: &tail, count: 4)
  try require(tail == [0, 0, 0, 0], "read beyond availability must zero-fill")
}

private func testRingBufferReset() throws {
  let ring = AudioRingBuffer(capacity: 4)
  var samples: [Float] = [5, 6, 7, 8]
  samples.withUnsafeBufferPointer { ring.write($0.baseAddress!, count: 4) }
  ring.reset()
  var out = [Float](repeating: 1, count: 4)
  let read = ring.read(into: &out, count: 4)
  try require(read == 0 && out == [0, 0, 0, 0], "reset must drain the ring")
}

private func testRms() throws {
  try require(AudioMeter.rms([]) == 0, "empty samples -> 0 level")
  try require(AudioMeter.rms([0, 0, 0]) == 0, "silence -> 0 level")
  let fullScale = AudioMeter.rms([1, 1, 1, 1])
  try require(abs(fullScale - 1) < 0.0001, "saturated samples -> 1 level, got \(fullScale)")
  let half = AudioMeter.rms([0.5, 0.5, 0.5, 0.5])
  try require(abs(half - 0.5) < 0.0001, "0.5 constant -> 0.5 rms, got \(half)")
  try require(AudioMeter.rms([-1, 1]) > 0, "rectified rms must be positive")
}

private func testSilenceDetectorHysteresis() throws {
  let detector = SilenceDetector()
  // Below 2.5s of quiet the state does not change.
  try require(detector.update(level: 0.001, seconds: 1.0) == nil, "short quiet must not change state")
  try require(detector.update(level: 0.001, seconds: 1.5) == true, "2.5s quiet must flip to silent")
  // Remaining quiet does not re-emit.
  try require(detector.update(level: 0.001, seconds: 1.0) == nil, "already-silent must not re-emit")
  // A loud sample breaks the silence and emits the change.
  try require(detector.update(level: 0.5, seconds: 0.1) == false, "loud sample must flip back to audible")
  try require(detector.update(level: 0.5, seconds: 0.1) == nil, "already-audible must not re-emit")
  detector.reset()
  try require(detector.update(level: 0.001, seconds: 3.0) == true, "reset must allow a fresh silent transition")
}

private func testDegradationReasonDecision() throws {
  // dual-source availability drives the degradation message; this mirrors the
  // product decision in MacOSAudioCapture.degradationReason.
  func degradationReason(hasSystemAudio: Bool, modern: Bool) -> String? {
    guard !hasSystemAudio else { return nil }
    if modern {
      return "系统声音不可用，本次仅记录麦克风。请检查“系统设置 → 隐私与安全性 → 屏幕与系统音频录制”。"
    }
    return "当前 macOS 版本仅支持麦克风录音；升级到 macOS 14.4 或更高版本可记录系统声音。"
  }
  try require(degradationReason(hasSystemAudio: true, modern: true) == nil, "dual available -> no degradation")
  try require(degradationReason(hasSystemAudio: false, modern: true)?.contains("仅记录麦克风") == true, "modern degradation text")
  try require(degradationReason(hasSystemAudio: false, modern: false)?.contains("升级到 macOS 14.4") == true, "legacy <14.4 degradation text")
}

do {
  try testErrorClassification()
  try testRingBufferOrderAndOverrun()
  try testRingBufferReset()
  try testRms()
  try testSilenceDetectorHysteresis()
  try testDegradationReasonDecision()
  print("MacAudioLogic native tests passed")
} catch {
  FileHandle.standardError.write(Data("MacAudioLogic native tests failed: \(error)\n".utf8))
  exit(1)
}