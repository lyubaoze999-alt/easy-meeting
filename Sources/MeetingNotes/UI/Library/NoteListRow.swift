import SwiftUI

/// 纪要库左侧列表的单行（界面层，任务 15.1，需求 11.3、11.5）。
///
/// 每行展示标题、时间与时长（需求 11.3）；选中态以辅色背景 + 主色左侧条高亮
/// （需求 11.5）。点击触发 `onTap`，由上层把该条设为选中。取色来自
/// `@Environment(\.themeTokens)`（需求 17.4），文案为中文（需求 1.1）。
struct NoteListRow: View {
    @Environment(\.themeTokens) private var tokens

    let note: MeetingNote
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // 选中态左侧主色指示条（需求 11.5）。
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? tokens.accentPrimary : Color.clear)
                    .frame(width: 3)
                    .padding(.vertical, tokens.spacingUnit * 0.5)

                VStack(alignment: .leading, spacing: tokens.spacingUnit * 0.4) {
                    Text(displayTitle)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(tokens.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: tokens.spacingUnit * 0.5) {
                        Text(NoteListRow.timeText(note.startedAt))
                        Text("·")
                        Text(NoteListRow.durationText(note.duration))
                    }
                    .font(.caption)
                    .foregroundColor(tokens.textSecondary)
                }
                .padding(.leading, tokens.spacingUnit)
                .padding(.vertical, tokens.spacingUnit * 0.75)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: tokens.cornerRadius)
                    .fill(isSelected ? tokens.accentSecondary.opacity(0.35) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 标题展示文案，空白时退回占位（需求 1.1）。
    private var displayTitle: String {
        let trimmed = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名会议" : trimmed
    }

    /// 行内时间展示（需求 11.3）：今天显示时刻，否则显示月日 + 时刻。
    static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "M月d日 HH:mm"
        }
        return formatter.string(from: date)
    }

    /// 行内时长展示（需求 11.3）：如 1小时5分 / 12分 / 45秒。
    static func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)小时\(minutes)分" : "\(hours)小时"
        }
        if minutes > 0 {
            return "\(minutes)分"
        }
        return "\(seconds)秒"
    }
}
