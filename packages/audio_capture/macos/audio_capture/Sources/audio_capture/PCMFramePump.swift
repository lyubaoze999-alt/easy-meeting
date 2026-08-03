import Foundation

struct NativePCMFrame {
  let sessionId: String
  let sequence: Int64
  let startSample: Int64
  let sampleRate: Int
  let channels: Int
  let bytes: Data
}

/// Maintains the bounded, best-effort copy used by realtime consumers.
///
/// The WAV writer calls `append` only after the same samples were written to
/// disk. Delivery happens on a separate serial queue. If Flutter is slow, the
/// oldest queued network copies are discarded while sequence/startSample keep
/// advancing so Dart can detect the exact gap.
final class PCMFramePump {
  static let sampleRate = 24_000
  static let channels = 1
  static let samplesPerFrame = 4_800
  static let bytesPerFrame = samplesPerFrame * MemoryLayout<Int16>.size
  static let maximumQueuedFrames = 25

  var onFrame: ((NativePCMFrame) -> Void)?

  private let lock = NSLock()
  private let deliveryQueue = DispatchQueue(
    label: "com.meetingnotes.audio.pcm-delivery",
    qos: .utility
  )
  private var sessionId: String?
  private var pendingBytes = Data()
  private var queuedFrames: [NativePCMFrame] = []
  private var nextSequence: Int64 = 0
  private var nextStartSample: Int64 = 0
  private var accepting = false
  private var delivering = false
  private var generation: UInt64 = 0
  private var finishCallbacks: [() -> Void] = []

  func start(sessionId: String) {
    lock.lock()
    generation &+= 1
    self.sessionId = sessionId
    pendingBytes.removeAll(keepingCapacity: true)
    queuedFrames.removeAll(keepingCapacity: true)
    nextSequence = 0
    nextStartSample = 0
    accepting = true
    delivering = false
    finishCallbacks.removeAll(keepingCapacity: true)
    lock.unlock()
  }

  func append(_ bytes: Data) {
    guard !bytes.isEmpty else { return }
    var generationToSchedule: UInt64?
    lock.lock()
    if accepting, let sessionId {
      pendingBytes.append(bytes)
      while pendingBytes.count >= Self.bytesPerFrame {
        let frameBytes = Data(pendingBytes.prefix(Self.bytesPerFrame))
        pendingBytes.removeFirst(Self.bytesPerFrame)
        enqueueLocked(
          NativePCMFrame(
            sessionId: sessionId,
            sequence: nextSequence,
            startSample: nextStartSample,
            sampleRate: Self.sampleRate,
            channels: Self.channels,
            bytes: frameBytes
          )
        )
        nextSequence += 1
        nextStartSample += Int64(Self.samplesPerFrame)
      }
      generationToSchedule = scheduleDeliveryLocked()
    }
    lock.unlock()
    scheduleDelivery(generationToSchedule)
  }

  /// Stops accepting audio and emits the final frame even when it is shorter
  /// than 200 ms. It never waits for Flutter, so finalizing the WAV remains the
  /// priority.
  func finish(completion: (() -> Void)? = nil) {
    var generationToSchedule: UInt64?
    var completeImmediately: (() -> Void)?
    lock.lock()
    if accepting, let sessionId, !pendingBytes.isEmpty {
      let sampleCount = pendingBytes.count / MemoryLayout<Int16>.size
      enqueueLocked(
        NativePCMFrame(
          sessionId: sessionId,
          sequence: nextSequence,
          startSample: nextStartSample,
          sampleRate: Self.sampleRate,
          channels: Self.channels,
          bytes: pendingBytes
        )
      )
      nextSequence += 1
      nextStartSample += Int64(sampleCount)
      pendingBytes = Data()
    }
    accepting = false
    if let completion {
      if queuedFrames.isEmpty, !delivering {
        completeImmediately = completion
      } else {
        finishCallbacks.append(completion)
      }
    }
    generationToSchedule = scheduleDeliveryLocked()
    lock.unlock()
    scheduleDelivery(generationToSchedule)
    completeImmediately?()
  }

  /// Waits only until every retained frame has been handed to the event-channel
  /// callback. It never waits for Dart or a network acknowledgement.
  @discardableResult
  func finishAndWait(timeout: TimeInterval = 1) -> Bool {
    let completed = DispatchSemaphore(value: 0)
    finish { completed.signal() }
    return completed.wait(timeout: .now() + timeout) == .success
  }

  func cancel() {
    lock.lock()
    generation &+= 1
    accepting = false
    delivering = false
    sessionId = nil
    pendingBytes.removeAll(keepingCapacity: false)
    queuedFrames.removeAll(keepingCapacity: false)
    let callbacks = finishCallbacks
    finishCallbacks.removeAll(keepingCapacity: false)
    lock.unlock()
    callbacks.forEach { $0() }
  }

  private func enqueueLocked(_ frame: NativePCMFrame) {
    queuedFrames.append(frame)
    if queuedFrames.count > Self.maximumQueuedFrames {
      queuedFrames.removeFirst(queuedFrames.count - Self.maximumQueuedFrames)
    }
  }

  private func scheduleDeliveryLocked() -> UInt64? {
    guard !delivering, !queuedFrames.isEmpty else { return nil }
    delivering = true
    return generation
  }

  private func scheduleDelivery(_ generation: UInt64?) {
    guard let generation else { return }
    deliveryQueue.async { [weak self] in self?.drain(generation: generation) }
  }

  private func drain(generation expectedGeneration: UInt64) {
    while true {
      let frame: NativePCMFrame
      lock.lock()
      guard generation == expectedGeneration else {
        lock.unlock()
        return
      }
      guard !queuedFrames.isEmpty else {
        delivering = false
        if !accepting { sessionId = nil }
        let callbacks = finishCallbacks
        finishCallbacks.removeAll(keepingCapacity: false)
        lock.unlock()
        callbacks.forEach { $0() }
        return
      }
      frame = queuedFrames.removeFirst()
      lock.unlock()
      onFrame?(frame)
    }
  }
}
