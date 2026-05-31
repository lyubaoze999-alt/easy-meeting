import XCTest
@testable import MeetingNotes

/// 录音状态机迁移单元测试（任务 11.2，需求 6.6、6.7）。
///
/// 覆盖待机→录音→暂停→继续→结束的合法迁移、非法迁移被拒、以及时长累计语义。
final class RecordingStateMachineTests: XCTestCase {

    // MARK: - 纯迁移函数

    func testLegalTransitions() {
        XCTAssertEqual(RecordingCoordinator.nextState(from: .idle, on: .start), .recording)
        XCTAssertEqual(RecordingCoordinator.nextState(from: .recording, on: .pause), .paused)
        XCTAssertEqual(RecordingCoordinator.nextState(from: .paused, on: .resume), .recording)
        XCTAssertEqual(RecordingCoordinator.nextState(from: .recording, on: .stop), .finished)
        XCTAssertEqual(RecordingCoordinator.nextState(from: .paused, on: .stop), .finished)
    }

    func testIllegalTransitionsReturnNil() {
        // 待机态不能暂停/继续/结束。
        XCTAssertNil(RecordingCoordinator.nextState(from: .idle, on: .pause))
        XCTAssertNil(RecordingCoordinator.nextState(from: .idle, on: .resume))
        XCTAssertNil(RecordingCoordinator.nextState(from: .idle, on: .stop))
        // 录音中不能再 start / resume。
        XCTAssertNil(RecordingCoordinator.nextState(from: .recording, on: .start))
        XCTAssertNil(RecordingCoordinator.nextState(from: .recording, on: .resume))
        // 暂停态不能 start / pause。
        XCTAssertNil(RecordingCoordinator.nextState(from: .paused, on: .start))
        XCTAssertNil(RecordingCoordinator.nextState(from: .paused, on: .pause))
        // 结束态是终态，任何事件都非法。
        XCTAssertNil(RecordingCoordinator.nextState(from: .finished, on: .start))
        XCTAssertNil(RecordingCoordinator.nextState(from: .finished, on: .stop))
    }

    // MARK: - 端到端迁移 + 时长累计（需求 6.6、6.7）

    /// 音频采集替身：记录被调用的方法，stop 返回固定 URL。
    private final class FakeCapture: AudioCaptureService {
        let systemLevel = AsyncStream<Float> { _ in }
        let micLevel = AsyncStream<Float> { _ in }
        let systemSilent = AsyncStream<Bool> { _ in }
        let micSilent = AsyncStream<Bool> { _ in }
        private(set) var events: [String] = []
        func start() async throws { events.append("start") }
        func pause() { events.append("pause") }
        func resume() { events.append("resume") }
        func stop() async throws -> URL { events.append("stop"); return URL(fileURLWithPath: "/tmp/out.wav") }
    }

    /// 可控时钟。
    private final class FakeClock {
        var now: Date = Date(timeIntervalSince1970: 0)
        func tick(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
    }

    @MainActor
    func testFullLifecycleAndDurationAccumulation() async throws {
        let capture = FakeCapture()
        let clock = FakeClock()
        let template = NoteTemplate(id: "default", name: "默认", isBuiltin: true, instruction: "x")
        let coordinator = RecordingCoordinator(
            audioCapture: capture,
            initialTemplate: template,
            clock: { clock.now }
        )

        // 待机 → 录音
        try await coordinator.start()
        XCTAssertEqual(coordinator.state, .recording)

        // 录音 5 秒
        clock.tick(5)
        XCTAssertEqual(coordinator.elapsedDuration, 5, accuracy: 1e-6)

        // 添加重点标记，记录当前 5 秒
        XCTAssertEqual(coordinator.addHighlight(), 5)

        // 暂停 → 时长冻结
        try coordinator.pause()
        XCTAssertEqual(coordinator.state, .paused)
        clock.tick(10)  // 暂停期间不计入
        XCTAssertEqual(coordinator.elapsedDuration, 5, accuracy: 1e-6)

        // 继续录 3 秒
        try coordinator.resume()
        XCTAssertEqual(coordinator.state, .recording)
        clock.tick(3)
        XCTAssertEqual(coordinator.elapsedDuration, 8, accuracy: 1e-6)

        // 结束 → 时长 = 活跃段之和 = 8 秒（Property 1 对齐）
        let url = try await coordinator.stop()
        XCTAssertEqual(coordinator.state, .finished)
        XCTAssertEqual(url.path, "/tmp/out.wav")
        XCTAssertEqual(coordinator.elapsedDuration, 8, accuracy: 1e-6)

        XCTAssertEqual(capture.events, ["start", "pause", "resume", "stop"])
        XCTAssertEqual(coordinator.highlights, [5])
    }

    @MainActor
    func testIllegalTransitionThrows() async {
        let coordinator = RecordingCoordinator(
            audioCapture: FakeCapture(),
            initialTemplate: NoteTemplate(id: "d", name: "默认", isBuiltin: true, instruction: "x")
        )
        // 待机态点暂停应抛非法迁移。
        await XCTAssertThrowsErrorAsync(try coordinator.pause())
    }

    @MainActor
    func testTemplateSwitchDuringRecording() async throws {
        let coordinator = RecordingCoordinator(
            audioCapture: FakeCapture(),
            initialTemplate: NoteTemplate(id: "d", name: "默认", isBuiltin: true, instruction: "x")
        )
        try await coordinator.start()
        let standup = NoteTemplate(id: "standup", name: "站会", isBuiltin: true, instruction: "y")
        XCTAssertTrue(coordinator.selectTemplate(standup))
        XCTAssertEqual(coordinator.selectedTemplate.id, "standup")
    }
}

/// 同步抛错断言的 async 包装（XCTAssertThrowsError 不支持 async 自动闭包）。
private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    do {
        try expression()
        XCTFail("期望抛出错误但没有", file: file, line: line)
    } catch {
        // 预期抛错。
    }
}
