import SwiftUI

/// 首次启动权限引导界面（需求 3.1、3.2、3.3）。
///
/// 引导用户授予屏幕录制（采集系统声音）与麦克风（采集本人声音）两项权限：
/// 每项权限展示当前状态、中文用途说明，并提供「授权」与「前往系统设置」两个入口。
/// 两项权限都授予后可点击「进入应用」完成引导。
///
/// 颜色全部取自 `@Environment(\.themeTokens)`，不写死色值（需求 17.4）；
/// 文案全为中文（需求 1.1）。
struct PermissionOnboardingView: View {
    @Environment(\.themeTokens) private var tokens
    @StateObject private var viewModel: PermissionOnboardingViewModel

    /// 用户完成引导（两项权限已处理并选择继续）时的回调，由上层用于切换到主界面。
    private let onContinue: () -> Void

    /// - Parameters:
    ///   - viewModel: 权限引导视图模型，默认新建一个包裹 `PermissionManager()` 的实例。
    ///   - onContinue: 点击「进入应用」时触发的回调。
    init(viewModel: PermissionOnboardingViewModel = PermissionOnboardingViewModel(),
         onContinue: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit * 2) {
            header

            PermissionRow(
                title: "屏幕录制",
                purpose: PrivacyPane.screenRecording.purposeDescription,
                status: viewModel.screenRecordingStatus,
                onAuthorize: { viewModel.requestScreenRecording() },
                onOpenSettings: { viewModel.openSystemSettings(for: .screenRecording) }
            )

            PermissionRow(
                title: "麦克风",
                purpose: PrivacyPane.microphone.purposeDescription,
                status: viewModel.microphoneStatus,
                onAuthorize: { Task { await viewModel.requestMicrophone() } },
                onOpenSettings: { viewModel.openSystemSettings(for: .microphone) }
            )

            footer
        }
        .padding(tokens.spacingUnit * 3)
        .frame(width: 420)
        .background(tokens.background)
        .onAppear { viewModel.refresh() }
    }

    /// 顶部标题与说明。
    private var header: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            Text("欢迎使用会议纪要")
                .font(.title2.bold())
                .foregroundColor(tokens.textPrimary)
            Text("开始录音前，请先授予以下权限，应用才能完整采集会议声音。")
                .font(.callout)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 底部刷新与继续操作。
    private var footer: some View {
        HStack(spacing: tokens.spacingUnit * 2) {
            Button("刷新状态") { viewModel.refresh() }
                .buttonStyle(.plain)
                .foregroundColor(tokens.accentPrimary)

            Spacer()

            Button(action: onContinue) {
                Text(viewModel.isAllAuthorized ? "进入应用" : "稍后设置")
                    .fontWeight(.semibold)
                    .foregroundColor(tokens.background)
                    .padding(.horizontal, tokens.spacingUnit * 2)
                    .padding(.vertical, tokens.spacingUnit)
                    .background(
                        RoundedRectangle(cornerRadius: tokens.cornerRadius)
                            .fill(tokens.accentPrimary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, tokens.spacingUnit)
    }
}

/// 单项权限的引导行：展示用途、当前状态，并提供授权与前往系统设置入口。
private struct PermissionRow: View {
    @Environment(\.themeTokens) private var tokens

    let title: String
    let purpose: String
    let status: PermissionStatus
    let onAuthorize: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.spacingUnit) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(tokens.textPrimary)
                Spacer()
                statusBadge
            }

            Text(purpose)
                .font(.subheadline)
                .foregroundColor(tokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if status != .authorized {
                HStack(spacing: tokens.spacingUnit) {
                    Button("授权", action: onAuthorize)
                        .buttonStyle(.plain)
                        .foregroundColor(tokens.background)
                        .padding(.horizontal, tokens.spacingUnit * 1.5)
                        .padding(.vertical, tokens.spacingUnit * 0.75)
                        .background(
                            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                                .fill(tokens.accentPrimary)
                        )

                    Button("前往系统设置", action: onOpenSettings)
                        .buttonStyle(.plain)
                        .foregroundColor(tokens.accentPrimary)
                        .padding(.horizontal, tokens.spacingUnit * 1.5)
                        .padding(.vertical, tokens.spacingUnit * 0.75)
                        .background(
                            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                                .stroke(tokens.accentSecondary, lineWidth: 1)
                        )
                }
            }
        }
        .padding(tokens.spacingUnit * 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: tokens.cornerRadius)
                .fill(tokens.surface)
        )
    }

    /// 当前权限状态的中文徽标。
    private var statusBadge: some View {
        Text(statusText)
            .font(.caption.bold())
            .foregroundColor(statusColor)
            .padding(.horizontal, tokens.spacingUnit)
            .padding(.vertical, tokens.spacingUnit * 0.5)
            .background(
                Capsule().fill(statusColor.opacity(0.15))
            )
    }

    /// 状态对应的中文文案（需求 1.1）。
    private var statusText: String {
        switch status {
        case .authorized: return "已授权"
        case .denied: return "已拒绝"
        case .notDetermined: return "未授权"
        }
    }

    /// 状态对应的令牌色：已授权用主色，其余用录制红提示需要处理（需求 17.4）。
    private var statusColor: Color {
        switch status {
        case .authorized: return tokens.accentPrimary
        case .denied, .notDetermined: return tokens.recording
        }
    }
}

#if DEBUG
/// 预览用的权限替身，便于在 Xcode Canvas 中查看各状态组合。
private final class PreviewPermissionManager: PermissionManaging {
    let screen: PermissionStatus
    let mic: PermissionStatus
    init(screen: PermissionStatus, mic: PermissionStatus) {
        self.screen = screen
        self.mic = mic
    }
    func microphoneStatus() -> PermissionStatus { mic }
    func screenRecordingStatus() -> PermissionStatus { screen }
    func requestMicrophoneAccess() async -> PermissionStatus { mic }
    @discardableResult func requestScreenRecordingAccess() -> Bool { screen == .authorized }
    func audioSourceReadiness() -> AudioSourceReadiness {
        AudioSourceReadiness(systemAudio: screen, microphone: mic)
    }
    @discardableResult func openSystemSettings(for pane: PrivacyPane) -> Bool { true }
}

/// 预览：覆盖「均未授权（浅色）」与「均已授权（深色）」两种典型组合。
///
/// 用经典 `PreviewProvider` 而非 `#Preview` 宏，以兼容仅装有 Command Line Tools
/// 的构建环境（该环境缺少 PreviewsMacros 宏插件）。
struct PermissionOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PermissionOnboardingView(
                viewModel: PermissionOnboardingViewModel(
                    permissions: PreviewPermissionManager(screen: .notDetermined, mic: .notDetermined)
                )
            )
            .themeTokens(.light)
            .previewDisplayName("未授权")

            PermissionOnboardingView(
                viewModel: PermissionOnboardingViewModel(
                    permissions: PreviewPermissionManager(screen: .authorized, mic: .authorized)
                )
            )
            .themeTokens(.dark)
            .previewDisplayName("全部已授权-深色")
        }
    }
}
#endif
