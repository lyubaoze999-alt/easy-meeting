import XCTest
import SwiftCheck
@testable import MeetingNotes

/// Property 8「界面文案全中文」属性测试（需求 1.1、1.2）。
///
/// 应用自有文案（状态名、模板名、错误提示等）必须含中文；用户输入的技术值
/// （接口地址、模型名）按原样透传，不被改写。本测试覆盖可纯逻辑校验的部分：
/// - 各状态 / 阶段 / 服务的 displayName 含中文（需求 1.1）；
/// - ServiceConfig 的 baseURL / model 在「落库再回填」往返中保持原样（需求 1.2）。
final class ChineseCopyTests: XCTestCase {

    /// 判断字符串是否含至少一个 CJK 统一表意文字。
    private func containsChinese(_ s: String) -> Bool {
        s.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }

    // MARK: - 应用自有文案为中文（需求 1.1）

    func testRecordingStateDisplayNamesAreChinese() {
        for state in [RecordingState.idle, .recording, .paused, .finished] {
            XCTAssertTrue(containsChinese(state.displayName), "状态名应为中文：\(state.displayName)")
        }
    }

    func testProcessingStageDisplayNamesAreChinese() {
        let stages: [ProcessingStage] = [
            .idle, .savingAudio, .transcribing(current: 1, total: 2), .summarizing, .done,
            .failed(.audioUnavailable(reason: "x"))
        ]
        for stage in stages {
            XCTAssertTrue(containsChinese(stage.displayName), "阶段名应为中文：\(stage.displayName)")
        }
    }

    func testConfigurableServiceDisplayNamesAreChinese() {
        for service in ConfigurableService.allCases {
            XCTAssertTrue(containsChinese(service.displayName), "服务名应为中文：\(service.displayName)")
        }
    }

    func testThemeAndTemplateNamesAreChinese() {
        for template in TemplateManager.makeBuiltinTemplates() {
            XCTAssertTrue(containsChinese(template.name), "内置模板名应为中文：\(template.name)")
            XCTAssertTrue(containsChinese(template.instruction), "内置模板指令应为中文")
        }
    }

    func testProcessingErrorMessagesAreChinese() {
        let errors: [ProcessingError] = [
            .servicesNotConfigured([.transcription]),
            .audioUnavailable(reason: "x"),
            .transcriptionFailed(reason: "x"),
            .summarizationFailed(reason: "x"),
            .persistenceFailed(reason: "x")
        ]
        for error in errors {
            XCTAssertTrue(containsChinese(error.message), "错误提示应为中文：\(error.message)")
        }
    }

    // MARK: - 用户输入技术值原样透传（需求 1.2）

    func testUserInputBaseURLAndModelPreservedVerbatim() {
        // 任意非空 baseURL / model：经 SettingsStore 落库 + Keychain 回填后应原样保留。
        final class FakeKeychain: KeychainStoring {
            private var s: [KeychainServiceIdentifier: String] = [:]
            func saveAPIKey(_ k: String, for svc: KeychainServiceIdentifier) throws { s[svc] = k }
            func loadAPIKey(for svc: KeychainServiceIdentifier) throws -> String? { s[svc] }
            func deleteAPIKey(for svc: KeychainServiceIdentifier) throws { s[svc] = nil }
        }
        let urlGen = String.arbitrary.suchThat { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let modelGen = String.arbitrary.suchThat { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        property("baseURL / model 落库回填后原样保留") <- forAll(urlGen, modelGen) { (url: String, model: String) in
            MainActor.assumeIsolated {
                let suite = "test.copy.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                let store = SettingsStore(defaults: defaults, keychain: FakeKeychain(), storageKey: "s")
                store.updateTranscription(ServiceConfig(baseURL: url, apiKey: "k", model: model))
                let reloaded = store.config(for: .transcription)
                return reloaded.baseURL == url && reloaded.model == model
            }
        }
    }
}
