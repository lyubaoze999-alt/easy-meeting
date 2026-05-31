import Foundation

/// 图文模式下的可视化数据（需求 14.2）。
///
/// 三类可视化结构均为可选：模型未产出对应内容时为 nil，
/// 由界面层在图文模式下按需渲染，纯文本模式不读取本结构。
struct NoteVisuals: Codable, Equatable {
    /// 时间线节点列表。
    var timeline: [TimelineNode]?
    /// 思维导图根节点。
    var mindmap: MindmapNode?
    /// 关键数字卡片列表。
    var keyNumbers: [KeyNumber]?
}

/// 时间线节点：会议进程中的一个时间点及其描述。
struct TimelineNode: Codable, Equatable {
    /// 时间标签（如 "00:05" 或 "会议中段"），按模型输出文本保留。
    var time: String
    /// 该时间点对应的标题。
    var title: String
    /// 详细描述，可选。
    var detail: String?
}

/// 思维导图节点，递归结构表达层级关系。
struct MindmapNode: Codable, Equatable {
    /// 节点文本。
    var title: String
    /// 子节点列表，叶子节点为空数组。
    var children: [MindmapNode]
}

/// 关键数字卡片：从会议中提炼的一个量化指标。
struct KeyNumber: Codable, Equatable {
    /// 指标名称（如 "目标转化率"）。
    var label: String
    /// 指标数值文本（如 "15%"、"3 个"），按模型输出原样保留。
    var value: String
    /// 补充说明，可选。
    var note: String?
}
