import Foundation

#if canImport(UserNotifications)
import UserNotifications
#endif

/// 处理完成通知能力（基础设施层，对应设计「UserNotifications」、需求 8.6、8.7）。
///
/// 当用户在处理态选择「在后台继续，完成后通知我」且处理流程全部完成时，
/// 由 `ProcessingPipeline` 调用本协议发出一条本地完成通知（需求 8.7）。
/// 抽象为协议便于在测试与无 UserNotifications 的环境中替换实现。
protocol CompletionNotifying {
    /// 请求通知授权。返回是否已获授权。
    ///
    /// 用户选择「后台继续」时调用，确保完成后能成功投递通知。
    @discardableResult
    func requestAuthorization() async -> Bool

    /// 发出「纪要已生成完成」通知，正文包含会议标题（需求 8.7）。
    /// - Parameter meetingTitle: 已生成纪要的会议标题。
    func notifyCompletion(meetingTitle: String) async
}

#if canImport(UserNotifications)

/// 基于 `UNUserNotificationCenter` 的完成通知实现（需求 8.7）。
///
/// 文案全部为中文（需求 1.1）。在不支持 UserNotifications 的平台下，
/// 由编译条件排除本实现，调用方应回退到无操作实现。
final class UserNotificationCompletionNotifier: CompletionNotifying {

    private let center: UNUserNotificationCenter

    /// - Parameter center: 通知中心，默认取当前应用的 `current()`（便于测试注入）。
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func notifyCompletion(meetingTitle: String) async {
        let content = UNMutableNotificationContent()
        content.title = "纪要已生成完成"
        let trimmed = meetingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = trimmed.isEmpty
            ? "会议纪要已生成完成。"
            : "「\(trimmed)」的会议纪要已生成完成。"
        content.sound = .default

        // 立即投递（trigger 为 nil 表示尽快展示）。
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}

#endif

/// 无操作的完成通知实现，用于不支持 UserNotifications 的平台或测试场景。
///
/// `ProcessingPipeline` 在 UserNotifications 不可用时以此作为默认，
/// 保证「后台继续」流程不因缺少通知能力而崩溃（需求 8.7 的降级路径）。
final class NoopCompletionNotifier: CompletionNotifying {
    init() {}

    @discardableResult
    func requestAuthorization() async -> Bool { false }

    func notifyCompletion(meetingTitle: String) async {}
}

/// 构造当前平台默认的完成通知实现：支持 UserNotifications 时用系统实现，否则无操作。
enum CompletionNotifierFactory {
    static func makeDefault() -> CompletionNotifying {
        #if canImport(UserNotifications)
        return UserNotificationCompletionNotifier()
        #else
        return NoopCompletionNotifier()
        #endif
    }
}
