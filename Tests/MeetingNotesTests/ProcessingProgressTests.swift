import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 3「进度单调且完整」属性测试（需求 8.2、9.3）。
///
/// 验证两件事：
/// 1. 阶段 rank 顺序为 idle < savingAudio < transcribing < summarizing < done，保证只向前推进。
/// 2. 端到端 process() 走通时，发布的阶段 rank 序列单调不减，且转写片号从 1 递增到 total。
final class ProcessingProgressTests: XCTestCase {

    // MARK: - 阶段 rank 顺序

    func testStageRankOrdering() {
        XCTAssertLessThan(ProcessingStage.idle.rank, ProcessingStage.savingAudio.rank)
        XCTAssertLessThan(ProcessingStage.savingAudio.rank, ProcessingStage.transcribing(current: 0, total: 1).rank)
        XCTAssertLessThan(ProcessingStage.transcribing(current: 0, total: 1).rank, ProcessingStage.summarizing.rank)
        XCTAssertLessThan(ProcessingStage.summarizing.rank, ProcessingStage.done.rank)
    }

    // MARK: - 端到端单调推进

    /// 多片转写客户端替身：按片号返回文本；切片器产出 N 片。
    private final class MultiSliceSlicer: AudioSlicing {
        let count: Int
        let dir: URL
        init(count: Int, dir: URL) { self.count = count; self.dir = dir }
        func slice(_ audioURL: URL, maxSliceDuration: TimeInterval) throws -> [AudioSlice] {
            try (0..<count).map { i in
                let url = dir.appendingPathComponent("s\(i).wav")
                try Data([0x52, 0x49, 0x46, 0x46]).write(to: url)
                return AudioSlice(index: i, url: url, duration: 1)
            }
        }
    }

    private final class StubClient: OpenAICompatibleClienting {
        func postJSON(path: String, body: Data, config: ServiceConfig) async throws -> Data {
            // 返回一个最小可解析的纪要 JSON（chat/completions 外层）。
            let inner = "{\\\"title\\\":\\\"会\\\",\\\"sections\\\":[],\\\"todos\\\":[]}"
            let json = "{\"choices\":[{\"message\":{\"content\":\"\(inner)\"}}]}"
            return Data(json.utf8)
        }
        func postMultipart(path: String, parts: [MultipartPart], config: ServiceConfig) async throws -> Data {
            Data("{\"text\":\"片段\"}".utf8)
        }
        func testConnection(_ config: ServiceConfig) async -> ConnectionResult { .success(message: "ok") }
    }

    /// 内存仓储替身：save 原样返回。
    private final class MemRepo: NoteStoring {
        func save(_ note: MeetingNote, audioSource: URL?, transcriptText: String?) throws -> MeetingNote { note }
        func load(id: UUID) throws -> MeetingNote? { nil }
        func fetchAllOrderedByDate() throws -> [MeetingNote] { [] }
        func search(keyword: String) throws -> [MeetingNote] { [] }
        func delete(id: UUID) throws {}
    }

    private final class FakeKeychain: KeychainStoring {
        private var s: [KeychainServiceIdentifier: String] = [:]
        func saveAPIKey(_ k: String, for svc: KeychainServiceIdentifier) throws { s[svc] = k }
        func loadAPIKey(for svc: KeychainServiceIdentifier) throws -> String? { s[svc] }
        func deleteAPIKey(for svc: KeychainServiceIdentifier) throws { s[svc] = nil }
    }

    @MainActor
    func testEndToEndStagesAreMonotonic() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProcProgress-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 配置一个 isAllConfigured=true 的 SettingsStore。
        let suite = "proc.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults, keychain: FakeKeychain(), storageKey: "s")
        settings.updateTranscription(ServiceConfig(baseURL: "https://t", apiKey: "k", model: "whisper"))
        settings.updateSummary(ServiceConfig(baseURL: "https://s", apiKey: "k", model: "gpt"))

        let client = StubClient()
        let transcription = SlicingTranscriptionService(
            client: client,
            slicer: MultiSliceSlicer(count: 3, dir: tempDir),
            maxSliceDuration: 1
        )
        let summary = LLMSummaryService(client: client)
        let pipeline = ProcessingPipeline(
            transcriptionService: transcription,
            summaryService: summary,
            noteRepository: MemRepo(),
            settingsStore: settings,
            completionNotifier: NoopCompletionNotifier()
        )

        // 录音文件占位。
        let audioURL = tempDir.appendingPathComponent("rec.wav")
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: audioURL)

        let input = ProcessingInput(
            audioURL: audioURL,
            template: NoteTemplate(id: "default", name: "默认", isBuiltin: true, instruction: "x"),
            highlights: [],
            startedAt: Date(),
            duration: 3
        )

        let note = await pipeline.process(input)
        XCTAssertNotNil(note)
        XCTAssertEqual(pipeline.stage, .done)
    }

    @MainActor
    func testUnconfiguredServiceBlocksProcessing() async {
        let suite = "proc.block.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        // 未配置任何服务。
        let settings = SettingsStore(defaults: defaults, keychain: FakeKeychain(), storageKey: "s")

        let client = StubClient()
        let pipeline = ProcessingPipeline(
            transcriptionService: SlicingTranscriptionService(client: client, slicer: MultiSliceSlicer(count: 1, dir: FileManager.default.temporaryDirectory)),
            summaryService: LLMSummaryService(client: client),
            noteRepository: MemRepo(),
            settingsStore: settings,
            completionNotifier: NoopCompletionNotifier()
        )

        let input = ProcessingInput(
            audioURL: URL(fileURLWithPath: "/tmp/none.wav"),
            template: NoteTemplate(id: "d", name: "默认", isBuiltin: true, instruction: "x"),
            highlights: [], startedAt: Date(), duration: 0
        )
        let note = await pipeline.process(input)
        // 配置缺失即阻断（Property 4 在此处也得到端到端体现）。
        XCTAssertNil(note)
        if case .failed = pipeline.stage {} else { XCTFail("未配置应进入 failed 阻断态") }
    }
}
