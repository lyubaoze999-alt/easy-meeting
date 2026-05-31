import Foundation

/// 纪要主体。
///
/// 一次会议录制完成后生成的结构化纪要，元数据入库，音频与原始转写存文件。
/// 对应需求 12.1（结构化纪要）、12.3（待办）、7.4（重点标记）、14.2（图文可视化）。
struct MeetingNote: Identifiable, Codable, Equatable {
    /// 纪要唯一标识，同时用于音频 / 转写 / 正文文件的归档目录名。
    let id: UUID
    /// 会议标题（生成或用户编辑）。
    var title: String
    /// 录音开始时间。
    var startedAt: Date
    /// 录音总时长（秒）。
    var duration: TimeInterval
    /// 混音后的 WAV 文件路径。
    var audioPath: String
    /// 原始转写文本文件路径。
    var transcriptPath: String
    /// 生成所用模板的标识。
    var templateId: String
    /// 结构化分区（由模板决定，如 摘要 / 关键决策 / 讨论要点）。
    var sections: [NoteSection]
    /// 待办事项列表（需求 12.4）。
    var todos: [TodoItem]
    /// 重点标记时间点（相对录音起点的秒数，需求 7）。
    var highlights: [TimeInterval]
    /// 图文模式下的可视化数据，纯文本模式为 nil（需求 14）。
    var visuals: NoteVisuals?
}

/// 纪要分区，对应模板划分的一个内容块（如 摘要 / 关键决策 / 讨论要点）。
struct NoteSection: Codable, Equatable {
    /// 分区标题。
    var heading: String
    /// 分区正文内容。
    var content: String
    /// 命中重点标记时标注为 true（需求 7.4）。
    var isHighlighted: Bool
}

/// 待办事项（需求 12.4）。
struct TodoItem: Codable, Equatable {
    /// 待办内容。
    var text: String
    /// 是否已完成。
    var done: Bool
    /// 责任人，未识别到则为 nil。
    var owner: String?
    /// 截止时间，按原文文本保留，未识别到则为 nil。
    var dueDate: String?
}
