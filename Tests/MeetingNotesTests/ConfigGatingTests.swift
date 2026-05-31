import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 4「配置缺失即阻断」属性测试（需求 15.6）。
///
/// 不变量：当转写或总结服务任一三要素（地址/密钥/模型名）为空时，
/// isAllConfigured 必为 false（无法进入处理流程）；仅当两项服务三要素
/// 全部非空时，isAllConfigured 才为 true。
final class ConfigGatingTests: XCTestCase {

    /// 内存版 Keychain 替身。
    private final class FakeKeychain: KeychainStoring {
        private var storage: [KeychainServiceIdentifier: String] = [:]
        func saveAPIKey(_ apiKey: String, for service: KeychainServiceIdentifier) throws { storage[service] = apiKey }
        func loadAPIKey(for service: KeychainServiceIdentifier) throws -> String? { storage[service] }
        func deleteAPIKey(for service: KeychainServiceIdentifier) throws { storage[service] = nil }
    }

    private func makeStore() -> (SettingsStore, UserDefaults, String) {
        let suite = "test.gating.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = MainActor.assumeIsolated {
            SettingsStore(defaults: defaults, keychain: FakeKeychain(), storageKey: "appSettings")
        }
        return (store, defaults, suite)
    }

    /// 生成可能为空或非空的字符串：空概率与非空概率各半，覆盖缺失场景。
    private var fieldGen: Gen<String> {
        Gen.one(of: [
            Gen.pure(""),
            Gen.pure("   "),                       // 纯空白也视为未配置
            String.arbitrary.suchThat { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        ])
    }

    func testIncompleteConfigBlocksPipeline() {
        let g = fieldGen
        property("缺任一要素则 isAllConfigured=false，全齐则为 true") <- forAll(g, g, g, g, g, g) {
            (tURL: String, tKey: String, tModel: String, sURL: String, sKey: String, sModel: String) in
            let (store, defaults, suite) = self.makeStore()
            defer { defaults.removePersistentDomain(forName: suite) }

            return MainActor.assumeIsolated {
                store.updateTranscription(ServiceConfig(baseURL: tURL, apiKey: tKey, model: tModel))
                store.updateSummary(ServiceConfig(baseURL: sURL, apiKey: sKey, model: sModel))

                func filled(_ s: String) -> Bool {
                    !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                let expectedAll = filled(tURL) && filled(tKey) && filled(tModel)
                    && filled(sURL) && filled(sKey) && filled(sModel)

                return store.isAllConfigured == expectedAll
            }
        }
    }
}
