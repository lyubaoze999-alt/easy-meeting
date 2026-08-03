import AVFoundation
import Foundation

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

struct MacAudioAvailability {
  let systemAudio: Bool
  let microphone: Bool
  let degradationReason: String?
}

final class MacOSAudioCapture {
  var onEvent: ((String, Any) -> Void)?

  private var engine: AVAudioEngine?
  private var mixer: AVAudioMixerNode?
  private let ringBuffer = AudioRingBuffer()
  private let fileLock = NSLock()
  private var systemTap: AnyObject?
  private var sourceNode: AVAudioSourceNode?
  private var outputFile: AVAudioFile?
  private var converter: AVAudioConverter?
  private var outputURL: URL?
  private var running = false
  private var writing = false
  private var inputTapInstalled = false
  private var mixerTapInstalled = false
  private var mixerAttached = false
  private let systemSilence = SilenceDetector()
  private let microphoneSilence = SilenceDetector()

  func start() throws -> MacAudioAvailability {
    guard !running else { throw MacAudioError.alreadyRunning }
    let engine = AVAudioEngine()
    let mixer = AVAudioMixerNode()
    self.engine = engine
    self.mixer = mixer
    ringBuffer.reset()
    systemSilence.reset()
    microphoneSilence.reset()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("EasyMeetingRecordings", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("\(UUID().uuidString).wav")
    outputURL = url
    do {
      outputFile = try AVAudioFile(forWriting: url, settings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
      ])

      let input = engine.inputNode
      let micFormat = input.inputFormat(forBus: 0)
      guard micFormat.channelCount > 0 else { throw MacAudioError.microphoneUnavailable }
      engine.attach(mixer)
      mixerAttached = true
      engine.connect(input, to: mixer, format: micFormat)
      input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { [weak self] buffer, _ in
        self?.handleMicrophone(buffer)
      }
      inputTapInstalled = true

      let hasSystemAudio = attachSystemAudio(engine: engine, mixer: mixer)
      engine.connect(mixer, to: engine.mainMixerNode, format: nil)
      engine.mainMixerNode.outputVolume = 0
      let mixFormat = mixer.outputFormat(forBus: 0)
      mixer.installTap(onBus: 0, bufferSize: 4096, format: mixFormat) { [weak self] buffer, _ in
        self?.write(buffer)
      }
      mixerTapInstalled = true
      setWriting(true)
      engine.prepare()
      try engine.start()
      running = true
      onEvent?("systemSilent", false)
      onEvent?("microphoneSilent", false)
      return MacAudioAvailability(
        systemAudio: hasSystemAudio,
        microphone: true,
        degradationReason: degradationReason(hasSystemAudio: hasSystemAudio)
      )
    } catch {
      setWriting(false)
      cleanup()
      try? FileManager.default.removeItem(at: url)
      outputURL = nil
      throw error
    }
  }

  func pause() { setWriting(false) }
  func resume() { if running { setWriting(true) } }

  func stop() throws -> URL {
    guard running, let outputURL else { throw MacAudioError.notRunning }
    setWriting(false)
    cleanup()
    running = false
    return outputURL
  }

  private func attachSystemAudio(engine: AVAudioEngine, mixer: AVAudioMixerNode) -> Bool {
    guard #available(macOS 14.4, *) else { return false }
    let tap = SystemAudioTap()
    do {
      try tap.start { [weak self] buffers, frames, format in
        self?.handleSystem(buffers, frames: frames, format: format)
      }
    } catch { return false }
    guard let format = AVAudioFormat(
      commonFormat: .pcmFormatFloat32,
      sampleRate: tap.streamFormat?.sampleRate ?? 48_000,
      channels: 1,
      interleaved: false
    ) else {
      tap.stop()
      return false
    }
    let node = AVAudioSourceNode(format: format) { [weak self] _, _, frames, list in
      guard let self, let data = UnsafeMutableAudioBufferListPointer(list).first?.mData else { return noErr }
      self.ringBuffer.read(into: data.assumingMemoryBound(to: Float.self), count: Int(frames))
      return noErr
    }
    engine.attach(node)
    engine.connect(node, to: mixer, format: format)
    systemTap = tap
    sourceNode = node
    return true
  }

  private func degradationReason(hasSystemAudio: Bool) -> String? {
    guard !hasSystemAudio else { return nil }
    if #available(macOS 14.4, *) {
      return "系统声音不可用，本次仅记录麦克风。请检查“系统设置 → 隐私与安全性 → 屏幕与系统音频录制”。"
    }
    return "当前 macOS 版本仅支持麦克风录音；升级到 macOS 14.4 或更高版本可记录系统声音。"
  }

  private func handleSystem(
    _ buffers: UnsafePointer<AudioBufferList>,
    frames: AVAudioFrameCount,
    format: AVAudioFormat
  ) {
    let frameCount = Int(frames)
    guard frameCount > 0 else { return }
    let list = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffers))
    let channels = max(1, Int(format.channelCount))
    var mono = [Float](repeating: 0, count: frameCount)
    if format.isInterleaved, let raw = list.first?.mData {
      let samples = raw.assumingMemoryBound(to: Float.self)
      for frame in 0..<frameCount {
        for channel in 0..<channels { mono[frame] += samples[frame * channels + channel] }
        mono[frame] /= Float(channels)
      }
    } else {
      for frame in 0..<frameCount {
        var count = 0
        for channel in 0..<min(channels, list.count) {
          if let raw = list[channel].mData {
            mono[frame] += raw.assumingMemoryBound(to: Float.self)[frame]
            count += 1
          }
        }
        if count > 0 { mono[frame] /= Float(count) }
      }
    }
    mono.withUnsafeBufferPointer { pointer in
      if let base = pointer.baseAddress { ringBuffer.write(base, count: frameCount) }
    }
    let level = AudioMeter.rms(mono)
    onEvent?("systemLevel", level)
    if let silent = systemSilence.update(level: level, seconds: Double(frameCount) / format.sampleRate) {
      onEvent?("systemSilent", silent)
    }
  }

  private func handleMicrophone(_ buffer: AVAudioPCMBuffer) {
    let level = AudioMeter.level(buffer)
    onEvent?("microphoneLevel", level)
    let seconds = Double(buffer.frameLength) / max(1, buffer.format.sampleRate)
    if let silent = microphoneSilence.update(level: level, seconds: seconds) {
      onEvent?("microphoneSilent", silent)
    }
  }

  private func write(_ buffer: AVAudioPCMBuffer) {
    fileLock.lock()
    defer { fileLock.unlock() }
    guard writing else { return }
    guard let file = outputFile else { return }
    let target = file.processingFormat
    guard let activeConverter = converter ?? AVAudioConverter(from: buffer.format, to: target) else { return }
    converter = activeConverter
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 1024
    guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
    var supplied = false
    var conversionError: NSError?
    let status = activeConverter.convert(to: output, error: &conversionError) { _, state in
      if supplied { state.pointee = .noDataNow; return nil }
      supplied = true
      state.pointee = .haveData
      return buffer
    }
    if status != .error && output.frameLength > 0 { try? file.write(from: output) }
  }

  private func setWriting(_ value: Bool) {
    fileLock.lock()
    writing = value
    fileLock.unlock()
  }

  private func cleanup() {
    guard let engine else {
      outputFile = nil
      converter = nil
      return
    }
    engine.stop()
    if mixerTapInstalled, let mixer { mixer.removeTap(onBus: 0) }
    if inputTapInstalled { engine.inputNode.removeTap(onBus: 0) }
    if #available(macOS 14.4, *), let tap = systemTap as? SystemAudioTap { tap.stop() }
    if let sourceNode {
      engine.disconnectNodeInput(sourceNode)
      engine.disconnectNodeOutput(sourceNode)
      engine.detach(sourceNode)
    }
    if mixerAttached, let mixer {
      engine.disconnectNodeInput(mixer)
      engine.disconnectNodeOutput(mixer)
      engine.detach(mixer)
    }
    engine.reset()
    sourceNode = nil
    systemTap = nil
    outputFile = nil
    converter = nil
    inputTapInstalled = false
    mixerTapInstalled = false
    mixerAttached = false
    self.mixer = nil
    self.engine = nil
  }
}

private final class AudioRingBuffer {
  private var storage = [Float](repeating: 0, count: 96_000)
  private var writeIndex = 0
  private var readIndex = 0
  private var available = 0
  private let lock = NSLock()

  func write(_ samples: UnsafePointer<Float>, count: Int) {
    lock.lock(); defer { lock.unlock() }
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

  func reset() { lock.lock(); writeIndex = 0; readIndex = 0; available = 0; lock.unlock() }
}

private enum AudioMeter {
  static func rms(_ samples: [Float]) -> Float {
    guard !samples.isEmpty else { return 0 }
    return min(1, sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)))
  }

  static func level(_ buffer: AVAudioPCMBuffer) -> Float {
    guard let data = buffer.floatChannelData else { return 0 }
    var result: Float = 0
    for channel in 0..<Int(buffer.format.channelCount) {
      let values = Array(UnsafeBufferPointer(start: data[channel], count: Int(buffer.frameLength)))
      result += rms(values)
    }
    return result / Float(max(1, Int(buffer.format.channelCount)))
  }
}

private final class SilenceDetector {
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
