import SwiftUI

/// 服务配置界面的视图模型（界面层，任务 16.1，需求 15.1-15.5）。
///
/// 持有转写服务与总结服务两份「编辑草稿」（`ServiceConfig`），与 `SettingsStore` 中的
/// 已保存配置解耦：用户在界面上的修改先落在草稿里，点击「保存」才经 `SettingsStore` 的
/// `updateTranscription` / `updateSummary` 持久化（密钥仍仅入 Keychain，见 `SettingsStore`）。
///
/// 连接测试（需求 15.4）通过注入的 `OpenAICompatibleClienting.testConnection` 完成，结果以
/// 中文 `ConnectionResult` 形式暴露给视图展示（需求 1.1、1.2）。
///
/// 作为 `@MainActor ObservableObject`，所有 `@Published` 状态变更都在主线程，可安全驱动 UI。
@MainActor
final class ServiceConfigViewModel: ObservableObject {
    /// 转写服务编辑草稿（需求 15.1）。
    @Published var transcriptionDraft: ServiceConfig
    /// 总结服务编辑草稿（需求 15.2）。
    @Published var summaryDraft: ServiceConfig

    /// 转写服务最近一次连接测试结果（需求 15.4）。nil 表示尚未测试。
    @Published var transcriptionResult: ConnectionResult?
    /// 总结服务最近一次连接测试结果（需求 15.4）。nil 表示尚未测试。
    @Published var summaryResult: ConnectionResult?

    /// 转写服务连接测试进行中标识（用于禁用按钮、展示进度）。
    @Published var isTestingTranscription = false
    /// 总结服务连接测试进行中标识。
    @Published var isTestingSummary = false

    /// 转写服务「已保存」瞬时提示标识。
    @Published var transcriptionSaved = false
    /// 总结服务「已保存」瞬时提示标识。
    @Published var summarySaved = false

    private let settings: SettingsStore
    private let client: OpenAICompatibleClienting

    /// 转写服务的常用模型快捷项（需求 15.3）。为合理默认值，用户可在自定义输入项中改写。
    static let transcriptionCommonModels = ["whisper-1", "whisper-large-v3"]
    /// 总结服务的常用模型快捷项（需求 15.3）。
    static let summaryCommonModels = ["gpt-4o-mini", "gpt-4o", "deepseek-chat"]

    /// - Parameters:
    ///   - settings: 配置管理（提供已保存配置并承接保存动作）。
    ///   - client: OpenAI 兼容客户端，默认 `OpenAICompatibleClient()`，用于连接测试。
    init(settings: SettingsStore,
         client: OpenAICompatibleClienting = OpenAICompatibleClient()) {
        self.settings = settings
        self.client = client
        self.transcriptionDraft = settings.config(for: .transcription)
        self.summaryDraft = settings.config(for: .summary)
    }

    /// 指定服务的常用模型快捷项（需求 15.3）。
    func commonModels(for service: ConfigurableService) -> [String] {
        switch service {
        case .transcription: return Self.transcriptionCommonModels
        case .summary: return Self.summaryCommonModels
        }
    }

    /// 保存转写服务草稿到 `SettingsStore`（需求 15.1）。展示瞬时「已保存」提示。
    func saveTranscription() {
        settings.updateTranscription(transcriptionDraft)
        flashSaved(.transcription)
    }

    /// 保存总结服务草稿到 `SettingsStore`（需求 15.2）。
    func saveSummary() {
        settings.updateSummary(summaryDraft)
        flashSaved(.summary)
    }

    /// 对转写服务发起连接测试（需求 15.4）。
    func testTranscription() async {
        isTestingTranscription = true
        transcriptionResult = nil
        let result = await client.testConnection(transcriptionDraft)
        transcriptionResult = result
        isTestingTranscription = false
    }

    /// 对总结服务发起连接测试（需求 15.4）。
    func testSummary() async {
        isTestingSummary = true
        summaryResult = nil
        let result = await client.testConnection(summaryDraft)
        summaryResult = result
        isTestingSummary = false
    }

    /// 触发「已保存」瞬时提示，短暂展示后自动收起。
    private func flashSaved(_ service: ConfigurableService) {
        switch service {
        case .transcription: transcriptionSaved = true
        case .summary: summarySaved = true
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            switch service {
            case .transcription: self.transcriptionSaved = false
            case .summary: self.summarySaved = false
            }
        }
    }
}

/// 服务配置界面（界面层，任务 16.1，需求 15.1-15.5）。
///
/// 自上而下展示：
/// - OpenAI 兼容协议提示条（需求 15.5）；
/// - 转写服务配置表单（接口地址、密钥、模型名、常用模型快捷选择 + 自定义输入、连接测试，需求 15.1、15.3、15.4）；
/// - 总结服务配置表单（同上，需求 15.2、15.3、15.4）。
///
/// 取色全部来自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；自有文案均为中文
/// （需求 1.1），用户填写的接口地址与模型名按原样展示与使用（需求 1.2）。
struct ServiceConfigView: View {
    @Environment(\.themeTokens) private var tokens
    @StateObject private var viewModel: ServiceConfigViewModel

    /// - Parameters:
    ///   - settings: 配置管理。
    ///   - client: OpenAI 兼容客户端，默认 `OpenAICompatibleClient()`，用于连接测试（需求 15.4）。
    init(settings: SettingsStore,
         client: OpenAICompatibleClienting = OpenAICompatibleClient()) {
        _viewModel = StateObject(wrappedValue: ServiceConfigViewModel(settings: settings, client: client))
    }

    /// 仅供预览 / 测试注入已构造的视图模型。
    init(viewModel: ServiceConfigViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 3) {
                compatibilityHint

                ServiceConfigForm(
                    title: ConfigurableService.transcription.displayName,
                    iconName: "waveform",
                    commonModels: viewModel.commonModels(for: .transcription),
                    config: $viewModel.transcriptionDraft,
                    result: viewModel.transcriptionResult,
                    isTesting: viewModel.isTestingTranscription,
                    isSaved: viewModel.transcriptionSaved,
                    onTest: { Task { await viewModel.testTranscription() } },
                    onSave: { viewModel.saveTranscription() }
                )

                ServiceConfigForm(
                    title: ConfigurableService.summary.displayName,
                    iconName: "text.append",
                    commonModels: viewModel.commonModels(for: .summary),
                    config: $viewModel.summaryDraft,
                    result: viewModel.summaryResult,
                    isTesting: viewModel.isTestingSummary,
                    isSaved: viewModel.summarySaved,
                    onTest: { Task { await viewModel.testSummary() } },
                    onSave: { viewModel.saveSummary() }
                )
            }
            .padding(tokens.spacingUnit * 3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(tokens.background)
    }
}

// MARK: - OpenAI 兼容提示（需求 15.5）

private extension ServiceConfigView {
    /// 提示转写服务与总结服务支持兼容 OpenAI 协议的服务（需求 15.5）。
    var compatibilityHint: some View {
        HStack(alignment: .top, spacing: tokens.spacingUnit) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(tokens.accentPrimary)
            Text("转写服务与总结服务均支持兼容 OpenAI 协议的服务，填写各自的接口地址、密钥与模型名即可。")
                .font(.callout)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(tokens.spacingUnit * 1.5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.accentSecondary.opacity(0.25))
        )
    }
}

/// 单个服务的配置表单（转写或总结共用，需求 15.1-15.4）。
///
/// 展示接口地址、密钥（`SecureField`）、模型名三项配置（需求 15.1、15.2），其中模型名提供
/// 常用模型快捷选择（`Menu`）与自定义输入（`TextField`）（需求 15.3）；底部「连接测试」按钮
/// 触发 `onTest` 并展示中文结果（需求 15.4），「保存」按钮触发 `onSave`。
///
/// 纯展示视图：配置经 `@Binding` 双向绑定，交互经回调上抛，不直接持有业务服务。
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4）；用户填写的地址、模型名原样展示（需求 1.2）。
private struct ServiceConfigForm: View {
    @Environment(\.themeTokens) private var tokens

    /// 服务中文名称（如「转写服务」）。
    let title: String
    /// 卡片标题处的图标名。
    let iconName: String
    /// 该服务的常用模型快捷项（需求 15.3）。
    let commonModels: [String]
    /// 配置草稿的双向绑定（地址、密钥、模型名）。
    @Binding var config: ServiceConfig
    /// 最近一次连接测试结果（需求 15.4），nil 表示未测试。
    let result: ConnectionResult?
    /// 连接测试进行中标识。
    let isTesting: Bool
    /// 「已保存」瞬时提示标识。
    let isSaved: Bool
    /// 点击「连接测试」回调（需求 15.4）。
    let onTest: () -> Void
    /// 点击「保存」回调。
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.5) {
            header
            field(label: "接口地址", systemImage: "link") {
                TextField("https://api.openai.com/v1", text: $config.baseURL)
                    .textFieldStyle(.roundedBorder)
            }
            field(label: "密钥", systemImage: "key.fill") {
                SecureField("请输入访问密钥", text: $config.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            field(label: "模型名", systemImage: "cube") {
                modelInput
            }
            actionRow
            resultRow
        }
        .padding(tokens.spacingUnit * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }

    /// 卡片标题行：图标 + 服务名称。
    private var header: some View {
        HStack(spacing: tokens.spacingUnit) {
            Image(systemName: iconName)
                .foregroundColor(tokens.accentPrimary)
            Text(title)
                .font(.headline)
                .foregroundColor(tokens.textPrimary)
        }
    }

    /// 通用的「标签 + 输入控件」一行布局。
    private func field<Content: View>(label: String,
                                      systemImage: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.5) {
            HStack(spacing: tokens.spacingUnit * 0.5) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(tokens.textSecondary)
            }
            content()
        }
    }

    /// 模型名输入：常用模型快捷选择（`Menu`）+ 自定义输入（`TextField`）（需求 15.3）。
    /// 快捷项选中后写入草稿；自定义输入按用户输入原样保存与使用（需求 1.2）。
    private var modelInput: some View {
        HStack(spacing: tokens.spacingUnit) {
            TextField("自定义模型名", text: $config.model)
                .textFieldStyle(.roundedBorder)

            Menu {
                ForEach(commonModels, id: \.self) { model in
                    Button(model) { config.model = model }
                }
            } label: {
                HStack(spacing: tokens.spacingUnit * 0.5) {
                    Text("常用模型")
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(tokens.accentPrimary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    /// 操作行：连接测试 + 保存（需求 15.4）。
    private var actionRow: some View {
        HStack(spacing: tokens.spacingUnit) {
            Button(action: onTest) {
                HStack(spacing: tokens.spacingUnit * 0.5) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isTesting ? "测试中…" : "连接测试")
                }
                .foregroundColor(tokens.accentPrimary)
                .padding(.vertical, tokens.spacingUnit)
                .padding(.horizontal, tokens.spacingUnit * 1.5)
                .background(
                    RoundedRectangle(cornerRadius: tokens.cornerRadius)
                        .stroke(tokens.accentPrimary, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isTesting)

            Button(action: onSave) {
                Text("保存")
                    .fontWeight(.semibold)
                    .foregroundColor(tokens.background)
                    .padding(.vertical, tokens.spacingUnit)
                    .padding(.horizontal, tokens.spacingUnit * 2)
                    .background(
                        RoundedRectangle(cornerRadius: tokens.cornerRadius)
                            .fill(tokens.accentPrimary)
                    )
            }
            .buttonStyle(.plain)

            if isSaved {
                Label("已保存", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(tokens.accentPrimary)
            }

            Spacer()
        }
    }

    /// 连接测试结果行：成功 / 失败用不同图标与颜色，文案为中文（需求 15.4、1.1）。
    @ViewBuilder
    private var resultRow: some View {
        if let result {
            HStack(alignment: .top, spacing: tokens.spacingUnit * 0.5) {
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .foregroundColor(result.isSuccess ? tokens.accentPrimary : tokens.recording)
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(result.isSuccess ? tokens.textPrimary : tokens.recording)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG
/// 预览用桩客户端：连接测试返回固定中文结果，不发起真实网络请求。
private final class PreviewConfigClient: OpenAICompatibleClienting {
    func postJSON(path: String, body: Data, config: ServiceConfig) async throws -> Data { Data() }
    func postMultipart(path: String, parts: [MultipartPart], config: ServiceConfig) async throws -> Data { Data() }
    func testConnection(_ config: ServiceConfig) async -> ConnectionResult {
        .success(message: "连接成功，模型「\(config.model)」可用。")
    }
}

/// 预览：覆盖「空配置（浅色）」与「已填写配置（深色）」两种典型组合。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
struct ServiceConfigView_Previews: PreviewProvider {
    @MainActor
    private static func makeStore(filled: Bool) -> SettingsStore {
        let defaults = UserDefaults(suiteName: "preview.serviceConfig.\(filled)") ?? .standard
        defaults.removePersistentDomain(forName: "preview.serviceConfig.\(filled)")
        let store = SettingsStore(defaults: defaults, keychain: InMemoryKeychain())
        if filled {
            store.updateTranscription(ServiceConfig(baseURL: "https://api.openai.com/v1",
                                                    apiKey: "sk-demo",
                                                    model: "whisper-1"))
            store.updateSummary(ServiceConfig(baseURL: "https://api.deepseek.com/v1",
                                              apiKey: "sk-demo",
                                              model: "deepseek-chat"))
        }
        return store
    }

    static var previews: some View {
        Group {
            ServiceConfigView(settings: makeStore(filled: false), client: PreviewConfigClient())
                .frame(width: 480, height: 640)
                .themeTokens(.light)
                .previewDisplayName("空配置-浅色")

            ServiceConfigView(settings: makeStore(filled: true), client: PreviewConfigClient())
                .frame(width: 480, height: 640)
                .themeTokens(.dark)
                .previewDisplayName("已填写-深色")
        }
    }
}

/// 预览专用的内存版 Keychain，避免预览写入真实钥匙串。
private final class InMemoryKeychain: KeychainStoring {
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
#endif
