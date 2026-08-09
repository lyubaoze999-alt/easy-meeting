import AVFoundation

struct MacAudioAvailability {
  let systemAudio: Bool
  let microphone: Bool
  let sessionId: String
  let degradationReason: String?
}

final class MacOSAudioCapture {
  var onEvent: ((String, Any) -> Void)?
  var onPCMFrame: ((NativePCMFrame) -> Void)? {
    didSet { pcmFramePump.onFrame = onPCMFrame }
  }

  private var engine: AVAudioEngine?
  private var mixer: AVAudioMixerNode?
  private let ringBuffer = AudioRingBuffer()
  private let pcmFramePump = PCMFramePump()
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
    let sessionId = UUID().uuidString
    let url = directory.appendingPathComponent("\(sessionId).wav")
    outputURL = url
    do {
      outputFile = try AVAudioFile(forWriting: url, settings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: PCMFramePump.sampleRate,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false
      ], commonFormat: .pcmFormatInt16, interleaved: false)
      pcmFramePump.start(sessionId: sessionId)

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
        sessionId: sessionId,
        degradationReason: degradationReason(hasSystemAudio: hasSystemAudio)
      )
    } catch {
      setWriting(false)
      pcmFramePump.cancel()
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
    _ = pcmFramePump.finishAndWait()
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
    let level = _microphoneLevel(buffer)
    onEvent?("microphoneLevel", level)
    let seconds = Double(buffer.frameLength) / max(1, buffer.format.sampleRate)
    if let silent = microphoneSilence.update(level: level, seconds: seconds) {
      onEvent?("microphoneSilent", silent)
    }
  }

  private func _microphoneLevel(_ buffer: AVAudioPCMBuffer) -> Float {
    guard let data = buffer.floatChannelData else { return 0 }
    var result: Float = 0
    for channel in 0..<Int(buffer.format.channelCount) {
      let values = Array(UnsafeBufferPointer(start: data[channel], count: Int(buffer.frameLength)))
      result += AudioMeter.rms(values)
    }
    return result / Float(max(1, Int(buffer.format.channelCount)))
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
    guard status != .error, output.frameLength > 0 else { return }
    do {
      try file.write(from: output)
      if let channel = output.int16ChannelData?.pointee {
        pcmFramePump.append(
          Data(bytes: channel, count: Int(output.frameLength) * MemoryLayout<Int16>.size)
        )
      }
    } catch {
      // R-05: a write failure must not silently truncate the recording. Stop
      // writing new samples and surface the error to Dart so the UI can warn
      // the user that the on-disk capture is incomplete.
      writing = false
      onEvent?("writeError", error.localizedDescription)
    }
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
