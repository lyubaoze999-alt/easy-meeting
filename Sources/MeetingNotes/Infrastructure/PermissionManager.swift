import AVFoundation
import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#endif

/// 单项权限的授权状态（需求 3.1、3.2、3.3）。
///
/// 屏幕录制权限与麦克风权限各用一个该枚举描述。
enum PermissionStatus: Equatable {
    /// 已授权。
    case authorized
    /// 已拒绝（含被系统策略限制的情况）。
    case denied
    /// 尚未决定，即用户还没在系统弹窗里做过选择。
    case notDetermined
}

/// 待机态使用的双音源就绪情况（需求 3.4、4.2）。
///
/// - 系统声音通路依赖屏幕录制权限（通过 Core Audio Process Tap 采集系统音频）。
/// - 麦克风通路依赖麦克风权限。
struct AudioSourceReadiness: Equatable {
    /// 系统声音音源的权限状态，来源于屏幕录制权限。
    var systemAudio: PermissionStatus
    /// 麦克风音源的权限状态。
    var microphone: PermissionStatus

    /// 系统声音音源是否就绪。
    var isSystemAudioReady: Bool { systemAudio == .authorized }
    /// 麦克风音源是否就绪。
    var isMicrophoneReady: Bool { microphone == .authorized }
    /// 两路音源是否都已就绪，可正常开始录音。
    var isAllReady: Bool { isSystemAudioReady && isMicrophoneReady }
}

/// 系统设置「隐私与安全性」下可跳转的面板（需求 3.2、3.3）。
enum PrivacyPane {
    /// 麦克风面板。
    case microphone
    /// 屏幕录制面板（系统声音采集所需）。
    case screenRecording

    /// 对应的系统设置 URL。
    ///
    /// 使用 `x-apple.systempreferences:` 协议直达对应隐私子面板，
    /// 供 UI 提供「前往系统设置」入口。
    var settingsURL: URL? {
        switch self {
        case .microphone:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .screenRecording:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
    }

    /// 该权限用途的中文说明，供权限引导与待机态提示展示（需求 1.1、3.2、3.3）。
    var purposeDescription: String {
        switch self {
        case .microphone:
            return "麦克风权限用于采集本人声音"
        case .screenRecording:
            return "屏幕录制权限用于采集系统声音"
        }
    }
}

/// 权限管理协议，便于上层与测试替身解耦。
protocol PermissionManaging {
    /// 当前麦克风权限状态。
    func microphoneStatus() -> PermissionStatus
    /// 当前屏幕录制权限状态（系统声音采集所需）。
    func screenRecordingStatus() -> PermissionStatus
    /// 请求麦克风权限，返回用户选择后的最终状态。
    func requestMicrophoneAccess() async -> PermissionStatus
    /// 请求屏幕录制权限，返回是否已授权。
    @discardableResult
    func requestScreenRecordingAccess() -> Bool
    /// 当前双音源就绪情况，供待机态展示（需求 3.4、4.2）。
    func audioSourceReadiness() -> AudioSourceReadiness
    /// 打开系统设置到指定隐私面板，供「前往系统设置」入口使用（需求 3.2、3.3）。
    @discardableResult
    func openSystemSettings(for pane: PrivacyPane) -> Bool
}

/// 权限管理器：检测屏幕录制与麦克风两类权限，提供请求授权与跳转系统设置的能力（需求 3）。
///
/// - 麦克风：通过 `AVCaptureDevice.authorizationStatus(for: .audio)` 检测，
///   通过 `AVCaptureDevice.requestAccess(for:)` 发起授权弹窗。
/// - 屏幕录制：系统声音经 Core Audio Process Tap 采集需要屏幕录制权限，
///   通过 `CGPreflightScreenCaptureAccess()` 检测、`CGRequestScreenCaptureAccess()` 发起授权。
///   由于 Core Graphics 不区分「未决定」与「已拒绝」，这里用一个持久化标记记录
///   是否曾经发起过授权请求，从而推断出 `.notDetermined` 与 `.denied`。
final class PermissionManager: PermissionManaging {

    /// 记录是否曾发起过屏幕录制授权请求的偏好键。
    private static let didRequestScreenRecordingKey =
        "PermissionManager.didRequestScreenRecording"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 麦克风

    func microphoneStatus() -> PermissionStatus {
        Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func requestMicrophoneAccess() async -> PermissionStatus {
        // 仅在尚未决定时弹窗；已决定的状态直接返回，避免无意义请求。
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else {
            return microphoneStatus()
        }
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        return granted ? .authorized : .denied
    }

    /// 将系统授权状态映射为本应用的权限状态枚举。
    private static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    // MARK: - 屏幕录制（系统声音）

    func screenRecordingStatus() -> PermissionStatus {
        if CGPreflightScreenCaptureAccess() {
            return .authorized
        }
        // 未授权时，借助持久化标记区分「未决定」与「已拒绝」：
        // 从未请求过 → 未决定；请求过仍未授权 → 已拒绝。
        return defaults.bool(forKey: Self.didRequestScreenRecordingKey)
            ? .denied
            : .notDetermined
    }

    @discardableResult
    func requestScreenRecordingAccess() -> Bool {
        // 标记已发起请求，使后续状态检测能区分未决定与已拒绝。
        defaults.set(true, forKey: Self.didRequestScreenRecordingKey)
        return CGRequestScreenCaptureAccess()
    }

    // MARK: - 组合状态

    func audioSourceReadiness() -> AudioSourceReadiness {
        AudioSourceReadiness(
            systemAudio: screenRecordingStatus(),
            microphone: microphoneStatus()
        )
    }

    // MARK: - 跳转系统设置

    @discardableResult
    func openSystemSettings(for pane: PrivacyPane) -> Bool {
        guard let url = pane.settingsURL else { return false }
        #if canImport(AppKit)
        return NSWorkspace.shared.open(url)
        #else
        return false
        #endif
    }
}
