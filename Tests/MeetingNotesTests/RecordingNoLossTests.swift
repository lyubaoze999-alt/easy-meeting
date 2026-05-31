import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 1「录音不丢段」属性测试（需求 6.6、6.7）。
///
/// CoreAudioCaptureService 用「写入门闸 isWritingEnabled」实现暂停/继续：
/// 暂停期间混音帧不落盘，继续后紧接已录内容追加，最终 WAV 时长 = 各活跃段时长之和。
/// 真实音频图依赖硬件无法在无人值守环境运行，这里把门闸语义抽象为纯逻辑模型 `WriteGateModel`，
/// 对任意「活跃/暂停」段序列验证：累计写入时长恒等于活跃段时长之和，无丢失、无重叠。
final class RecordingNoLossTests: XCTestCase {

    /// 写入门闸纯逻辑模型，复刻 CoreAudioCaptureService 的 pause/resume 语义。
    struct WriteGateModel {
        private(set) var writtenDuration: TimeInterval = 0
        private var writingEnabled = true

        mutating func pause() { writingEnabled = false }
        mutating func resume() { writingEnabled = true }

        /// 喂入一段时长的混音帧：仅在门闸开启时累计写入（模拟落盘）。
        mutating func feed(_ duration: TimeInterval) {
            if writingEnabled { writtenDuration += duration }
        }
    }

    /// 一段录音事件：要么是一段活跃时长，要么是暂停/继续切换。
    enum Segment {
        case active(TimeInterval)   // 门闸开启时的一段时长
        case paused(TimeInterval)   // 门闸关闭时的一段时长
    }

    func testWrittenDurationEqualsSumOfActiveSegments() {
        // 生成 0...20 段，每段为活跃或暂停，时长 0...10 秒。
        let durationGen = Gen<TimeInterval>.choose((0, 10_000)).map { TimeInterval($0) / 1000.0 }
        let segGen: Gen<Segment> = Gen<Bool>.fromElements(of: [true, false]).flatMap { isActive in
            durationGen.map { isActive ? .active($0) : .paused($0) }
        }
        let segsGen = segGen.proliferate.suchThat { $0.count <= 20 }

        property("写入时长 = 活跃段时长之和") <- forAll(segsGen) { (segments: [Segment]) in
            var model = WriteGateModel()
            var expectedActive: TimeInterval = 0
            for seg in segments {
                switch seg {
                case let .active(d):
                    model.resume()
                    model.feed(d)
                    expectedActive += d
                case let .paused(d):
                    model.pause()
                    model.feed(d)   // 暂停期间喂入不应被写入
                }
            }
            return abs(model.writtenDuration - expectedActive) < 1e-9
        }
    }

    func testPausedFramesAreNeverWritten() {
        var model = WriteGateModel()
        model.feed(1.0)       // 活跃：+1
        model.pause()
        model.feed(5.0)       // 暂停：丢弃
        model.resume()
        model.feed(2.0)       // 活跃：+2
        XCTAssertEqual(model.writtenDuration, 3.0, accuracy: 1e-9)
    }
}
