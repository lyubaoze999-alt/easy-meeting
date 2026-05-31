import SwiftUI

/// 模板管理界面（界面层，任务 16.2，需求 16.1、16.3、16.4、16.6）。
///
/// 自上而下展示：
/// - 纯文本 / 图文模式选择（需求 16.6），经 `TemplateManager.setImageMode` 持久化；
/// - 内置模板列表（默认 / 站会 / 评审 / 面试，需求 16.1），每行带「内置」标记，仅可复制；
/// - 自定义模板列表（需求 16.3、16.4），支持编辑、删除、复制，并提供「新建」入口。
///
/// 新建 / 编辑通过 `.sheet` 弹出表单：名称输入 + 纪要指令 `TextEditor`（需求 16.3）。
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4），自有文案均为中文（需求 1.1）。
struct TemplateManagementView: View {
    @Environment(\.themeTokens) private var tokens
    @ObservedObject var templateManager: TemplateManager

    /// 当前展示的编辑表单上下文；非 nil 时弹出 `.sheet`（新建或编辑）。
    @State private var editorContext: TemplateEditorContext?

    /// 图文模式本地镜像：保证 `Picker` 交互即时刷新，并经 `onChange` 写回管理器（需求 16.6）。
    @State private var imageMode: Bool

    /// - Parameter templateManager: 模板管理服务（提供内置 / 自定义模板与图文模式读写）。
    init(templateManager: TemplateManager) {
        self.templateManager = templateManager
        _imageMode = State(initialValue: templateManager.imageMode)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.spacingUnit * 3) {
                imageModeSection
                builtinSection
                customSection
            }
            .padding(tokens.spacingUnit * 3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(tokens.background)
        .onChange(of: imageMode) { _, newValue in
            templateManager.setImageMode(newValue)
        }
        .sheet(item: $editorContext) { context in
            TemplateEditorSheet(context: context) { result in
                apply(result)
            }
            .themeTokens(tokens)
        }
    }
}

// MARK: - 纯文本 / 图文模式选择（需求 16.6）

private extension TemplateManagementView {
    /// 纯文本 / 图文模式选择区：`Picker` 绑定本地镜像，变更经 `onChange` 写回管理器。
    var imageModeSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            sectionTitle("纪要展示模式")
            Text("图文模式会在文字内容基础上额外生成时间线、思维导图、关键数字卡片等可视化内容。")
                .font(.caption)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("纪要展示模式", selection: $imageMode) {
                Text("纯文本").tag(false)
                Text("图文").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(tokens.spacingUnit * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }
}

// MARK: - 内置模板列表（需求 16.1）

private extension TemplateManagementView {
    /// 内置模板区：默认 / 站会 / 评审 / 面试，每行带「内置」标记，仅提供复制操作。
    var builtinSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.5) {
            sectionTitle("内置模板")
            ForEach(templateManager.builtinTemplates) { template in
                TemplateRow(
                    template: template,
                    onEdit: nil,
                    onDelete: nil,
                    onDuplicate: { duplicate(template) }
                )
            }
        }
    }
}

// MARK: - 自定义模板列表（需求 16.3、16.4）

private extension TemplateManagementView {
    /// 自定义模板区：列表 + 新建入口，每行支持编辑 / 删除 / 复制。
    var customSection: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 1.5) {
            HStack {
                sectionTitle("自定义模板")
                Spacer()
                Button(action: startCreate) {
                    Label("新建", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundColor(tokens.accentPrimary)
                }
                .buttonStyle(.plain)
            }

            if templateManager.customTemplates.isEmpty {
                Text("暂无自定义模板，点击「新建」创建，或复制内置模板得到可编辑副本。")
                    .font(.callout)
                    .foregroundColor(tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(tokens.spacingUnit * 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: tokens.cornerRadius)
                            .fill(tokens.surface)
                    )
            } else {
                ForEach(templateManager.customTemplates) { template in
                    TemplateRow(
                        template: template,
                        onEdit: { startEdit(template) },
                        onDelete: { templateManager.deleteCustomTemplate(id: template.id) },
                        onDuplicate: { duplicate(template) }
                    )
                }
            }
        }
    }
}

// MARK: - 操作与表单交互

private extension TemplateManagementView {
    /// 区块标题样式。
    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundColor(tokens.textPrimary)
    }

    /// 打开「新建」表单（需求 16.3）。
    func startCreate() {
        editorContext = TemplateEditorContext(mode: .create, name: "", instruction: "")
    }

    /// 打开「编辑」表单（需求 16.4，仅自定义模板）。
    func startEdit(_ template: NoteTemplate) {
        editorContext = TemplateEditorContext(
            mode: .edit(id: template.id),
            name: template.name,
            instruction: template.instruction
        )
    }

    /// 复制模板为可编辑的自定义副本（需求 16.4，内置 / 自定义均可）。
    func duplicate(_ template: NoteTemplate) {
        templateManager.duplicateTemplate(id: template.id)
    }

    /// 处理表单保存结果：新建或编辑后写回管理器。
    func apply(_ result: TemplateEditorResult) {
        switch result.mode {
        case .create:
            templateManager.createCustomTemplate(name: result.name, instruction: result.instruction)
        case .edit(let id):
            templateManager.updateCustomTemplate(id: id, name: result.name, instruction: result.instruction)
        }
    }
}

/// 单个模板行（内置或自定义共用）。
///
/// 展示名称、内置标记（需求 16.1）与纪要指令摘要；右侧按可用操作展示编辑 / 删除 / 复制按钮：
/// 内置模板隐藏编辑 / 删除（仅允许复制），自定义模板三者齐全（需求 16.4）。
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4）。
private struct TemplateRow: View {
    @Environment(\.themeTokens) private var tokens

    let template: NoteTemplate
    /// 编辑回调；nil 表示不提供编辑（内置模板）。
    let onEdit: (() -> Void)?
    /// 删除回调；nil 表示不提供删除（内置模板）。
    let onDelete: (() -> Void)?
    /// 复制回调（内置 / 自定义均可）。
    let onDuplicate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            HStack(spacing: tokens.spacingUnit) {
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(tokens.textPrimary)

                if template.isBuiltin {
                    Text("内置")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(tokens.accentPrimary)
                        .padding(.vertical, tokens.spacingUnit * 0.25)
                        .padding(.horizontal, tokens.spacingUnit * 0.75)
                        .background(
                            Capsule().fill(tokens.accentSecondary.opacity(0.35))
                        )
                }

                Spacer()
                actions
            }

            Text(template.instruction)
                .font(.caption)
                .foregroundColor(tokens.textSecondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(tokens.spacingUnit * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }

    /// 行内操作区：复制始终可用；编辑 / 删除仅对自定义模板出现。
    private var actions: some View {
        HStack(spacing: tokens.spacingUnit * 1.5) {
            if let onEdit {
                iconButton("square.and.pencil", label: "编辑", tint: tokens.accentPrimary, action: onEdit)
            }
            iconButton("doc.on.doc", label: "复制", tint: tokens.accentPrimary, action: onDuplicate)
            if let onDelete {
                iconButton("trash", label: "删除", tint: tokens.recording, action: onDelete)
            }
        }
    }

    /// 统一的图标按钮：以无障碍标签暴露中文操作名。
    private func iconButton(_ systemName: String,
                            label: String,
                            tint: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(tint)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - 编辑表单上下文与结果

/// 模板编辑表单的工作模式：新建或编辑某个已有模板。
private enum TemplateEditorMode: Equatable {
    case create
    case edit(id: String)
}

/// 模板编辑表单的输入上下文（驱动 `.sheet`，需 `Identifiable`）。
private struct TemplateEditorContext: Identifiable {
    let id = UUID()
    let mode: TemplateEditorMode
    let name: String
    let instruction: String
}

/// 模板编辑表单的保存结果，上抛给父视图写回管理器。
private struct TemplateEditorResult {
    let mode: TemplateEditorMode
    let name: String
    let instruction: String
}

/// 模板新建 / 编辑表单（`.sheet` 内容，需求 16.3、16.4）。
///
/// 提供名称 `TextField` 与纪要指令 `TextEditor`（需求 16.3）；名称为空时禁用「保存」。
/// 取色全部来自 `@Environment(\.themeTokens)`（需求 17.4），文案均为中文（需求 1.1）。
private struct TemplateEditorSheet: View {
    @Environment(\.themeTokens) private var tokens
    @Environment(\.dismiss) private var dismiss

    let context: TemplateEditorContext
    let onSave: (TemplateEditorResult) -> Void

    @State private var name: String
    @State private var instruction: String

    init(context: TemplateEditorContext, onSave: @escaping (TemplateEditorResult) -> Void) {
        self.context = context
        self.onSave = onSave
        _name = State(initialValue: context.name)
        _instruction = State(initialValue: context.instruction)
    }

    /// 名称去除首尾空白后是否非空（决定能否保存）。
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 表单标题随工作模式切换。
    private var title: String {
        switch context.mode {
        case .create: return "新建模板"
        case .edit: return "编辑模板"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
            Text(title)
                .font(.headline)
                .foregroundColor(tokens.textPrimary)

            VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.5) {
                Text("模板名称")
                    .font(.subheadline)
                    .foregroundColor(tokens.textSecondary)
                TextField("请输入模板名称", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.5) {
                Text("纪要指令")
                    .font(.subheadline)
                    .foregroundColor(tokens.textSecondary)
                Text("描述希望的纪要分区结构与生成要求，交给总结服务按此组织内容。")
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextEditor(text: $instruction)
                    .font(.body)
                    .frame(minHeight: 160)
                    .padding(tokens.spacingUnit * 0.5)
                    .background(
                        RoundedRectangle(cornerRadius: tokens.cornerRadius)
                            .stroke(tokens.textSecondary.opacity(0.3), lineWidth: 1)
                    )
            }

            HStack(spacing: tokens.spacingUnit) {
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(tokens.textSecondary)
                    .padding(.vertical, tokens.spacingUnit)
                    .padding(.horizontal, tokens.spacingUnit * 2)

                Button("保存") {
                    onSave(TemplateEditorResult(mode: context.mode, name: name, instruction: instruction))
                    dismiss()
                }
                .buttonStyle(.plain)
                .fontWeight(.semibold)
                .foregroundColor(tokens.background)
                .padding(.vertical, tokens.spacingUnit)
                .padding(.horizontal, tokens.spacingUnit * 2.5)
                .background(
                    RoundedRectangle(cornerRadius: tokens.cornerRadius)
                        .fill(canSave ? tokens.accentPrimary : tokens.textSecondary.opacity(0.4))
                )
                .disabled(!canSave)
            }
        }
        .padding(tokens.spacingUnit * 3)
        .frame(width: 420)
        .background(tokens.background)
    }
}

#if DEBUG
/// 预览：覆盖「仅内置（浅色）」与「含自定义模板（深色）」两种典型组合。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools 的构建环境。
struct TemplateManagementView_Previews: PreviewProvider {
    @MainActor
    private static func makeManager(withCustom: Bool) -> TemplateManager {
        let suite = "preview.templates.\(withCustom)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults, keychain: TemplatePreviewKeychain())
        let manager = TemplateManager(settingsStore: store, defaults: defaults, storageKey: "\(suite).custom")
        if withCustom {
            manager.createCustomTemplate(name: "客户访谈",
                                         instruction: "请按背景、核心诉求、跟进事项三个分区整理客户访谈内容。")
            manager.createCustomTemplate(name: "项目复盘",
                                         instruction: "请按目标达成、亮点、不足、改进项四个分区整理复盘内容。")
            store.updateImageMode(true)
        }
        return manager
    }

    static var previews: some View {
        Group {
            TemplateManagementView(templateManager: makeManager(withCustom: false))
                .frame(width: 520, height: 640)
                .themeTokens(.light)
                .previewDisplayName("仅内置-浅色")

            TemplateManagementView(templateManager: makeManager(withCustom: true))
                .frame(width: 520, height: 640)
                .themeTokens(.dark)
                .previewDisplayName("含自定义-深色")
        }
    }
}

/// 预览专用的内存版 Keychain，避免预览写入真实钥匙串。
private final class TemplatePreviewKeychain: KeychainStoring {
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
