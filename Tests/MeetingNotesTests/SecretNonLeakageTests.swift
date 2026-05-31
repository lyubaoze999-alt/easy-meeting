import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 5「密钥不外泄」属性测试（需求 15.1、15.2）。
///
/// 不变量：对任意 baseURL / apiKey / model，SettingsStore 持久化后，
/// 写入 UserDefaults 的数据中不得出现 apiKey 明文；同时内存态仍能从
/// Keychain 回填出 apiKey，保证功能不受影响。
final class SecretNonLeakageTests: XCTestCase {

    /// 内存版 Keychain 替身：apiKey 只进这里，不落 UserDefaults。
    private final class FakeKeychain: KeychainStoring {
        private var storage: [KeychainServiceIdentifier: String] = [:]
        func saveAPIKey(_ apiKey: String, for service: KeychainServiceIdentifier) throws {
            storage[service] = apiKey
        }
        func loadAPIKey(for service: KeychainServiceIdentifier) throws -> String? {
            storage[service]
        }
        func deleteAPIKey(for service: KeychainServiceIdentifier) throws {
            storage[service] = nil
        }
    }

    /// 构造一个隔离的 UserDefaults（独立 suite），避免污染标准域。
    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let suite = "test.secret.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (defaults, suite)
    }

    func testAPIKeyNeverLandsInUserDefaults() {
        // 生成非空 apiKey（含可能的特殊字符），以及任意 baseURL / model。
        let nonEmpty = String.arbitrary.suchThat { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        property("apiKey 明文不出现在 UserDefaults 持久化数据中，且内存态可回填") <- forAll(nonEmpty, String.arbitrary, String.arbitrary) { (apiKey: String, baseURL: String, model: String) in
            // 每个样本用独立的 defaults + keychain，互不干扰。
            let (defaults, suite) = self.makeIsolatedDefaults()
            defer { defaults.removePersistentDomain(forName: suite) }
            let keychain = FakeKeychain()

            // SettingsStore 是 @MainActor，测试体内同步驱动主actor。
            let leaked: Bool = MainActor.assumeIsolated {
                let store = SettingsStore(defaults: defaults, keychain: keychain, storageKey: "appSettings")
                store.updateTranscription(ServiceConfig(baseURL: baseURL, apiKey: apiKey, model: model))
                store.updateSummary(ServiceConfig(baseURL: baseURL, apiKey: apiKey, model: model))

                // 1) 读取 UserDefaults 原始数据，apiKey 明文不得出现。
                guard let data = defaults.data(forKey: "appSettings") else { return false }
                let raw = String(data: data, encoding: .utf8) ?? ""
                let appearsInDefaults = raw.contains(apiKey)

                // 2) 内存态仍能拿到 apiKey（从 Keychain 回填），功能不受损。
                let inMemoryHasKey = store.settings.transcription.apiKey == apiKey
                    && store.settings.summary.apiKey == apiKey

                return appearsInDefaults || !inMemoryHasKey
            }
            return !leaked
        }
    }
}
