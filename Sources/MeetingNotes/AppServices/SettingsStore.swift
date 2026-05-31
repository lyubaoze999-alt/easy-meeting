import Foundation
import Combine

/// 可配置的大模型服务种类（需求 15.1、15.2）。
///
/// 用于「服务是否已配置」判定的逐项区分，以及未配置时面向用户的中文提示（需求 15.6）。
/// 与基础设施层的 `KeychainServiceIdentifier` 一一对应，但本枚举只承担应用层的语义与展示，
/// 不直接耦合 Keychain 实现。
enum ConfigurableService: CaseIterable {
    /// 转写服务（需求 15.1）。
    case transcription
    /// 总结服务（需求 15.2）。
    case summary

    /// 面向用户的中文名称（需求 1.1、15.6 的提示文案使用）。
    var displayName: String {
        switch self {
        case .transcription: return "转写服务"
        case .summary: return "总结服务"
        }
    }

    /// 映射到 Keychain 条目标识，用于密钥的安全存取。
    var keychainIdentifier: KeychainServiceIdentifier {
        switch self {
        case .transcription: return .transcription
        case .summary: return .summary
        }
    }
}

/// 配置管理（应用服务层，对应设计「SettingsStore」、需求 15）。
///
/// 职责：
/// - 读写转写/总结服务配置（地址、密钥、模型名）、主题、图文模式（需求 15.1、15.2、15.3、16.6、17.1）。
/// - 提供「服务是否已配置」判定，供处理流程在开始前做阻断提示（需求 15.6）。
///
/// 存储策略（对应设计「存储策略」）：
/// - 轻量偏好（`baseURL`、`model`、主题、图文模式）持久化到 `UserDefaults`。
/// - `apiKey` **仅** 存入 Keychain，落入 `UserDefaults` 的 `AppSettings` 中 `apiKey` 一律置空，
///   守住 Property 5「密钥不外泄」。加载时再从 Keychain 回填 `apiKey` 到内存态。
///
/// 作为 `ObservableObject`，`settings` 变化会驱动后续设置界面刷新。
@MainActor
final class SettingsStore: ObservableObject {
    /// 当前应用配置（内存态，`apiKey` 已从 Keychain 回填）。
    @Published private(set) var settings: AppSettings

    private let defaults: UserDefaults
    private let keychain: KeychainStoring
    private let storageKey: String

    /// 未配置过任何信息时的初始配置：两项服务均为空、跟随系统主题、纯文本模式。
    static let defaultSettings = AppSettings(
        transcription: ServiceConfig(baseURL: "", apiKey: "", model: ""),
        summary: ServiceConfig(baseURL: "", apiKey: "", model: ""),
        theme: .system,
        imageMode: false
    )

    /// - Parameters:
    ///   - defaults: 轻量偏好存储，默认 `.standard`（便于测试注入隔离实例）。
    ///   - keychain: 密钥安全存储，默认 `KeychainStore()`。
    ///   - storageKey: `UserDefaults` 中存放 `AppSettings` JSON 的键名。
    init(defaults: UserDefaults = .standard,
         keychain: KeychainStoring = KeychainStore(),
         storageKey: String = "com.meetingnotes.appSettings") {
        self.defaults = defaults
        self.keychain = keychain
        self.storageKey = storageKey
        self.settings = Self.loadSettings(defaults: defaults, keychain: keychain, storageKey: storageKey)
    }
}

// MARK: - 加载与持久化

extension SettingsStore {
    /// 从 `UserDefaults` 读取轻量偏好，再从 Keychain 回填两项服务的 `apiKey`。
    ///
    /// 无任何持久化记录时返回 `defaultSettings`。Keychain 读取失败按空密钥处理，不影响其余配置加载。
    static func loadSettings(defaults: UserDefaults,
                             keychain: KeychainStoring,
                             storageKey: String) -> AppSettings {
        var loaded = defaultSettings
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loaded = decoded
        }
        // 从 Keychain 回填密钥（落库的 AppSettings 中 apiKey 为空，见 persist）。
        loaded.transcription.apiKey =
            (try? keychain.loadAPIKey(for: .transcription)) .flatMap { $0 } ?? ""
        loaded.summary.apiKey =
            (try? keychain.loadAPIKey(for: .summary)) .flatMap { $0 } ?? ""
        return loaded
    }

    /// 把当前配置持久化：密钥写 Keychain，其余（apiKey 置空）写 UserDefaults。
    private func persist() {
        // 1) 密钥单独入 Keychain（守住 Property 5：明文不落 UserDefaults）。
        try? keychain.saveAPIKey(settings.transcription.apiKey, for: .transcription)
        try? keychain.saveAPIKey(settings.summary.apiKey, for: .summary)

        // 2) 轻量偏好入 UserDefaults，apiKey 一律置空。
        var sanitized = settings
        sanitized.transcription.apiKey = ""
        sanitized.summary.apiKey = ""
        if let data = try? JSONEncoder().encode(sanitized) {
            defaults.set(data, forKey: storageKey)
        }
    }
}

// MARK: - 读写配置

extension SettingsStore {
    /// 更新转写服务配置（地址、密钥、模型名，需求 15.1）。
    func updateTranscription(_ config: ServiceConfig) {
        settings.transcription = config
        persist()
    }

    /// 更新总结服务配置（地址、密钥、模型名，需求 15.2）。
    func updateSummary(_ config: ServiceConfig) {
        settings.summary = config
        persist()
    }

    /// 更新外观主题（需求 17.1）。
    func updateTheme(_ theme: ThemeMode) {
        settings.theme = theme
        persist()
    }

    /// 更新纯文本/图文模式（需求 16.6）。
    func updateImageMode(_ enabled: Bool) {
        settings.imageMode = enabled
        persist()
    }

    /// 读取指定服务的当前配置。
    func config(for service: ConfigurableService) -> ServiceConfig {
        switch service {
        case .transcription: return settings.transcription
        case .summary: return settings.summary
        }
    }
}

// MARK: - 「服务是否已配置」判定（需求 15.6）

extension SettingsStore {
    /// 单项服务是否已完成配置：地址、密钥、模型名均非空（去除首尾空白后）。
    func isConfigured(_ service: ConfigurableService) -> Bool {
        Self.isConfigured(config(for: service))
    }

    /// 转写与总结服务是否都已配置，可用于在进入处理流程前做阻断判定（需求 15.6）。
    var isAllConfigured: Bool {
        isConfigured(.transcription) && isConfigured(.summary)
    }

    /// 返回尚未配置的服务列表，供未配置时拼装中文提示文案（需求 15.6）。
    var unconfiguredServices: [ConfigurableService] {
        ConfigurableService.allCases.filter { !isConfigured($0) }
    }

    /// 判断一份服务配置三要素是否齐备。
    static func isConfigured(_ config: ServiceConfig) -> Bool {
        !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
