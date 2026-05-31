import AVFoundation
import Foundation

/// 单声道 / 多声道 PCM 的 RMS 电平计算工具（需求 5.2：实时电平用于波形）。
///
/// RMS（均方根）反映一段样本的有效能量，比瞬时峰值更平滑，适合驱动音量波形与静音判断。
/// 对归一化的 Float PCM（样本落在 -1...1），RMS 天然落在 0...1，这里再做一次钳制以防越界。
enum AudioLevelMeter {

    /// 计算一段单声道 Float 样本的 RMS，并钳制到 0...1。
    static func rms(_ samples: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        var sumSquares: Float = 0
        for i in 0..<count {
            let sample = samples[i]
            sumSquares += sample * sample
        }
        let mean = sumSquares / Float(count)
        let value = sqrtf(mean)
        return min(1, max(0, value))
    }

    /// 计算一个 `AVAudioPCMBuffer` 的 RMS 电平（跨声道取均值），钳制到 0...1。
    ///
    /// 仅支持 Float32 PCM（麦克风 `inputNode` 与混音 tap 均为 Float32）。
    /// 非 Float 缓冲返回 0（视为无可测电平）。
    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return 0 }
        var total: Float = 0
        for channel in 0..<channelCount {
            total += rms(channelData[channel], count: frameLength)
        }
        return min(1, max(0, total / Float(channelCount)))
    }
}

/// 单路音源静音判定器（需求 5.3 系统声音、5.4 麦克风）。
///
/// 持续喂入每个音频缓冲的 RMS 电平与对应时长，累计「连续低于阈值」的时长；
/// 当累计静音时长达到判定窗口时标识该路为静音，一旦出现高于阈值的信号立即恢复为非静音。
///
/// 该判定**只用于状态标识，绝不中断录制**（需求 5.3、5.4 明确：不中断录制）——
/// 调用方仅根据返回的状态翻转去更新 UI 上的「系统声音静音」/「麦克风静音」提示。
///
/// 阈值与窗口取值说明：
/// - `defaultThreshold = 0.005`（约 -46 dBFS）：低于普通环境底噪量级，足以区分
///   「完全没有收到信号」与「收到了很轻的声音」，又不至于把真实轻声误判为静音。
/// - `defaultWindow = 2.5` 秒：留出说话的自然停顿余量，避免句子间隙被误判为通路静音，
///   同时能在数秒内反映出「这一路一直没声音」的真实情况。
final class ChannelSilenceDetector {

    /// RMS 静音阈值，低于此值的缓冲视为「无有效信号」。
    static let defaultThreshold: Float = 0.005
    /// 持续静音判定窗口（秒）：连续低于阈值累计达到该时长才判定为静音。
    static let defaultWindow: TimeInterval = 2.5

    private let threshold: Float
    private let window: TimeInterval
    private var silentAccumulation: TimeInterval = 0
    private var silent = false
    private let lock = NSLock()

    init(threshold: Float = defaultThreshold, window: TimeInterval = defaultWindow) {
        self.threshold = threshold
        self.window = window
    }

    /// 当前是否处于静音状态。
    var isSilent: Bool {
        lock.lock()
        defer { lock.unlock() }
        return silent
    }

    /// 喂入一个缓冲的 RMS 与时长，推进静音判定。
    /// - Parameters:
    ///   - rms: 该缓冲的 RMS 电平（0...1）。
    ///   - duration: 该缓冲对应的时长（秒）。
    /// - Returns: 若静音状态发生翻转，返回新的状态（true=转为静音，false=恢复有信号）；
    ///   未发生翻转则返回 nil。调用方据此决定是否向 UI 推送状态变化。
    @discardableResult
    func update(rms: Float, duration: TimeInterval) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        if rms < threshold {
            silentAccumulation += duration
            if !silent && silentAccumulation >= window {
                silent = true
                return true
            }
        } else {
            silentAccumulation = 0
            if silent {
                silent = false
                return false
            }
        }
        return nil
    }

    /// 重置判定状态（每次重新开始采集前调用）。
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        silentAccumulation = 0
        silent = false
    }
}
