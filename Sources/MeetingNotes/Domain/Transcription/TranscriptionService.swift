import Foundation

/// 转写服务协议（需求 9.2、9.3、8.4）。
///
/// 将一段音频转为完整文字稿：内部按转写服务单次处理上限切片，逐片调用转写接口，
/// 再把各片结果按原始时间顺序合并为完整转写文本（Property 2「切片转写顺序一致」）。
/// 处理过程中通过 `progress` 回调发布「当前片号 / 总片数」，片号从 1 递增到总片数，
/// 不回退、不跳号（Property 3「进度单调且完整」）。
protocol TranscriptionService {
    /// 转写整段音频，返回按时间顺序拼接的完整文字稿。
    ///
    /// - Parameters:
    ///   - audio: 待转写的 WAV 音频地址（16kHz / 单声道 / 16bit PCM）。
    ///   - config: 转写服务配置（提供 baseURL、apiKey、model）。
    ///   - progress: 每完成一片回调一次，`current` 从 1 递增到 `total`，`total` 为切片总数。
    /// - Returns: 各切片转写文本按原始时间顺序合并后的完整文字稿。
    /// - Throws: `TranscriptionError` 描述切片、网络、解析等异常。
    func transcribe(audio: URL,
                    config: ServiceConfig,
                    progress: (_ current: Int, _ total: Int) -> Void) async throws -> String
}

/// 转写过程中可能抛出的错误（需求 9.2）。
enum TranscriptionError: Error, Equatable {
    /// 音频切片失败，附带底层切片错误描述。
    case slicingFailed(reason: String)
    /// 切片结果为空（音频无有效内容，无可转写片段）。
    case noSlices
    /// 某一片转写的网络/HTTP 调用失败，附带片号（从 1 起）与底层错误描述。
    case sliceRequestFailed(sliceNumber: Int, reason: String)
    /// 某一片转写响应无法解析为预期 JSON 结构，附带片号（从 1 起）。
    case responseDecodingFailed(sliceNumber: Int)
}

/// OpenAI 兼容转写接口的响应体结构：`{"text": "..."}`。
///
/// 仅取 `text` 字段；其余字段（如 `language`、`duration`、`segments`）按需忽略，
/// 保证对返回体的健壮解析。
private struct OpenAITranscriptionResponse: Decodable {
    let text: String
}

/// 基于切片 + OpenAI 兼容客户端的转写实现（需求 9.2、9.3、8.4）。
///
/// 实现要点：
/// - 用注入的 `AudioSlicing` 把音频切分为按 `index` 递增的有序切片。
/// - 严格按 `index` 升序逐片调用 `audio/transcriptions`（multipart 上传切片文件）。
/// - 各片文本按切片顺序（而非完成顺序）拼接为完整文字稿（Property 2）。
/// - 每完成一片，以 `(已完成片数, 总片数)` 触发进度回调，片号 1...total 单调递增（Property 3）。
final class SlicingTranscriptionService: TranscriptionService {
    private let client: OpenAICompatibleClienting
    private let slicer: AudioSlicing
    /// 单片时长上限（秒），超限触发切片。默认取 `AudioSlicer.defaultMaxSliceDuration`。
    private let maxSliceDuration: TimeInterval
    /// 上传切片文件时使用的 MIME 类型（WAV）。
    private let audioMimeType: String

    /// - Parameters:
    ///   - client: OpenAI 兼容客户端，用于调用转写接口（注入便于测试）。
    ///   - slicer: 音频切片能力（注入便于测试）。
    ///   - maxSliceDuration: 单片时长上限（秒），默认 `AudioSlicer.defaultMaxSliceDuration`。
    init(client: OpenAICompatibleClienting,
         slicer: AudioSlicing,
         maxSliceDuration: TimeInterval = AudioSlicer.defaultMaxSliceDuration,
         audioMimeType: String = "audio/wav") {
        self.client = client
        self.slicer = slicer
        self.maxSliceDuration = maxSliceDuration
        self.audioMimeType = audioMimeType
    }

    func transcribe(audio: URL,
                    config: ServiceConfig,
                    progress: (_ current: Int, _ total: Int) -> Void) async throws -> String {
        // 1) 切片：按原始时间顺序得到有序切片（index 从 0 递增）。
        let slices: [AudioSlice]
        do {
            slices = try slicer.slice(audio, maxSliceDuration: maxSliceDuration)
        } catch {
            throw TranscriptionError.slicingFailed(reason: error.localizedDescription)
        }

        guard !slices.isEmpty else {
            throw TranscriptionError.noSlices
        }

        // 2) 强制按 index 升序处理，确保合并顺序与录音时间轴一致（Property 2）。
        let orderedSlices = slices.sorted { $0.index < $1.index }
        let total = orderedSlices.count

        // 3) 逐片转写，文本按切片顺序收集。
        var sliceTexts: [String] = []
        sliceTexts.reserveCapacity(total)

        for (offset, slice) in orderedSlices.enumerated() {
            let sliceNumber = offset + 1   // 面向进度/错误的片号，从 1 起。
            let text = try await transcribeSlice(slice, sliceNumber: sliceNumber, config: config)
            sliceTexts.append(text)
            // 4) 完成一片即发布进度，片号 1...total 单调递增（Property 3）。
            progress(sliceNumber, total)
        }

        // 5) 按原始时间顺序合并为完整文字稿。
        return Self.mergeTranscripts(sliceTexts)
    }

    // MARK: - 私有实现

    /// 转写单个切片：multipart 上传文件 + 模型名，解析 `{"text": "..."}`。
    private func transcribeSlice(_ slice: AudioSlice,
                                 sliceNumber: Int,
                                 config: ServiceConfig) async throws -> String {
        let audioData: Data
        do {
            audioData = try Data(contentsOf: slice.url)
        } catch {
            throw TranscriptionError.sliceRequestFailed(
                sliceNumber: sliceNumber,
                reason: error.localizedDescription
            )
        }

        let parts: [MultipartPart] = [
            .file(
                name: "file",
                filename: slice.url.lastPathComponent,
                mimeType: audioMimeType,
                data: audioData
            ),
            .text(name: "model", value: config.model)
        ]

        let responseData: Data
        do {
            responseData = try await client.postMultipart(
                path: "audio/transcriptions",
                parts: parts,
                config: config
            )
        } catch {
            throw TranscriptionError.sliceRequestFailed(
                sliceNumber: sliceNumber,
                reason: error.localizedDescription
            )
        }

        return try Self.decodeText(from: responseData, sliceNumber: sliceNumber)
    }

    /// 健壮解析转写响应，提取 `text` 字段。
    private static func decodeText(from data: Data, sliceNumber: Int) throws -> String {
        if let decoded = try? JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data) {
            return decoded.text
        }
        // 兜底：部分实现可能把纯文本直接作为响应体返回。
        if let raw = String(data: data, encoding: .utf8),
           data.first != UInt8(ascii: "{") {
            return raw
        }
        throw TranscriptionError.responseDecodingFailed(sliceNumber: sliceNumber)
    }

    /// 将各片文本按原始顺序合并为完整文字稿（Property 2）。
    ///
    /// 逐片去除首尾空白后用空格连接，过滤掉空片，避免出现多余空白。
    static func mergeTranscripts(_ texts: [String]) -> String {
        texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
