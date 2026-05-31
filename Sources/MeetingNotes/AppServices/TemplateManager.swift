import Foundation
import Combine

/// 纪要模板管理（应用服务层，对应设计「TemplateManager」、需求 16）。
///
/// 职责：
/// - 提供默认 / 站会 / 评审 / 面试四个内置通用模板（需求 16.1）。
/// - 自定义模板的新建、编辑、删除、复制（需求 16.3、16.4）。
/// - 纯文本 / 图文模式的读取与切换（需求 16.6）。
///
/// 存储策略：
/// - 内置模板由代码定义（`builtinTemplates`），不落库、不可删除。
/// - 自定义模板以 JSON 持久化到 `UserDefaults`，加载时与内置模板合并。
/// - 图文模式不在本类自持，而是委托 `SettingsStore`（`AppSettings.imageMode`）读写，
///   避免出现两份「真相来源」。
///
/// 作为 `ObservableObject`，`customTemplates` 变化会驱动后续模板管理界面刷新。
@MainActor
final class TemplateManager: ObservableObject {
    /// 用户自定义模板（内置模板不在此列表，见 `builtinTemplates`）。
    @Published private(set) var customTemplates: [NoteTemplate]

    /// 内置通用模板：默认 / 站会 / 评审 / 面试（需求 16.1），代码定义且不可删除。
    let builtinTemplates: [NoteTemplate]

    private let defaults: UserDefaults
    private let storageKey: String
    private let settingsStore: SettingsStore

    /// - Parameters:
    ///   - settingsStore: 图文模式的真相来源，图文/纯文本读写委托给它（需求 16.6）。
    ///   - defaults: 自定义模板的轻量存储，默认 `.standard`（便于测试注入隔离实例）。
    ///   - storageKey: `UserDefaults` 中存放自定义模板 JSON 的键名。
    init(settingsStore: SettingsStore,
         defaults: UserDefaults = .standard,
         storageKey: String = "com.meetingnotes.customTemplates") {
        self.settingsStore = settingsStore
        self.defaults = defaults
        self.storageKey = storageKey
        self.builtinTemplates = Self.makeBuiltinTemplates()
        self.customTemplates = Self.loadCustomTemplates(defaults: defaults, storageKey: storageKey)
    }
}

// MARK: - 内置模板定义（需求 16.1）

extension TemplateManager {
    /// 内置模板的固定标识，供查找与默认选择使用（自定义模板用 UUID，不会与之冲突）。
    enum BuiltinID {
        static let `default` = "builtin.default"
        static let standup = "builtin.standup"
        static let review = "builtin.review"
        static let interview = "builtin.interview"
    }

    /// 构造四个内置通用模板。`instruction` 描述各自的分区结构，交由总结服务按结构生成（需求 16.2）。
    static func makeBuiltinTemplates() -> [NoteTemplate] {
        [
            // 默认模板：与需求 12.3 的纪要库分区对齐（会议摘要 / 关键决策 / 待办事项 / 讨论要点）。
            NoteTemplate(
                id: BuiltinID.default,
                name: "默认",
                isBuiltin: true,
                instruction: """
                请将会议内容整理为以下四个分区，标题保持一致：
                1. 会议摘要：用三到五句话概括会议主题、背景与整体结论。
                2. 关键决策：逐条列出会上达成的决定，说明结论与理由。
                3. 待办事项：逐条列出需要跟进的行动，尽量标注责任人与截止时间。
                4. 讨论要点：归纳主要讨论话题、不同观点与未决问题。
                """
            ),
            // 站会模板：聚焦昨日进展 / 今日计划 / 阻塞 / 待办。
            NoteTemplate(
                id: BuiltinID.standup,
                name: "站会",
                isBuiltin: true,
                instruction: """
                请按每日站会的结构整理内容，标题保持一致：
                1. 昨日进展：按成员或事项归纳已完成的工作。
                2. 今日计划：按成员或事项列出当天要推进的工作。
                3. 阻塞与风险：列出当前遇到的阻碍及需要协调的事项。
                4. 待办事项：逐条列出需要跟进的行动，尽量标注责任人与截止时间。
                """
            ),
            // 评审模板：聚焦评审对象 / 问题与建议 / 结论 / 待办。
            NoteTemplate(
                id: BuiltinID.review,
                name: "评审",
                isBuiltin: true,
                instruction: """
                请按评审会议的结构整理内容，标题保持一致：
                1. 评审概述：说明本次评审的对象、范围与目标。
                2. 问题与建议：逐条列出发现的问题、对应的改进建议及优先级。
                3. 评审结论：给出通过 / 有条件通过 / 不通过的结论及依据。
                4. 待办事项：逐条列出需要修改或跟进的行动，尽量标注责任人与截止时间。
                """
            ),
            // 面试模板：聚焦候选人信息 / 考察维度 / 亮点与顾虑 / 结论。
            NoteTemplate(
                id: BuiltinID.interview,
                name: "面试",
                isBuiltin: true,
                instruction: """
                请按面试记录的结构整理内容，标题保持一致：
                1. 候选人概况：归纳候选人背景、应聘岗位与整体印象。
                2. 考察维度：按技术能力、项目经历、沟通协作等维度归纳表现。
                3. 亮点与顾虑：分别列出明显的优势与需要关注的疑点。
                4. 面试结论：给出推荐 / 待定 / 不推荐的结论及理由。
                """
            )
        ]
    }
}

// MARK: - 模板查询

extension TemplateManager {
    /// 内置模板与自定义模板合并后的完整列表，内置在前（供模板选择列表展示）。
    var allTemplates: [NoteTemplate] {
        builtinTemplates + customTemplates
    }

    /// 默认模板（需求 16.1），用于未显式选择时的兜底。
    var defaultTemplate: NoteTemplate {
        // 内置模板由代码定义，默认模板必定存在；兜底取首个内置模板。
        builtinTemplates.first { $0.id == BuiltinID.default } ?? builtinTemplates[0]
    }

    /// 按 id 查找模板（内置或自定义均可）。
    func template(withID id: String) -> NoteTemplate? {
        allTemplates.first { $0.id == id }
    }
}

// MARK: - 自定义模板的增删改复制（需求 16.3、16.4）

extension TemplateManager {
    /// 新建自定义模板（需求 16.3）：以纪要指令文本为核心，生成唯一 id。
    /// - Returns: 新建的模板，便于界面立即选中。
    @discardableResult
    func createCustomTemplate(name: String, instruction: String) -> NoteTemplate {
        let template = NoteTemplate(
            id: UUID().uuidString,
            name: name,
            isBuiltin: false,
            instruction: instruction
        )
        customTemplates.append(template)
        persist()
        return template
    }

    /// 编辑自定义模板的名称与纪要指令（需求 16.4）。
    ///
    /// 内置模板不可编辑：传入内置 id 时不做任何修改。
    /// - Returns: 是否成功更新。
    @discardableResult
    func updateCustomTemplate(id: String, name: String, instruction: String) -> Bool {
        guard let index = customTemplates.firstIndex(where: { $0.id == id }) else {
            return false
        }
        customTemplates[index].name = name
        customTemplates[index].instruction = instruction
        persist()
        return true
    }

    /// 删除自定义模板（需求 16.4）。
    ///
    /// 内置模板不可删除：传入内置 id 时不做任何修改。
    /// - Returns: 是否成功删除。
    @discardableResult
    func deleteCustomTemplate(id: String) -> Bool {
        guard let index = customTemplates.firstIndex(where: { $0.id == id }) else {
            return false
        }
        customTemplates.remove(at: index)
        persist()
        return true
    }

    /// 复制模板为一份新的可编辑自定义模板（需求 16.4）。
    ///
    /// 内置模板不可删除，但可通过复制得到可编辑的自定义副本。源模板（内置或自定义）均可复制。
    /// - Returns: 复制出的新模板；源 id 不存在时返回 nil。
    @discardableResult
    func duplicateTemplate(id: String) -> NoteTemplate? {
        guard let source = template(withID: id) else { return nil }
        let copy = NoteTemplate(
            id: UUID().uuidString,
            name: "\(source.name) 副本",
            isBuiltin: false,
            instruction: source.instruction
        )
        customTemplates.append(copy)
        persist()
        return copy
    }
}

// MARK: - 纯文本 / 图文模式（需求 16.6）

extension TemplateManager {
    /// 当前是否为图文模式（true 图文，false 纯文本）。委托 `SettingsStore` 这一真相来源。
    var imageMode: Bool {
        settingsStore.settings.imageMode
    }

    /// 设置纯文本 / 图文模式（需求 16.6）。委托 `SettingsStore` 持久化，避免双份真相来源。
    func setImageMode(_ enabled: Bool) {
        settingsStore.updateImageMode(enabled)
    }
}

// MARK: - 自定义模板的加载与持久化

extension TemplateManager {
    /// 从 `UserDefaults` 读取自定义模板列表；无记录或解码失败时返回空列表。
    static func loadCustomTemplates(defaults: UserDefaults, storageKey: String) -> [NoteTemplate] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NoteTemplate].self, from: data) else {
            return []
        }
        // 防御：即使存储被外部污染，也只保留自定义模板（内置由代码定义）。
        return decoded.filter { !$0.isBuiltin }
    }

    /// 持久化当前自定义模板列表到 `UserDefaults`（内置模板不落库）。
    private func persist() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
