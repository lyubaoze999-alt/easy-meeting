import Foundation

/// 单个大模型服务的连接配置。转写服务、总结服务各持有一份（需求 15.1、15.2）。
///
/// 兼容 OpenAI 协议的服务配置三要素：接口地址、密钥、模型名。
///
/// - Important: 关于 `apiKey` 的持久化约束（对应 Property 5「密钥不外泄」）：
///   该字段仅作为内存中的运行态结构存在。`apiKey` 的明文 **不得** 写入
///   SQLite、日志或导出文件；密钥的安全存储交由 Keychain 处理（后续任务 3.2）。
///   当 `AppSettings` 入库或序列化用于持久化时，应剔除或置空 `apiKey`，
///   仅保留 `baseURL` 与 `model`。
struct ServiceConfig: Codable, Equatable {
    /// 接口地址。按用户输入的原始内容原样使用，不做拼接或改写（需求 1.2）。
    var baseURL: String
    /// 访问密钥。仅存于内存，明文不落库、不入日志、不进导出（见类型说明，Property 5）。
    var apiKey: String
    /// 模型名。按用户输入原样展示与使用（需求 1.2）。
    var model: String
}

/// 主题模式（需求 17.1）：浅色 / 深色 / 跟随系统。
///
/// 原始值用于持久化到 UserDefaults 等轻量偏好存储。
enum ThemeMode: String, Codable {
    case light
    case dark
    case system
}

/// 应用级配置聚合（需求 15、16.6、17.1）。
///
/// - Important: 序列化用于持久化时，内部 `ServiceConfig.apiKey` 的明文不得落库，
///   密钥统一交由 Keychain 管理（后续任务 3.2，对应 Property 5「密钥不外泄」）。
struct AppSettings: Codable, Equatable {
    /// 转写服务配置（需求 15.1）。
    var transcription: ServiceConfig
    /// 总结服务配置（需求 15.2）。
    var summary: ServiceConfig
    /// 外观主题（需求 17.1）。
    var theme: ThemeMode
    /// 图文模式开关：true 为图文模式，false 为纯文本模式（需求 16.6、需求 14）。
    var imageMode: Bool
}
