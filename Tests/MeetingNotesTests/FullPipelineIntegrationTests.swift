import XCTest
import AVFoundation
@testable import MeetingNotes

/// 全链路集成测试（任务 18.2，需求 8.1、8.2、8.7、8.8）。
///
/// 用本地 mock 的 OpenAI 兼容客户端跑通「转写 → 生成 → 落库 → 展示」：
/// - 真实 AudioSlicer 切分一个临时 WAV；
/// - mock 客户端返回转写文本与结构化纪要 JSON；
/// - 真实 NoteRepository 落库到临时沙盒，再读回校验；
/// - 校验阶段进度推进到 done、生成纪要非空、后台通知被触发。
final class FullPipelineIntegrationTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FullPipeline-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.removeItem(at: tempDir)
        }
        tempDir = nil
    }

    // MARK: - Mocks

    /// mock OpenAI 兼容客户端：转写返回固定文本，chat/completions 返回结构化纪要 JSON。
    private final class MockClient: OpenAICompatibleClienting {
        func postJSON(path: String, body: Data, config: ServiceConfig) async throws -> Data {
            let inner = "{\\\"title\\\":\\\"季度评审会\\\",\\\"sections\\\":[{\\\"heading\\\":\\\"会议摘要\\\",\\\"content\\\":\\\"评审了季度目标。\\\",\\\"isHighlighted\\\":false}],\\\"todos\\\":[{\\\"text\\\":\\\"跟进排期\\\",\\\"owner\\\":\\\"张三\\\",\\\"dueDate\\\":\\\"周五\\\"}]}"
            let json = "{\"choices\":[{\"message\":{\"content\":\"\(inner)\"}}]}"
            return Data(json.utf8)
        }
        func postMultipart(path: String, parts: [MultipartPart], config: ServiceConfig) async throws -> Data {
            Data("{\"text\":\"这是一段会议转写文本。\"}".utf8)
        }
        func testConnection(_ config: ServiceConfig) async -> ConnectionResult { .success(message: "ok") }
    }

    /// 记录是否发出完成通知的替身（需求 8.7）。
    private final class SpyNotifier: CompletionNotifying {
        private(set) var notified = false
        private(set) var notifiedTitle: String?
        func requestAuthorization() async -> Bool { true }
        func notifyCompletion(meetingTitle: String) async {
            notified = true
            notifiedTitle = meetingTitle
        }
    }

    private final class FakeKeychain: KeychainStoring {
        private var s: [KeychainServiceIdentifier: String] = [:]
        func saveAPIKey(_ k: String, for svc: KeychainServiceIdentifier) throws { s[svc] = k }
        func loadAPIKey(for svc: KeychainServiceIdentifier) throws -> String? { s[svc] }
        func deleteAPIKey(for svc: KeychainServiceIdentifier) throws { s[svc] = nil }
    }

    // MARK: - 辅助

    /// 写一个约 3 秒的 16kHz/单声道 WAV。
    private func writeWAV(seconds: Double) throws -> URL {
        let url = tempDir.appendingPathComponent("rec.wav")
        let format = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioCaptureFormat.sampleRate,
            channels: AudioCaptureFormat.channelCount,
            interleaved: false
        ))
        let file = try AVAudioFile(forWriting: url, settings: AudioCaptureFormat.wavSettings)
        let total = AVAudioFrameCount((AudioCaptureFormat.sampleRate * seconds).rounded())
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total))
        buffer.frameLength = total
        let ch = try XCTUnwrap(buffer.floatChannelData)
        for i in 0..<Int(total) { ch[0][i] = 0.05 * sinf(Float(i) * 0.05) }
        try file.write(from: buffer)
        return url
    }

    // MARK: - 端到端

    @MainActor
    func testEndToEndTranscribeGeneratePersistAndNotify() async throws {
        // 配置好的 SettingsStore（两服务均已配置，图文模式关闭）。
        let suite = "fullpipe.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults, keychain: FakeKeychain(), storageKey: "s")
        settings.updateTranscription(ServiceConfig(baseURL: "https://t", apiKey: "k", model: "whisper-1"))
        settings.updateSummary(ServiceConfig(baseURL: "https://s", apiKey: "k", model: "gpt-4o-mini"))

        let client = MockClient()
        let repository = try NoteRepository(baseDirectory: tempDir.appendingPathComponent("store"))
        let notifier = SpyNotifier()
        let pipeline = ProcessingPipeline(
            transcriptionService: SlicingTranscriptionService(client: client, slicer: AudioSlicer()),
            summaryService: LLMSummaryService(client: client),
            noteRepository: repository,
            settingsStore: settings,
            completionNotifier: notifier
        )

        // 用户选择后台继续 → 完成后应发通知（需求 8.6、8.7）。
        await pipeline.continueInBackgroundAndNotify()

        let audioURL = try writeWAV(seconds: 3)
        let template = TemplateManager.makeBuiltinTemplates().first { $0.id == TemplateManager.BuiltinID.default }!
        let input = ProcessingInput(
            audioURL: audioURL,
            template: template,
            highlights: [],
            startedAt: Date(),
            duration: 3
        )

        let note = await pipeline.process(input)

        // 1) 处理成功，阶段到 done（需求 8.8）。
        XCTAssertNotNil(note)
        XCTAssertEqual(pipeline.stage, .done)

        // 2) 生成纪要内容正确（来自 mock 总结）。
        XCTAssertEqual(note?.title, "季度评审会")
        XCTAssertEqual(note?.sections.first?.heading, "会议摘要")
        XCTAssertEqual(note?.todos.first?.owner, "张三")

        // 3) 已落库，可从仓储读回（需求 8.1 的落库环节）。
        let reloaded = try repository.load(id: try XCTUnwrap(note?.id))
        XCTAssertEqual(reloaded?.title, "季度评审会")

        // 4) 后台通知已触发，标题正确（需求 8.7）。
        XCTAssertTrue(notifier.notified)
        XCTAssertEqual(notifier.notifiedTitle, "季度评审会")

        // 5) 音频信息已产出（需求 8.3）。
        XCTAssertNotNil(pipeline.audioInfo)
        XCTAssertGreaterThan(pipeline.audioInfo?.fileSizeBytes ?? 0, 0)
    }
}
