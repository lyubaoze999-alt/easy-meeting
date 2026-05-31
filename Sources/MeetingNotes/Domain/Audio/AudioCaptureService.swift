import AVFoundation
import Foundation

/// 双音源音频采集服务协议（需求 5、6）。
///
/// 采集时同时拉取系统声音与麦克风两路，混合为一路并重采样为 16kHz / 单声道 / 16bit PCM 的 WAV。
/// `systemLevel` / `micLevel` 输出两路实时电平（基于 RMS），供录音态波形与静音判断使用；
/// `systemSilent` / `micSilent` 输出两路静音状态，供录音态展示「系统声音静音」/「麦克风静音」。
protocol AudioCaptureService: AnyObject {
    /// 系统声音实时电平流（0...1，越大越响）。
    var systemLevel: AsyncStream<Float> { get }
    /// 麦克风实时电平流（0...1，越大越响）。
    var micLevel: AsyncStream<Float> { get }
    /// 系统声音通路静音状态流（true=持续无信号被标识为静音，false=恢复有信号）。
    ///
    /// 静音仅用于状态标识，不中断录制（需求 5.3）。仅在状态翻转时产出新值。
    var systemSilent: AsyncStream<Bool> { get }
    /// 麦克风通路静音状态流（true=持续无信号被标识为静音，false=恢复有信号）。
    ///
    /// 静音仅用于状态标识，不中断录制（需求 5.4）。仅在状态翻转时产出新值。
    var micSilent: AsyncStream<Bool> { get }

    /// 开始采集：建立系统声音 Tap 与麦克风输入，启动混音与写文件（需求 5.1）。
    func start() async throws
    /// 暂停采集：停止写入但保留已录制内容（需求 6.6）。
    func pause()
    /// 继续采集：在已录制内容之后继续追加（需求 6.7）。
    func resume()
    /// 结束采集：收尾并返回混音后的 WAV 文件 URL（需求 6.8）。
    @discardableResult
    func stop() async throws -> URL
}

/// 采集目标音频格式常量（设计文档：16kHz / 单声道 / 16bit PCM）。
enum AudioCaptureFormat {
    /// 目标采样率：16kHz，匹配主流语音转写服务输入要求。
    static let sampleRate: Double = 16_000
    /// 目标声道数：单声道。
    static let channelCount: AVAudioChannelCount = 1
    /// 目标位深：16bit。
    static let bitDepth: Int = 16

    /// 写入 WAV 文件时使用的设置（线性 PCM，16kHz / 单声道 / 16bit / 小端）。
    static var wavSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
            AVLinearPCMBitDepthKey: bitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    /// 转换器目标处理格式：与 WAV 文件的 processingFormat 对齐（16kHz / 单声道 / Float32 非交错）。
    ///
    /// `AVAudioFile` 在以 `wavSettings` 创建后，其 `processingFormat` 为对应采样率与声道数的
    /// Float32 PCM；写入时由文件层把 Float32 编码为 16bit 整型。这里据此构造转换目标格式。
    static var converterTargetFormat: AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )
    }
}

/// 音频采集过程中可能抛出的错误（需求 5、6）。
enum AudioCaptureError: Error, Equatable {
    /// 当前已在采集中，重复 start。
    case alreadyRunning
    /// 尚未开始采集即调用 stop。
    case notRunning
    /// 无法构造目标音频格式（理论上不应发生，属环境异常）。
    case invalidTargetFormat
    /// 无法构造 AVAudioConverter（源格式与目标格式不兼容）。
    case converterUnavailable
    /// 麦克风输入不可用（无输入设备或被占用）。
    case microphoneUnavailable
    /// AVAudioEngine 启动失败，附带底层错误描述。
    case engineStartFailed(reason: String)
    /// 创建输出 WAV 文件失败，附带底层错误描述。
    case outputFileCreationFailed(reason: String)
    /// 系统声音 Tap 创建失败（需 macOS 14.4+ 且授予屏幕录制权限），附带 OSStatus。
    ///
    /// 该错误不阻断录音：服务会退化为仅麦克风采集（见实现的降级路径）。
    case systemTapUnavailable(status: Int32)
}
