import Foundation
import Security

/// Keychain 读写过程中可能出现的错误（需求 15.1、15.2，对应 Property 5「密钥不外泄」）。
enum KeychainError: Error, Equatable {
    /// 待存储的密钥无法编码为 UTF-8 数据。
    case encodingFailed
    /// Keychain 返回的数据无法解码为字符串。
    case decodingFailed
    /// 标识符为空，无法定位条目。
    case invalidIdentifier
    /// 底层 Security 框架返回的非成功状态码（OSStatus）。
    case unhandled(status: OSStatus)
}

/// 服务密钥的安全存储抽象（需求 15.1、15.2）。
///
/// SettingsStore（任务 4.1）通过该协议把 `ServiceConfig.apiKey` 单独存入 Keychain，
/// 而落库的 `AppSettings` 仅保留 `baseURL` 与 `model`，明文密钥不进 SQLite / UserDefaults /
/// 日志 / 导出文件，从而守住 Property 5「密钥不外泄」。
protocol KeychainStoring {
    /// 为指定服务标识保存 apiKey（已存在则覆盖）。
    func saveAPIKey(_ apiKey: String, for service: KeychainServiceIdentifier) throws
    /// 读取指定服务标识的 apiKey；未存储过返回 nil。
    func loadAPIKey(for service: KeychainServiceIdentifier) throws -> String?
    /// 删除指定服务标识的 apiKey；不存在时视为成功（幂等）。
    func deleteAPIKey(for service: KeychainServiceIdentifier) throws
}

/// 服务标识：转写服务与总结服务各自持有一份密钥（需求 15.1、15.2）。
///
/// 原始值用作 Keychain 条目的 `kSecAttrAccount`，稳定且互不冲突。
enum KeychainServiceIdentifier: String, CaseIterable {
    /// 转写服务密钥（需求 15.1）。
    case transcription
    /// 总结服务密钥（需求 15.2）。
    case summary
}

/// 基于 Security 框架 `SecItem` API 的 Keychain 密钥存储实现。
///
/// 所有条目使用统一的 `kSecAttrService`（应用域）+ 区分服务的 `kSecAttrAccount`，
/// 通用密码类型（`kSecClassGenericPassword`）。
struct KeychainStore: KeychainStoring {
    /// Keychain 条目所属的服务域。默认按应用 Bundle 维度隔离，避免与其他应用条目冲突。
    private let serviceDomain: String

    /// - Parameter serviceDomain: Keychain 条目的 `kSecAttrService`，默认取应用标识。
    init(serviceDomain: String = "com.meetingnotes.apikeys") {
        self.serviceDomain = serviceDomain
    }

    func saveAPIKey(_ apiKey: String, for service: KeychainServiceIdentifier) throws {
        let account = service.rawValue
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // 先尝试更新已有条目，避免重复 add 报 errSecDuplicateItem。
        let query = baseQuery(account: account)
        let attributesToUpdate: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            // 条目不存在，执行新增。
            var addQuery = baseQuery(account: account)
            addQuery[kSecValueData as String] = data
            // 仅本设备可解锁后访问，不参与 iCloud 同步，符合密钥不外泄约束。
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(status: addStatus)
            }
        default:
            throw KeychainError.unhandled(status: updateStatus)
        }
    }

    func loadAPIKey(for service: KeychainServiceIdentifier) throws -> String? {
        let account = service.rawValue
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.decodingFailed
            }
            guard let apiKey = String(data: data, encoding: .utf8) else {
                throw KeychainError.decodingFailed
            }
            return apiKey
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandled(status: status)
        }
    }

    func deleteAPIKey(for service: KeychainServiceIdentifier) throws {
        let account = service.rawValue
        let query = baseQuery(account: account)
        let status = SecItemDelete(query as CFDictionary)
        // 不存在时视为成功，保证删除幂等。
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }

    /// 构造定位单条通用密码的基础查询字典。
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceDomain,
            kSecAttrAccount as String: account
        ]
    }
}
