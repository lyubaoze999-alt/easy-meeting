import Foundation
import Combine

/// 录音状态机的四个状态（应用服务层，对应设计「RecordingCoordinator」与状态机图）。
///
/// 待机 → 录音中 ↔ 暂停 → 结束。菜单栏面板按此状态切换展示内容（需求 4.8、6.8）。
enum RecordingState: Equatable {
    /// 待机：未开始录音，菜单栏面板展示待机态（需求 4）。
    case idle
    /// 录音中：正在采集音频，时长持续走动（需求 6.1、6.2）。
    case recording
    /// 暂停：保留已录制内容、停止采集，时长冻结（需求 6.6）。
    case paused
    /// 结束：已停止录音，等待 / 进入离线处理（需求 6.8、8）。
    case finished

    /// 面向用户的中文状态名（需求 1.1）。
    var displayName: String {
        switch self {
        case .idle: return "待机"
        case .recording: return "录音中"
        case .paused: return "暂停"
        case .finished: return "结束"
        }
    }
}

/// 驱动状态机迁移的事件。与状态共同决定下一个状态（见 `RecordingCoordinator.nextState`）。
enum RecordingEvent: Equatable {
    /// 开始记录（待机 → 录音中，需求 4.8）。
    case start
    /// 暂停（录音中 → 暂停，需求 6.6）。
    case pause
    /// 继续（暂停 → 录音中，需求 6.7）。
    case resume
    /// 结束并生成纪要（录音中 / 暂停 → 结束，需求 6.8）。
    case stop
}

/// 状态机迁移相关错误。
enum RecordingCoordinatorError: Error, Equatable {
    /// 在当前状态下触发了非法事件（如待机态点暂停），迁移被拒绝。
    case illegalTransition(from: RecordingState, event: RecordingEvent)
}

/// 录音协调器（应用服务层，对应设计「RecordingCoordinator」、需求 4.8、6.5-6.8、7.1、7.2）。
///
/// 职责：
/// - 管理待机 / 录音中 / 暂停 / 结束状态机迁移，并守护非法迁移（需求 4.8、6.6、6.7、6.8）。
/// - 累计「实际录音时长」：仅在录音中累加，暂停冻结、继续接续（供录音态计时与 Property 1 对齐，需求 6.2）。
/// - 持有重点标记时间点列表与本次所选模板；支持录音态切换模板（需求 6.5）、
///   一键添加重点标记并记录当前录制时间点（需求 7.1、7.2）。
/// - 驱动注入的 `AudioCaptureService` 执行 start / pause / resume / stop，
///   并把录音产物（WAV、重点标记、模板）交给后续处理流程（任务 12.1 消费）。
///
/// 迁移逻辑抽为纯函数 `nextState(from:on:)`，便于单元测试（任务 11.2）。
///
/// 作为 `ObservableObject`，`state` / `selectedTemplate` / `highlights` 变化驱动菜单栏面板刷新。
@MainActor
final class RecordingCoordinator: ObservableObject {
    /// 当前录音状态，菜单栏面板绑定此值切换四态（需求 4.8、6.8）。
    @Published private(set) var state: RecordingState = .idle

    /// 本次录音所选模板，录音态可切换（需求 6.4、6.5）。
    @Published private(set) var selectedTemplate: NoteTemplate

    /// 重点标记时间点列表，单位为「自录音开始的实际录音秒数」（需求 7.1、7.2）。
    @Published private(set) var highlights: [TimeInterval] = []

    /// 本次录音结束后产出的混音 WAV 文件地址，供处理流程消费（需求 6.8、8.1）。
    private(set) var recordedAudioURL: URL?

    /// 本次录音会话的开始时间，在 `start()` 时记录，供结束后构建 `ProcessingInput` 的会议起始时间（需求 8.1）。
    /// 与「实际录音时长」`elapsedDuration` 配合，确定纪要的开始时间与持续时长。
    private(set) var sessionStartedAt: Date?

    private let audioCapture: AudioCaptureService
    /// 可注入的时钟，便于测试时长累计（默认取系统时间）。
    private let clock: () -> Date

    /// 已完成录音段的累计时长（不含当前正在录制的这一段）。
    private var accumulatedDuration: TimeInterval = 0
    /// 当前录音段的起始时间；非录音中时为 nil。
    private var segmentStartedAt: Date?

    /// - Parameters:
    ///   - audioCapture: 双音源采集服务，被状态机驱动 start/pause/resume/stop（需求 5、6）。
    ///   - initialTemplate: 本次录音的初始模板（通常取 `TemplateManager.defaultTemplate`）。
    ///   - clock: 时间来源，默认 `Date()`；测试注入可控时钟以验证时长累计。
    init(audioCapture: AudioCaptureService,
         initialTemplate: NoteTemplate,
         clock: @escaping () -> Date = { Date() }) {
        self.audioCapture = audioCapture
        self.selectedTemplate = initialTemplate
        self.clock = clock
    }
}

// MARK: - 纯迁移函数（供守护方法与单元测试复用，任务 11.2）

extension RecordingCoordinator {
    /// 给定当前状态与事件，返回下一个合法状态；非法迁移返回 nil。
    ///
    /// 合法迁移：
    /// - 待机 --start--> 录音中
    /// - 录音中 --pause--> 暂停
    /// - 暂停 --resume--> 录音中
    /// - 录音中 / 暂停 --stop--> 结束
    ///
    /// 其余组合（如待机态 stop、结束态任何事件）均为非法，返回 nil。
    static func nextState(from current: RecordingState, on event: RecordingEvent) -> RecordingState? {
        switch (current, event) {
        case (.idle, .start): return .recording
        case (.recording, .pause): return .paused
        case (.paused, .resume): return .recording
        case (.recording, .stop), (.paused, .stop): return .finished
        default: return nil
        }
    }
}

// MARK: - 状态迁移（驱动音频采集）

extension RecordingCoordinator {
    /// 开始记录：待机 → 录音中（需求 4.8）。
    ///
    /// 先启动音频采集，成功后才清零本次会话数据并迁移状态；采集启动失败则保持待机态。
    func start() async throws {
        guard let next = Self.nextState(from: state, on: .start) else {
            throw RecordingCoordinatorError.illegalTransition(from: state, event: .start)
        }
        try await audioCapture.start()
        // 新会话：清空上次的重点标记与产物，时长归零。
        accumulatedDuration = 0
        highlights = []
        recordedAudioURL = nil
        let now = clock()
        sessionStartedAt = now
        segmentStartedAt = now
        state = next
    }

    /// 暂停：录音中 → 暂停，保留已录制内容并冻结时长（需求 6.6）。
    func pause() throws {
        guard let next = Self.nextState(from: state, on: .pause) else {
            throw RecordingCoordinatorError.illegalTransition(from: state, event: .pause)
        }
        freezeCurrentSegment()
        audioCapture.pause()
        state = next
    }

    /// 继续：暂停 → 录音中，在已录制内容之后接续采集并恢复计时（需求 6.7）。
    func resume() throws {
        guard let next = Self.nextState(from: state, on: .resume) else {
            throw RecordingCoordinatorError.illegalTransition(from: state, event: .resume)
        }
        audioCapture.resume()
        segmentStartedAt = clock()
        state = next
    }

    /// 结束并生成纪要：录音中 / 暂停 → 结束（需求 6.8）。
    ///
    /// 先冻结时长，再停止采集并保存 WAV 地址，最后迁移到结束态。
    /// - Returns: 混音后的 WAV 文件地址，交给处理流程（任务 12.1）。
    @discardableResult
    func stop() async throws -> URL {
        guard let next = Self.nextState(from: state, on: .stop) else {
            throw RecordingCoordinatorError.illegalTransition(from: state, event: .stop)
        }
        freezeCurrentSegment()
        let url = try await audioCapture.stop()
        recordedAudioURL = url
        state = next
        return url
    }

    /// 重置回待机态，清空本次会话数据（处理流程接手后回到待机，对应状态机图「完成 → 待机」）。
    ///
    /// 保留当前所选模板。任意状态均可调用。
    func reset() {
        accumulatedDuration = 0
        segmentStartedAt = nil
        sessionStartedAt = nil
        highlights = []
        recordedAudioURL = nil
        state = .idle
    }

    /// 把当前正在录制的这一段时长并入累计值，并清空段起点。非录音中调用为幂等空操作。
    private func freezeCurrentSegment() {
        if let started = segmentStartedAt {
            accumulatedDuration += clock().timeIntervalSince(started)
            segmentStartedAt = nil
        }
    }
}

// MARK: - 实际录音时长（需求 6.2）

extension RecordingCoordinator {
    /// 自录音开始的实际录音时长（秒），仅在录音中累加，暂停冻结、继续接续。
    ///
    /// 录音中时为「已完成段累计 + 当前段已录时长」；暂停 / 结束 / 待机时为已冻结的累计值。
    /// 录音态计时与重点标记时间点均以此为准（需求 6.2、7.2、Property 1）。
    var elapsedDuration: TimeInterval {
        guard let started = segmentStartedAt else { return accumulatedDuration }
        return accumulatedDuration + clock().timeIntervalSince(started)
    }
}

// MARK: - 模板切换（需求 6.5）

extension RecordingCoordinator {
    /// 切换本次录音所选模板（需求 6.5）。
    ///
    /// 待机 / 录音中 / 暂停态均可切换；结束态不再变更，避免影响已交付处理流程的会话快照。
    /// - Returns: 是否成功切换。
    @discardableResult
    func selectTemplate(_ template: NoteTemplate) -> Bool {
        guard state != .finished else { return false }
        selectedTemplate = template
        return true
    }
}

// MARK: - 重点标记（需求 7.1、7.2）

extension RecordingCoordinator {
    /// 一键添加重点标记，记录当前实际录音时间点（需求 7.1、7.2）。
    ///
    /// 仅在录音中 / 暂停态有效（录音会话进行中）；其余状态忽略。
    /// - Returns: 记录下的时间点（秒）；非有效状态返回 nil。
    @discardableResult
    func addHighlight() -> TimeInterval? {
        guard state == .recording || state == .paused else { return nil }
        let timestamp = elapsedDuration
        highlights.append(timestamp)
        return timestamp
    }
}
