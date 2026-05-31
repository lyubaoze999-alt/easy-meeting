import Foundation
import Combine

/// 首次启动权限引导的视图模型（需求 3.1、3.2、3.3）。
///
/// 包裹 `PermissionManaging`，把屏幕录制与麦克风两项权限状态以 `@Published` 暴露给
/// SwiftUI 视图，并提供请求授权、刷新状态、跳转系统设置的动作。视图只读 `@Published`
/// 状态并触发动作，不直接接触权限检测细节，便于以测试替身注入 `PermissionManaging`。
///
/// 同步动作均由 SwiftUI 在主线程触发；异步授权回调可能在任意线程恢复，故对 `@Published`
/// 的写入统一通过 `MainActor.run` 切回主线程，保证发布在主线程进行。
final class PermissionOnboardingViewModel: ObservableObject {
    /// 屏幕录制权限状态（系统声音采集所需，需求 3.2）。
    @Published private(set) var screenRecordingStatus: PermissionStatus
    /// 麦克风权限状态（本人声音采集所需，需求 3.3）。
    @Published private(set) var microphoneStatus: PermissionStatus

    private let permissions: PermissionManaging

    /// - Parameter permissions: 权限管理依赖，默认使用 `PermissionManager()`，
    ///   测试时可注入替身。
    init(permissions: PermissionManaging = PermissionManager()) {
        self.permissions = permissions
        self.screenRecordingStatus = permissions.screenRecordingStatus()
        self.microphoneStatus = permissions.microphoneStatus()
    }

    /// 两项权限是否都已授予，决定引导界面是否可直接进入应用（需求 3.1）。
    var isAllAuthorized: Bool {
        screenRecordingStatus == .authorized && microphoneStatus == .authorized
    }

    /// 重新读取两项权限的最新状态。
    ///
    /// 用户从系统设置返回、或完成系统授权弹窗后调用，确保界面与系统状态一致。
    func refresh() {
        screenRecordingStatus = permissions.screenRecordingStatus()
        microphoneStatus = permissions.microphoneStatus()
    }

    /// 发起麦克风授权请求并刷新状态（需求 3.3）。
    @MainActor
    func requestMicrophone() async {
        microphoneStatus = await permissions.requestMicrophoneAccess()
    }

    /// 发起屏幕录制授权请求并刷新状态（需求 3.2）。
    ///
    /// 屏幕录制权限的实际生效通常需用户在系统弹窗中勾选，这里请求后立即刷新一次，
    /// 用户也可通过「前往系统设置」完成授权后再回到界面刷新。
    func requestScreenRecording() {
        permissions.requestScreenRecordingAccess()
        screenRecordingStatus = permissions.screenRecordingStatus()
    }

    /// 打开系统设置到指定隐私面板（需求 3.2、3.3 的「前往系统设置」入口）。
    func openSystemSettings(for pane: PrivacyPane) {
        permissions.openSystemSettings(for: pane)
    }
}
