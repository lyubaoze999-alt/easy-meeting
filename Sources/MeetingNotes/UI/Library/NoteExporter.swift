import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// 纪要复制与导出工具（界面层，任务 15.4，需求 13.1、13.2）。
///
/// 提供两类纯文本表示与对应的系统交互：
/// - `plainText(of:)`：纪要的纯文本全文表示，用于「复制全文」写入剪贴板（需求 13.1）。
/// - `markdown(of:)`：纪要的 Markdown 表示，用于「导出 Markdown」落盘（需求 13.2）。
/// - `copyToPasteboard(_:)`：把任意文本写入系统剪贴板（仅 macOS 生效）。
/// - `exportMarkdown(_:)`：弹出保存面板，将 Markdown 写入用户所选文件（仅 macOS 生效）。
///
/// 文本拼装为纯逻辑、与平台无关，便于在任意环境构建与测试；
/// 与 AppKit 相关的剪贴板写入、保存面板用 `#if canImport(AppKit)` 守卫，
/// 在不含 AppKit 的平台降级为无操作以保证可编译。文案均为中文（需求 1.1），
/// 用户输入的标题等按原样保留（需求 1.2）。密钥等敏感信息不参与拼装，不写入导出文件（需求 15.1、15.2）。
enum NoteExporter {

    // MARK: - 纯文本全文（需求 13.1）

    /// 构建纪要的纯文本全文表示：标题、元信息、各分区、待办，逐行拼接。
    ///
    /// 与完成态预览的复制口径保持一致：分区以「【标题】」起头，待办以 `[ ]` / `[x]`
    /// 勾选框前缀，并把责任人 / 截止时间括注在行尾。
    static func plainText(of note: MeetingNote) -> String {
        var lines: [String] = []
        lines.append(displayTitle(of: note))
        lines.append(metaLine(of: note))

        for section in note.sections {
            let heading = section.heading.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !heading.isEmpty || !content.isEmpty else { continue }
            lines.append("")
            if !heading.isEmpty {
                lines.append(section.isHighlighted ? "【\(heading)】（重点）" : "【\(heading)】")
            }
            if !content.isEmpty { lines.append(content) }
        }

        if !note.todos.isEmpty {
            lines.append("")
            lines.append("【待办事项】")
            for todo in note.todos {
                var line = todo.done ? "[x] " : "[ ] "
                line += todo.text
                if let meta = todoMeta(todo) { line += "（\(meta)）" }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Markdown（需求 13.2）

    /// 构建纪要的 Markdown 表示：一级标题为会议标题，元信息为引用行，
    /// 各分区为二级标题 + 正文，待办为 `- [ ]` / `- [x]` 复选框列表（含责任人 / 截止时间）。
    static func markdown(of note: MeetingNote) -> String {
        var lines: [String] = []
        lines.append("# \(displayTitle(of: note))")
        lines.append("")
        lines.append("> \(metaLine(of: note))")

        for section in note.sections {
            let heading = section.heading.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !heading.isEmpty || !content.isEmpty else { continue }
            lines.append("")
            if !heading.isEmpty {
                lines.append(section.isHighlighted ? "## \(heading)（重点）" : "## \(heading)")
            }
            if !content.isEmpty {
                lines.append("")
                lines.append(content)
            }
        }

        if !note.todos.isEmpty {
            lines.append("")
            lines.append("## 待办事项")
            lines.append("")
            for todo in note.todos {
                var line = todo.done ? "- [x] " : "- [ ] "
                line += todo.text
                if let meta = todoMeta(todo) { line += "（\(meta)）" }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - 系统交互（剪贴板 / 保存面板）

    /// 把文本写入系统剪贴板（需求 13.1）。仅 macOS 生效，其余平台为无操作。
    static func copyToPasteboard(_ text: String) {
        #if canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #endif
    }

    /// 弹出保存面板并把纪要的 Markdown 写入用户所选文件（需求 13.2）。
    ///
    /// 默认文件名取自会议标题（清理掉文件名非法字符），扩展名为 `.md`。
    /// 用户取消保存面板时直接返回，不做任何写入。仅 macOS 生效，其余平台为无操作。
    static func exportMarkdown(_ note: MeetingNote) {
        #if canImport(AppKit)
        let panel = NSSavePanel()
        panel.title = "导出 Markdown"
        panel.prompt = "导出"
        panel.nameFieldStringValue = suggestedFileName(for: note)
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        panel.isExtensionHidden = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = markdown(of: note)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        #endif
    }

    // MARK: - 文件名与文本片段（纯逻辑，可复用 / 可测试）

    /// 建议的导出文件名（含 `.md` 扩展名），基于会议标题清理非法字符后生成。
    static func suggestedFileName(for note: MeetingNote) -> String {
        let base = sanitizedFileBase(displayTitle(of: note))
        return "\(base).md"
    }

    /// 把标题清理为安全的文件名主体：去除路径分隔符等非法字符，折叠空白，限制长度。
    static func sanitizedFileBase(_ title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = title
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "未命名会议" : trimmed
        return String(base.prefix(80))
    }

    /// 标题展示文案，标题为空白时退回占位（与库内其他视图口径一致）。
    static func displayTitle(of note: MeetingNote) -> String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名会议" : trimmed
    }

    /// 元信息行：日期 + 时间段 + 时长，复用纪要详情视图的格式化口径。
    static func metaLine(of note: MeetingNote) -> String {
        NoteDetailView.metaText(startedAt: note.startedAt, duration: note.duration)
    }

    /// 待办的责任人 / 截止时间附注，二者皆缺则为 nil。
    static func todoMeta(_ todo: TodoItem) -> String? {
        var parts: [String] = []
        if let owner = todo.owner?.trimmingCharacters(in: .whitespacesAndNewlines), !owner.isEmpty {
            parts.append("负责人：\(owner)")
        }
        if let due = todo.dueDate?.trimmingCharacters(in: .whitespacesAndNewlines), !due.isEmpty {
            parts.append("截止：\(due)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}
