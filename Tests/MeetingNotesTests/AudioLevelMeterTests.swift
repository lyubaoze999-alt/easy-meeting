import XCTest
import AVFoundation
@testable import MeetingNotes

/// 双路实时电平与静音判定单元测试（任务 7.2，需求 5.2、5.3、5.4）。
///
/// 这部分是不依赖真机硬件的纯逻辑：RMS 计算与连续静音累计判定，可直接单测覆盖。
/// 真实双路采集的权限链与混音属设计文档「手动验证」范围。
final class AudioLevelMeterTests: XCTestCase {

    // MARK: - RMS 计算（需求 5.2）

    func testRMSOfSilenceIsZero() {
        let samples = [Float](repeating: 0, count: 512)
        let level = samples.withUnsafeBufferPointer { AudioLevelMeter.rms($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(level, 0, accuracy: 1e-6)
    }

    func testRMSOfFullScaleConstantIsOne() {
        // 恒定满幅信号的 RMS 等于幅值本身。
        let samples = [Float](repeating: 1, count: 256)
        let level = samples.withUnsafeBufferPointer { AudioLevelMeter.rms($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(level, 1, accuracy: 1e-6)
    }

    func testRMSOfSineWaveIsAmplitudeOverSqrt2() {
        // 正弦波的 RMS ≈ 幅值 / √2。
        let count = 2048
        let amplitude: Float = 0.8
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = amplitude * sinf(2 * .pi * Float(i) / Float(count))
        }
        let level = samples.withUnsafeBufferPointer { AudioLevelMeter.rms($0.baseAddress!, count: $0.count) }
        XCTAssertEqual(level, amplitude / 2.0.squareRoot().float, accuracy: 0.01)
    }

    func testRMSIsClampedToUnitRange() {
        // 越界样本不会让 RMS 超过 1。
        let samples = [Float](repeating: 5, count: 64)
        let level = samples.withUnsafeBufferPointer { AudioLevelMeter.rms($0.baseAddress!, count: $0.count) }
        XCTAssertLessThanOrEqual(level, 1)
        XCTAssertGreaterThanOrEqual(level, 0)
    }

    func testRMSOfEmptyBufferIsZero() {
        var dummy: Float = 0
        let level = AudioLevelMeter.rms(&dummy, count: 0)
        XCTAssertEqual(level, 0)
    }

    // MARK: - 静音判定（需求 5.3、5.4）

    func testStaysNonSilentBelowWindow() {
        let detector = ChannelSilenceDetector(threshold: 0.01, window: 2.0)
        // 累计 1.5 秒静音，未达 2 秒窗口，不应判定静音。
        XCTAssertNil(detector.update(rms: 0, duration: 1.5))
        XCTAssertFalse(detector.isSilent)
    }

    func testFlipsToSilentWhenWindowReached() {
        let detector = ChannelSilenceDetector(threshold: 0.01, window: 2.0)
        XCTAssertNil(detector.update(rms: 0, duration: 1.0))
        // 第二段使累计达到 2 秒，触发翻转为静音。
        XCTAssertEqual(detector.update(rms: 0, duration: 1.0), true)
        XCTAssertTrue(detector.isSilent)
    }

    func testFlipBackToNonSilentWhenSignalReturns() {
        let detector = ChannelSilenceDetector(threshold: 0.01, window: 1.0)
        XCTAssertEqual(detector.update(rms: 0, duration: 1.0), true)
        XCTAssertTrue(detector.isSilent)
        // 出现高于阈值的信号，立即恢复为非静音。
        XCTAssertEqual(detector.update(rms: 0.5, duration: 0.1), false)
        XCTAssertFalse(detector.isSilent)
    }

    func testSignalResetsAccumulationBeforeWindow() {
        let detector = ChannelSilenceDetector(threshold: 0.01, window: 2.0)
        // 接近窗口边缘时来一帧信号，应清零累计，不触发静音。
        XCTAssertNil(detector.update(rms: 0, duration: 1.9))
        XCTAssertNil(detector.update(rms: 0.2, duration: 0.1))
        XCTAssertNil(detector.update(rms: 0, duration: 1.0))
        XCTAssertFalse(detector.isSilent)
    }

    func testOnlyEmitsOnStateChange() {
        let detector = ChannelSilenceDetector(threshold: 0.01, window: 1.0)
        XCTAssertEqual(detector.update(rms: 0, duration: 1.0), true)
        // 已是静音态，继续静音不再重复产出。
        XCTAssertNil(detector.update(rms: 0, duration: 1.0))
        XCTAssertNil(detector.update(rms: 0, duration: 5.0))
        XCTAssertTrue(detector.isSilent)
    }

    func testResetClearsState() {
        let detector = ChannelSilenceDetector(threshold: 0.01, window: 1.0)
        XCTAssertEqual(detector.update(rms: 0, duration: 1.0), true)
        detector.reset()
        XCTAssertFalse(detector.isSilent)
        // 重置后重新累计，需再次达窗口才翻转。
        XCTAssertNil(detector.update(rms: 0, duration: 0.5))
    }

    // MARK: - PCM 缓冲电平（需求 5.2）

    func testPCMBufferLevelMatchesRMS() throws {
        let format = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                                 sampleRate: 16_000,
                                                 channels: 1,
                                                 interleaved: false))
        let frames: AVAudioFrameCount = 1024
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let channel = try XCTUnwrap(buffer.floatChannelData)
        for i in 0..<Int(frames) { channel[0][i] = 0.5 }
        // 恒定 0.5 的 RMS 等于 0.5。
        XCTAssertEqual(AudioLevelMeter.level(of: buffer), 0.5, accuracy: 1e-5)
    }
}

private extension Double {
    var float: Float { Float(self) }
}
