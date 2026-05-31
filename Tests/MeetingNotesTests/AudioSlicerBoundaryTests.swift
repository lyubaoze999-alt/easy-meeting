import XCTest
import AVFoundation
@testable import MeetingNotes

/// 切片边界单元测试（任务 8.4，需求 9.1）。
///
/// 覆盖三类边界：时长恰好等于上限（单片）、超一点（两片）、远超上限（多片）。
/// 用真实写出的 16kHz/单声道/16bit WAV 验证切片数量与内容守恒。
final class AudioSlicerBoundaryTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SlicerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    /// 写出一个指定时长（秒）的 16kHz 单声道 16bit WAV，样本为低幅正弦避免全零。
    private func writeWAV(seconds: Double, name: String = "src.wav") throws -> URL {
        let url = tempDir.appendingPathComponent(name)
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioCaptureFormat.sampleRate,
            channels: AudioCaptureFormat.channelCount,
            interleaved: false
        ))
        let file = try AVAudioFile(forWriting: url, settings: AudioCaptureFormat.wavSettings)
        let totalFrames = AVAudioFrameCount((AudioCaptureFormat.sampleRate * seconds).rounded())
        let chunk: AVAudioFrameCount = 16_000
        var written: AVAudioFrameCount = 0
        var phase: Float = 0
        while written < totalFrames {
            let n = min(chunk, totalFrames - written)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n))
            buffer.frameLength = n
            let ch = try XCTUnwrap(buffer.floatChannelData)
            for i in 0..<Int(n) {
                ch[0][i] = 0.1 * sinf(phase)
                phase += 0.05
            }
            try file.write(from: buffer)
            written += n
        }
        return url
    }

    func testDurationExactlyAtThresholdYieldsSingleSlice() throws {
        // 阈值 2 秒，音频恰好 2 秒 → 单片，且复用原文件。
        let url = try writeWAV(seconds: 2.0)
        let slicer = AudioSlicer()
        let slices = try slicer.slice(url, maxSliceDuration: 2.0)
        XCTAssertEqual(slices.count, 1)
        XCTAssertEqual(slices.first?.url, url)
        XCTAssertEqual(slices.first?.index, 0)
    }

    func testDurationSlightlyOverThresholdYieldsTwoSlices() throws {
        // 阈值 2 秒，音频 2.5 秒 → 两片。
        let url = try writeWAV(seconds: 2.5)
        let slicer = AudioSlicer()
        let slices = try slicer.slice(url, maxSliceDuration: 2.0)
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices.map(\.index), [0, 1])
        // 每片时长不超过阈值（含小幅容差）。
        for slice in slices {
            XCTAssertLessThanOrEqual(slice.duration, 2.0 + 0.05)
        }
    }

    func testDurationFarOverThresholdYieldsManySlices() throws {
        // 阈值 1 秒，音频 5 秒 → 5 片。
        let url = try writeWAV(seconds: 5.0)
        let slicer = AudioSlicer()
        let slices = try slicer.slice(url, maxSliceDuration: 1.0)
        XCTAssertEqual(slices.count, 5)
        XCTAssertEqual(slices.map(\.index), [0, 1, 2, 3, 4])
        // 总时长守恒（各片时长之和 ≈ 原时长）。
        let totalDuration = slices.reduce(0) { $0 + $1.duration }
        XCTAssertEqual(totalDuration, 5.0, accuracy: 0.05)
    }

    func testInvalidThresholdThrows() throws {
        let url = try writeWAV(seconds: 1.0)
        let slicer = AudioSlicer()
        XCTAssertThrowsError(try slicer.slice(url, maxSliceDuration: 0)) { error in
            XCTAssertEqual(error as? AudioSlicingError, .invalidThreshold)
        }
    }
}
