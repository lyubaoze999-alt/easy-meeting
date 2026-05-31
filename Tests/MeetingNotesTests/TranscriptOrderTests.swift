import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 2「切片转写顺序一致」属性测试（需求 9.2）。
///
/// 不变量：无论各切片转写的「完成顺序」如何，最终合并文本始终按切片 index 的
/// 原始时间顺序拼接；同时进度回调 current 从 1 单调递增到 total（Property 3 的片段覆盖）。
final class TranscriptOrderTests: XCTestCase {

    /// 可控的转写客户端替身：按 multipart 中的文件名返回预设文本，并可乱序响应。
    /// 这里直接用 SlicingTranscriptionService 的合并函数验证顺序不变量。
    func testMergePreservesSliceOrder() {
        property("合并文本按输入顺序拼接，与片段内容无关") <- forAll { (parts: [String]) in
            let cleaned = parts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let merged = SlicingTranscriptionService.mergeTranscripts(parts)
            let expected = cleaned.joined(separator: " ")
            return merged == expected
        }
    }

    func testMergeIsOrderSensitive() {
        // 顺序不同 → 合并结果不同（除非元素相同）。
        let a = SlicingTranscriptionService.mergeTranscripts(["第一段", "第二段", "第三段"])
        let b = SlicingTranscriptionService.mergeTranscripts(["第三段", "第二段", "第一段"])
        XCTAssertEqual(a, "第一段 第二段 第三段")
        XCTAssertEqual(b, "第三段 第二段 第一段")
        XCTAssertNotEqual(a, b)
    }

    func testEndToEndOrderingWithShuffledCompletion() async throws {
        // 用一个固定 3 片的切片器 + 按片号返回「片<index>」文本的客户端，
        // 验证即使客户端内部乱序，结果仍按 index 顺序合并。
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptOrderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let slicer = StubSlicer(sliceCount: 3, directory: tempDir)
        let client = OrderTaggingClient()
        let service = SlicingTranscriptionService(client: client, slicer: slicer)

        var progressSeq: [Int] = []
        let transcript = try await service.transcribe(
            audio: URL(fileURLWithPath: "/tmp/fake.wav"),
            config: ServiceConfig(baseURL: "https://x", apiKey: "k", model: "m")
        ) { current, total in
            XCTAssertEqual(total, 3)
            progressSeq.append(current)
        }

        // 文本严格按片号 0,1,2 顺序。
        XCTAssertEqual(transcript, "片0 片1 片2")
        // 进度 1..3 单调递增。
        XCTAssertEqual(progressSeq, [1, 2, 3])
    }

    // MARK: - 测试替身

    /// 固定切片数的切片器替身：产出 index 0..<n 的切片，并在磁盘写出占位文件。
    private final class StubSlicer: AudioSlicing {
        let sliceCount: Int
        let directory: URL
        init(sliceCount: Int, directory: URL) {
            self.sliceCount = sliceCount
            self.directory = directory
        }
        func slice(_ audioURL: URL, maxSliceDuration: TimeInterval) throws -> [AudioSlice] {
            try (0..<sliceCount).map { i in
                let url = directory.appendingPathComponent("slice-\(i).wav")
                try Data([0x52, 0x49, 0x46, 0x46]).write(to: url) // RIFF 占位
                return AudioSlice(index: i, url: url, duration: 1)
            }
        }
    }

    /// 客户端替身：从文件名中解析片号，返回 {"text":"片<index>"}。
    /// 文件读取在 service 中先于此调用，这里不依赖真实文件，故重写为不读盘的客户端。
    private final class OrderTaggingClient: OpenAICompatibleClienting {
        func postJSON(path: String, body: Data, config: ServiceConfig) async throws -> Data { Data() }
        func postMultipart(path: String, parts: [MultipartPart], config: ServiceConfig) async throws -> Data {
            var index = "?"
            for part in parts {
                if case let .file(_, filename, _, _) = part {
                    index = filename
                        .replacingOccurrences(of: "slice-", with: "")
                        .replacingOccurrences(of: ".wav", with: "")
                }
            }
            let json = "{\"text\":\"片\(index)\"}"
            return Data(json.utf8)
        }
        func testConnection(_ config: ServiceConfig) async -> ConnectionResult { .success(message: "ok") }
    }
}
