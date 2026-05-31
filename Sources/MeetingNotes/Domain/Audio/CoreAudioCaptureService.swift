import AVFoundation
import Foundation

/// 双音源采集混音服务的具体实现（需求 5、6）。
///
/// 采集图（设计文档「两路接入 AVAudioMixerNode，经 AVAudioConverter 重采样写入 WAV」）：
/// ```
/// 系统声音 Tap ──► 环形缓冲 ──► AVAudioSourceNode ─┐
///                                                  ├─► AVAudioMixerNode ──► (mixer tap)
/// 麦克风 inputNode ────────────────────────────────┘                          │
///                                                                   AVAudioConverter (→16kHz/单声道/16bit)
///                                                                              │
///                                                                       AVAudioFile (WAV)
/// ```
/// - 系统声音：`SystemAudioTap`（Core Audio Process Tap，macOS 14.4+）。不可用时自动降级为仅麦克风。
/// - 麦克风：`AVAudioEngine.inputNode`。
/// - 混音输出经 `AVAudioConverter` 重采样为 16kHz / 单声道 / 16bit PCM，写入 WAV 文件。
/// - `pause`/`resume` 通过写入门闸实现：暂停期间丢弃混音帧不写文件，已写内容完整保留，
///   继续后紧接其后追加，最终 WAV 时长等于各活跃段时长之和（需求 6.6、6.7，Property 1）。
///
/// - Note: 真实双路采集需 macOS 14.4+ 真机与屏幕录制 / 麦克风权限，无法在无人值守环境运行验证，
///   属设计文档「手动验证」范围；本类型在该环境下可正常编译。
final class CoreAudioCaptureService: AudioCaptureService {

    // MARK: - 实时电平与静音状态流（需求 5.2-5.4）

    /// 系统声音电平流（基于每个缓冲的 RMS，0...1）。
    let systemLevel: AsyncStream<Float>
    /// 麦克风电平流（基于每个缓冲的 RMS，0...1）。
    let micLevel: AsyncStream<Float>
    /// 系统声音静音状态流：持续无信号时标识静音，仅在状态翻转时产出（需求 5.3，不中断录制）。
    let systemSilent: AsyncStream<Bool>
    /// 麦克风静音状态流：持续无信号时标识静音，仅在状态翻转时产出（需求 5.4，不中断录制）。
    let micSilent: AsyncStream<Bool>

    private let systemLevelContinuation: AsyncStream<Float>.Continuation
    private let micLevelContinuation: AsyncStream<Float>.Continuation
    private let systemSilentContinuation: AsyncStream<Bool>.Continuation
    private let micSilentContinuation: AsyncStream<Bool>.Continuation

    /// 系统声音通路静音判定器（RMS 连续低于阈值累计达窗口即判定静音）。
    private let systemSilenceDetector = ChannelSilenceDetector()
    /// 麦克风通路静音判定器。
    private let micSilenceDetector = ChannelSilenceDetector()

    // MARK: - 音频图

    private let engine = AVAudioEngine()
    private let mixerNode = AVAudioMixerNode()
    private var sourceNode: AVAudioSourceNode?
    private var systemTap: AnyObject?           // 实际类型 SystemAudioTap，受 14.4 可用性约束以 AnyObject 持有
    private let systemRingBuffer = AudioRingBuffer()
    private var systemSourceFormat: AVAudioFormat?

    // MARK: - 写文件

    private var outputFile: AVAudioFile?
    private var converter: AVAudioConverter?
    private var outputURL: URL?
    private let fileLock = NSLock()

    // MARK: - 状态

    private var isRunning = false
    /// 写入门闸：true 表示当前正在把混音帧写入文件；暂停时置 false。
    private var isWritingEnabled = false

    // MARK: - 初始化

    init() {
        var sysCont: AsyncStream<Float>.Continuation!
        systemLevel = AsyncStream<Float> { sysCont = $0 }
        systemLevelContinuation = sysCont

        var micCont: AsyncStream<Float>.Continuation!
        micLevel = AsyncStream<Float> { micCont = $0 }
        micLevelContinuation = micCont

        var sysSilentCont: AsyncStream<Bool>.Continuation!
        systemSilent = AsyncStream<Bool> { sysSilentCont = $0 }
        systemSilentContinuation = sysSilentCont

        var micSilentCont: AsyncStream<Bool>.Continuation!
        micSilent = AsyncStream<Bool> { micSilentCont = $0 }
        micSilentContinuation = micSilentCont
    }

    // MARK: - AudioCaptureService

    func start() async throws {
        guard !isRunning else { throw AudioCaptureError.alreadyRunning }

        systemRingBuffer.reset()
        systemSilenceDetector.reset()
        micSilenceDetector.reset()
        // 录音开始时两路默认视为非静音，待持续无信号再翻转（需求 5.3、5.4）。
        systemSilentContinuation.yield(false)
        micSilentContinuation.yield(false)
        let outputURL = try makeOutputURL()
        self.outputURL = outputURL
        try openOutputFile(at: outputURL)

        engine.attach(mixerNode)

        // 1) 麦克风一路：inputNode → mixer。
        try attachMicrophone()

        // 2) 系统声音一路（macOS 14.4+，失败则降级为仅麦克风）。
        attachSystemAudioIfAvailable()

        // 3) mixer → mainMixer（静音输出，避免回授），并在 mixer 上挂 tap 写文件。
        engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
        engine.mainMixerNode.outputVolume = 0
        installMixerTap()

        engine.prepare()
        do {
            try engine.start()
        } catch {
            cleanup()
            throw AudioCaptureError.engineStartFailed(reason: error.localizedDescription)
        }

        isRunning = true
        isWritingEnabled = true
    }

    func pause() {
        // 关闭写入门闸：暂停期间混音帧不落盘，已录内容保留（需求 6.6）。
        isWritingEnabled = false
    }

    func resume() {
        // 重新打开写入门闸：在已录内容之后继续追加（需求 6.7）。
        guard isRunning else { return }
        isWritingEnabled = true
    }

    @discardableResult
    func stop() async throws -> URL {
        guard isRunning, let url = outputURL else {
            throw AudioCaptureError.notRunning
        }
        isWritingEnabled = false
        cleanup()
        isRunning = false
        return url
    }

    // MARK: - 麦克风

    private func attachMicrophone() throws {
        let input = engine.inputNode
        let micFormat = input.inputFormat(forBus: 0)
        guard micFormat.channelCount > 0 else {
            throw AudioCaptureError.microphoneUnavailable
        }
        engine.connect(input, to: mixerNode, format: micFormat)

        // 麦克风电平：单独在 inputNode 挂 tap（任务 7.2 在此计算 RMS 与静音判定）。
        input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { [weak self] buffer, _ in
            self?.handleMicBuffer(buffer)
        }
    }

    // MARK: - 系统声音

    private func attachSystemAudioIfAvailable() {
        guard #available(macOS 14.4, *) else {
            // 低于 14.4 无 Process Tap，降级为仅麦克风采集。
            return
        }
        let tap = SystemAudioTap()
        do {
            try tap.start { [weak self] buffers, frames, format in
                self?.handleSystemSamples(buffers: buffers, frames: frames, format: format)
            }
        } catch {
            // Tap 不可用（无权限 / 无系统音频）时降级为仅麦克风，不中断录音。
            return
        }
        systemTap = tap

        // 系统声音以单声道 Float32 接入混音图，采样率沿用 Tap 输出采样率。
        let tapRate = tap.streamFormat?.sampleRate ?? 48_000
        guard let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: tapRate,
            channels: 1,
            interleaved: false
        ) else { return }
        systemSourceFormat = sourceFormat

        let node = AVAudioSourceNode(format: sourceFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = abl.first, let data = buffer.mData else { return noErr }
            let ptr = data.assumingMemoryBound(to: Float.self)
            self.systemRingBuffer.read(into: ptr, count: Int(frameCount))
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: mixerNode, format: sourceFormat)
        sourceNode = node
    }

    /// 处理系统声音原生 PCM：下混为单声道写入环形缓冲，供 source node 拉取。
    private func handleSystemSamples(buffers: UnsafePointer<AudioBufferList>,
                                     frames: AVAudioFrameCount,
                                     format: AVAudioFormat) {
        let frameCount = Int(frames)
        guard frameCount > 0 else { return }
        let abl = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffers))
        let channels = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: frameCount)

        if format.isInterleaved {
            guard let raw = abl.first?.mData else { return }
            let data = raw.assumingMemoryBound(to: Float.self)
            for frame in 0..<frameCount {
                var sum: Float = 0
                for ch in 0..<channels { sum += data[frame * channels + ch] }
                mono[frame] = sum / Float(max(1, channels))
            }
        } else {
            // 非交错：每声道一个缓冲，逐帧取均值下混。
            for frame in 0..<frameCount {
                var sum: Float = 0
                var counted = 0
                for ch in 0..<min(channels, abl.count) {
                    if let raw = abl[ch].mData {
                        sum += raw.assumingMemoryBound(to: Float.self)[frame]
                        counted += 1
                    }
                }
                mono[frame] = counted > 0 ? sum / Float(counted) : 0
            }
        }

        mono.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress {
                systemRingBuffer.write(base, count: frameCount)
            }
        }

        // 需求 5.2：以下混后的单声道样本计算 RMS，作为系统声音实时电平输出给波形。
        let level = mono.withUnsafeBufferPointer { ptr -> Float in
            guard let base = ptr.baseAddress else { return 0 }
            return AudioLevelMeter.rms(base, count: frameCount)
        }
        systemLevelContinuation.yield(level)

        // 需求 5.3：累计连续无信号时长，达窗口则标识系统声音通路静音；不中断录制。
        let duration = format.sampleRate > 0 ? Double(frameCount) / format.sampleRate : 0
        if let flipped = systemSilenceDetector.update(rms: level, duration: duration) {
            systemSilentContinuation.yield(flipped)
        }
    }

    // MARK: - 混音写文件

    private func installMixerTap() {
        let tapFormat = mixerNode.outputFormat(forBus: 0)
        mixerNode.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [weak self] buffer, _ in
            self?.writeMixedBuffer(buffer)
        }
    }

    /// 将混音缓冲重采样为 16kHz / 单声道 / 16bit PCM 并写入 WAV。
    private func writeMixedBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isWritingEnabled else { return }
        fileLock.lock()
        defer { fileLock.unlock() }
        guard let file = outputFile else { return }

        let targetFormat = file.processingFormat
        let converter: AVAudioConverter
        if let existing = self.converter {
            converter = existing
        } else {
            guard let made = AVAudioConverter(from: buffer.format, to: targetFormat) else { return }
            self.converter = made
            converter = made
        }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var fedInput = false
        var convertError: NSError?
        let outcome = converter.convert(to: outBuffer, error: &convertError) { _, statusPtr in
            if fedInput {
                statusPtr.pointee = .noDataNow
                return nil
            }
            fedInput = true
            statusPtr.pointee = .haveData
            return buffer
        }

        guard outcome != .error, outBuffer.frameLength > 0 else { return }
        try? file.write(from: outBuffer)
    }

    private func handleMicBuffer(_ buffer: AVAudioPCMBuffer) {
        // 需求 5.2：计算麦克风缓冲的 RMS 作为实时电平输出给波形。
        let level = AudioLevelMeter.level(of: buffer)
        micLevelContinuation.yield(level)

        // 需求 5.4：累计连续无信号时长，达窗口则标识麦克风通路静音；不中断录制。
        let sampleRate = buffer.format.sampleRate
        let duration = sampleRate > 0 ? Double(buffer.frameLength) / sampleRate : 0
        if let flipped = micSilenceDetector.update(rms: level, duration: duration) {
            micSilentContinuation.yield(flipped)
        }
    }

    // MARK: - 输出文件

    private func makeOutputURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MeetingNotesRecordings", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw AudioCaptureError.outputFileCreationFailed(reason: error.localizedDescription)
        }
        return dir.appendingPathComponent("\(UUID().uuidString).wav")
    }

    private func openOutputFile(at url: URL) throws {
        do {
            outputFile = try AVAudioFile(forWriting: url, settings: AudioCaptureFormat.wavSettings)
        } catch {
            throw AudioCaptureError.outputFileCreationFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - 清理

    private func cleanup() {
        if engine.isRunning {
            mixerNode.removeTap(onBus: 0)
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        if #available(macOS 14.4, *), let tap = systemTap as? SystemAudioTap {
            tap.stop()
        }
        systemTap = nil
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
        fileLock.lock()
        outputFile = nil
        converter = nil
        fileLock.unlock()
    }

    deinit {
        systemLevelContinuation.finish()
        micLevelContinuation.finish()
        systemSilentContinuation.finish()
        micSilentContinuation.finish()
    }
}
