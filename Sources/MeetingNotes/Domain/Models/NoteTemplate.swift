import Foundation

/// 纪要模板（需求 16）。
///
/// 内置模板（默认 / 站会 / 评审 / 面试）`isBuiltin` 为 true，
/// 用户自定义模板以 `instruction`（纪要指令文本）为核心，
/// 指导总结服务按需要的分区与风格生成纪要。
struct NoteTemplate: Identifiable, Codable, Equatable {
    /// 模板标识。内置模板用固定字符串，自定义模板用生成的唯一值。
    let id: String
    /// 模板名称。
    var name: String
    /// 是否为内置模板（内置模板不可删除）。
    var isBuiltin: Bool
    /// 纪要指令：交给总结服务的提示文本，定义分区结构与生成要求。
    var instruction: String
}
