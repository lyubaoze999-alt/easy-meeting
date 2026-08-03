import Foundation

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

private func waitForDeliveries(
  _ semaphore: DispatchSemaphore,
  count: Int,
  timeout: DispatchTime = .now() + 3
) throws {
  for _ in 0..<count {
    try require(semaphore.wait(timeout: timeout) == .success, "Timed out waiting for PCM frame")
  }
}

private func testContinuousFramesAndTerminalFrame() throws {
  let pump = PCMFramePump()
  let received = LockedFrames()
  let delivered = DispatchSemaphore(value: 0)
  pump.onFrame = { frame in
    received.append(frame)
    delivered.signal()
  }

  pump.start(sessionId: "session-a")
  pump.append(Data(repeating: 7, count: PCMFramePump.bytesPerFrame * 2 + 2_000))
  pump.finish()

  try waitForDeliveries(delivered, count: 3)
  let frames = received.snapshot()
  try require(frames.map(\.sequence) == [0, 1, 2], "Sequences were not monotonic")
  try require(
    frames.map(\.startSample) == [0, 4_800, 9_600],
    "startSample did not follow the persisted sample timeline"
  )
  try require(
    frames.map { $0.bytes.count } == [
      PCMFramePump.bytesPerFrame,
      PCMFramePump.bytesPerFrame,
      2_000
    ],
    "PCM frames did not use 200 ms chunks plus an aligned terminal frame"
  )
  try require(
    frames.allSatisfy { $0.sampleRate == 24_000 && $0.channels == 1 },
    "PCM format was not canonical 24 kHz mono"
  )
}

private func testSlowConsumerDropsOldestCopies() throws {
  let pump = PCMFramePump()
  let received = LockedFrames()
  let firstDeliveryStarted = DispatchSemaphore(value: 0)
  let allowFirstDelivery = DispatchSemaphore(value: 0)
  let delivered = DispatchSemaphore(value: 0)
  pump.onFrame = { frame in
    received.append(frame)
    if frame.sequence == 0 {
      firstDeliveryStarted.signal()
      _ = allowFirstDelivery.wait(timeout: .now() + 2)
    }
    delivered.signal()
  }

  pump.start(sessionId: "session-a")
  pump.append(Data(count: PCMFramePump.bytesPerFrame))
  try require(
    firstDeliveryStarted.wait(timeout: .now() + 1) == .success,
    "The first PCM delivery did not start"
  )
  pump.append(Data(count: PCMFramePump.bytesPerFrame * 29))
  pump.finish()
  allowFirstDelivery.signal()

  try waitForDeliveries(delivered, count: 26)
  let frames = received.snapshot()
  try require(frames.count == 26, "The network-copy queue exceeded its 25-frame bound")
  try require(frames.first?.sequence == 0, "The in-flight frame was not delivered")
  try require(frames.dropFirst().first?.sequence == 5, "Oldest queued copies were not dropped")
  try require(frames.last?.sequence == 29, "The newest network copy was not retained")
  try require(
    frames.dropFirst().first?.startSample == 24_000,
    "Dropped copies did not remain detectable through startSample"
  )
}

private final class LockedFrames {
  private let lock = NSLock()
  private var frames: [NativePCMFrame] = []

  func append(_ frame: NativePCMFrame) {
    lock.lock()
    frames.append(frame)
    lock.unlock()
  }

  func snapshot() -> [NativePCMFrame] {
    lock.lock()
    defer { lock.unlock() }
    return frames
  }
}

do {
  try testContinuousFramesAndTerminalFrame()
  try testSlowConsumerDropsOldestCopies()
  print("PCMFramePump native tests passed")
} catch {
  FileHandle.standardError.write(Data("PCMFramePump native tests failed: \(error)\n".utf8))
  exit(1)
}
