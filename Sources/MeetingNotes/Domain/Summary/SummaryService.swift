import Foundation

/// 纪要生成服务协议（需求 7、12、16，对应设计「纪要生成（SummaryService）」）。
///
/// 依据所选模板，把完整转写文本整理为结构化纪要：
/// - 按模板的纪要指令组织分区（需求 16.2）。
/// - 把重点标记时间点作为聚焦输入提供给总结服务（需求 7.3）。
/// - 命中重点标记的分区在结果中标注 `isHighlighted`（需求 7.4）。
/// - 解析模型输出为 `MeetingNote`（含 sections、todos，需求 12.2）。
///
/// `imageMode` 为图文模式开关：开启时需额外生成可视化结构化数据（需求 16.5、14.2）。
/// 本协议保留该参数，可视化数据的生成与解析由任务 9.2 实现，本任务（9.1）只覆盖文字路径。
protocol SummaryService {
    /// 依据模板把转写文本生成为结构化纪要。
    ///
    /// - Parameters:
    ///   - transcript: 完整转写文本（可能含口语化表达与识别误差）。
    ///   - template: 所选纪要模板，其 `instruction` 定义分区结构（需求 16.2）。
    ///   - highlights: 重点标记时间点（相对录音起点的秒数，需求 7.3）。
    ///   - imageMode: 图文模式开关；true 时额外生成可视化数据（由任务 9.2 实现）。
    ///   - config: 总结服务配置（提供 baseURL、apiKey、model）。
    /// - Returns: 解析后的结构化纪要 `MeetingNote`。
    /// - Throws: `SummaryError` 描述请求、解析等异常。
    func summarize(transcript: String,
                   template: NoteTemplate,
                   highlights: [TimeInterval],
                   imageMode: Bool,
                   config: ServiceConfig) async throws -> MeetingNote
}

/// 生成纪要时的补充上下文，用于补齐 `MeetingNote` 中总结阶段无法得知的字段。
///
/// 录音时间、时长、音频/转写文件路径在「音频保存 → 转写」阶段才确定，
/// 由编排层（任务 12.1 的 ProcessingPipeline）在调用时传入；
/// 不传则使用占位值，待后续阶段回填。
struct SummaryContext: Equatable {
    /// 纪要唯一标识，同时用作文件归档目录名。
    var noteId: UUID
    /// 录音开始时间。
    var startedAt: Date
    /// 录音总时长（秒）。
    var duration: TimeInterval
    /// 混音 WAV 文件路径。
    var audioPath: String
    /// 原始转写文本文件路径。
    var transcriptPath: String

    init(noteId: UUID = UUID(),
         startedAt: Date = Date(),
         duration: TimeInterval = 0,
         audioPath: String = "",
         transcriptPath: String = "") {
        self.noteId = noteId
        self.startedAt = startedAt
        self.duration = duration
        self.audioPath = audioPath
        self.transcriptPath = transcriptPath
    }

    /// 缺省占位上下文：字段待编排层回填。
    static let placeholder = SummaryContext()
}

/// 生成纪要过程中可能抛出的错误（需求 12.2）。
enum SummaryError: Error, Equatable {
    /// 调用总结服务的网络/HTTP 请求失败，附带底层错误描述。
    case requestFailed(reason: String)
    /// 总结服务响应无法解析为预期的 chat/completions 结构。
    case responseDecodingFailed
    /// 响应中没有可用的生成内容（choices 为空或 content 为空）。
    case emptyContent
    /// 模型返回的内容无法解析为预期的纪要 JSON 结构。
    case contentDecodingFailed
}
