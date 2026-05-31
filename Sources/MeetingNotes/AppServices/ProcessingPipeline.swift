import Foundation
import Combine

/// 离线处理阶段（应用服务层，对应设计「ProcessingPipeline」、需求 8.1、8.2）。
///
/// 阶段严格单调向前推进：待机 → 保存音频 → 语音转写 → 生成纪要 → 完成，
/// 任意阶段失败进入 `failed`（终态）。转写阶段携带「当前片号 / 总片数」进度，
/// 供处理态面板展示（需求 8.4、9.3）。阶段不回退、转写片号不倒退（Property 3「进度单调且完整」）。
enum ProcessingStage: Equatable {
    /// 待机：尚未开始处理。
    case idle
    /// 保存音频：归档录音并计算时长与文件大小（需求 8.1、8.3）。
    case savingAudio
    /// 语音转写：携带当前处理的片段序号与总片段数（需求 8.4、9.3）。
    case transcribing(current: Int, total: Int)
    /// 生成纪要：调用总结服务生成结构化纪要（需求 8.1、8.5）。
    case summarizing
    /// 完成：纪要已生成并落库（需求 8.8）。
    case done
    /// 处理失败：携带失败原因（终态）。
    case failed(ProcessingError)

    /// 阶段排序值，用于守护单调推进（数值越大越靠后）。`failed` 单独处理，不参与比较。
    var rank: Int {
        switch self {
        case .idle: return 0
        case .savingAudio: return 1
        case .transcribing: return 2
        case .summarizing: return 3
        case .done: return 4
        case .failed: return Int.min
        }
    }

    /// 面向用户的中文阶段名（需求 1.1、8.2）。
    var displayName: String {
        switch self {
        case .idle: return "待机"
        case .savingAudio: return "保存音频"
        case .transcribing: return "语音转写"
        case .summarizing: return "生成纪要"
        case .done: return "完成"
        case .failed: return "处理失败"
        }
    }
}

/// 处理流程中可能出现的错误（对应设计「Error Handling」、需求 15.6）。
enum ProcessingError: Error, Equatable {
    /// 进入处理前发现转写或总结服务尚未配置，携带未配置的服务列表（需求 15.6、Property 4）。
    case servicesNotConfigured([ConfigurableService])
    /// 录音文件缺失或不可读，无法进入处理。
    case audioUnavailable(reason: String)
    /// 语音转写阶段失败。
    case transcriptionFailed(reason: String)
    /// 生成纪要阶段失败。
    case summarizationFailed(reason: String)
    /// 纪要落库失败。
    case persistenceFailed(reason: String)

    /// 面向用户的中文提示文案（需求 1.1）。
    var message: String {
        switch self {
        case let .servicesNotConfigured(services):
            let names = services.map(\.displayName).joined(separator: "、")
            return "\(names)尚未配置，请先在设置中完成配置后再开始处理。"
        case let .audioUnavailable(reason):
            return "录音文件不可用：\(reason)"
        case let .transcriptionFailed(reason):
            return "语音转写失败：\(reason)"
        case let .summarizationFailed(reason):
            return "生成纪要失败：\(reason)"
        case let .persistenceFailed(reason):
            return "纪要保存失败：\(reason)"
        }
    }
}

/// 音频保存阶段产出的音频信息，供处理态面板展示（需求 8.3）。
struct ProcessedAudioInfo: Equatable {
    /// 录音时长（秒）。
    let duration: TimeInterval
    /// 音频文件字节数。
    let fileSizeBytes: Int64

    /// 时长的中文展示文案（mm:ss 或 hh:mm:ss）。
    var durationText: String {
        let total = Int(duration.rounded())
        let seconds = total % 60
        let minutes = (total / 60) % 60
        let hours = total / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 文件大小的中文展示文案（B / KB / MB）。
    var fileSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }
}

/// 启动处理流程所需的输入快照，由录音协调器在结束录音后提供（需求 8.1）。
struct ProcessingInput {
    /// 录音产出的混音 WAV 文件地址。
    let audioURL: URL
    /// 本次录音所选纪要模板。
    let template: NoteTemplate
    /// 重点标记时间点（相对录音起点的秒数，需求 7）。
    let highlights: [TimeInterval]
    /// 录音开始时间。
    let startedAt: Date
    /// 录音总时长（秒）。
    let duration: TimeInterval

    init(audioURL: URL,
         template: NoteTemplate,
         highlights: [TimeInterval],
         startedAt: Date,
         duration: TimeInterval) {
        self.audioURL = audioURL
        self.template = template
        self.highlights = highlights
        self.startedAt = startedAt
        self.duration = duration
    }
}

/// 离线处理流程编排器（应用服务层，对应设计「ProcessingPipeline」、需求 8.1-8.5、15.6）。
///
/// 职责：
/// - 顺序执行「保存音频 → 语音转写 → 生成纪要」，对外发布单调推进的阶段进度（需求 8.1、8.2、Property 3）。
/// - 进入处理前校验转写与总结服务均已配置，未配置则阻断并给出中文提示，不进入处理（需求 15.6、Property 4）。
/// - 保存音频阶段完成后，暴露录音时长与文件大小供处理态面板展示（需求 8.3）。
/// - 转写阶段把 `当前片号 / 总片数` 进度透传到 `stage`（需求 8.4、9.3）。
/// - 生成阶段调用总结服务生成 `MeetingNote`，随后经仓储归档落库（需求 8.5）。
///
/// 后台继续与完成通知由任务 12.2 实现：处理态面板调用 `continueInBackgroundAndNotify()`
/// 标记用户希望「在后台继续，完成后通知我」（需求 8.6）；当处理推进到 `done`（需求 8.8 切换完成态）
/// 且此前已标记后台通知时，经注入的 `CompletionNotifying` 发出一条本地完成通知（需求 8.7）。
/// 失败时把错误体现在 `stage = .failed(...)` 与 `lastError`，不发系统通知。
///
/// 作为 `ObservableObject`，`stage` / `audioInfo` / `generatedNote` 变化驱动处理态面板刷新。
@MainActor
final class ProcessingPipeline: ObservableObject {
    /// 当前处理阶段，处理态面板绑定此值分步展示（需求 8.2、8.4）。
    @Published private(set) var stage: ProcessingStage = .idle

    /// 保存音频阶段产出的音频信息（时长、文件大小，需求 8.3）；未完成保存阶段时为 nil。
    @Published private(set) var audioInfo: ProcessedAudioInfo?

    /// 当前转写服务模型名，供处理态面板展示（需求 8.4）。
    @Published private(set) var transcriptionModel: String = ""

    /// 处理成功后生成并落库的纪要（需求 8.8）；未完成时为 nil。
    @Published private(set) var generatedNote: MeetingNote?

    /// 最近一次失败的错误，供界面展示提示（需求 15.6）。
    @Published private(set) var lastError: ProcessingError?

    /// 用户是否已选择「在后台继续，完成后通知我」（需求 8.6）。
    ///
    /// 处理态面板绑定此值高亮入口；为 true 时，处理完成会发出系统通知（需求 8.7）。
    @Published private(set) var willNotifyOnCompletion: Bool = false

    private let transcriptionService: TranscriptionService
    private let summaryService: SummaryService
    private let noteRepository: NoteStoring
    private let settingsStore: SettingsStore
    private let completionNotifier: CompletionNotifying
    private let fileManager: FileManager

    /// - Parameters:
    ///   - transcriptionService: 转写服务（领域能力层），切片转写并发布片号进度。
    ///   - summaryService: 纪要生成服务（领域能力层）。
    ///   - noteRepository: 纪要仓储（基础设施层），归档音频/转写/正文并入库。
    ///   - settingsStore: 配置管理，用于进入处理前的「服务是否已配置」阻断判定（需求 15.6）。
    ///   - completionNotifier: 完成通知能力（基础设施层），后台继续完成后发本地通知（需求 8.7）；
    ///     默认按平台选取系统实现或无操作实现。
    ///   - fileManager: 文件管理器，默认 `.default`（便于测试注入）。
    init(transcriptionService: TranscriptionService,
         summaryService: SummaryService,
         noteRepository: NoteStoring,
         settingsStore: SettingsStore,
         completionNotifier: CompletionNotifying = CompletionNotifierFactory.makeDefault(),
         fileManager: FileManager = .default) {
        self.transcriptionService = transcriptionService
        self.summaryService = summaryService
        self.noteRepository = noteRepository
        self.settingsStore = settingsStore
        self.completionNotifier = completionNotifier
        self.fileManager = fileManager
    }
}

// MARK: - 后台继续与完成通知（需求 8.6、8.7）

extension ProcessingPipeline {
    /// 处理态面板点击「在后台继续，完成后通知我」时调用（需求 8.6）。
    ///
    /// 标记后台通知意图并提前请求通知授权，确保处理完成时（需求 8.8 切换完成态）
    /// 能成功投递一条「纪要已生成完成」通知（需求 8.7）。
    /// 若处理已完成（已有生成的纪要），则立即补发一次通知。
    func continueInBackgroundAndNotify() async {
        willNotifyOnCompletion = true
        await completionNotifier.requestAuthorization()
        // 若用户在处理完成后才点击，立即补发通知，避免错过完成态。
        if case .done = stage, let note = generatedNote {
            await completionNotifier.notifyCompletion(meetingTitle: note.title)
        }
    }
}

// MARK: - 阶段推进守护（Property 3：单调推进，不回退）

extension ProcessingPipeline {
    /// 把阶段推进到 `next`，仅允许向前（rank 递增）或进入终态 `failed`。
    ///
    /// 转写阶段内部的片号推进由 `advanceTranscription(current:total:)` 单独守护，
    /// 此处对同处转写阶段的更新放行（交由片号守护处理），其余阶段必须 rank 严格递增。
    private func advance(to next: ProcessingStage) {
        switch next {
        case .failed:
            stage = next
        default:
            // 同阶段（如转写中片号更新）交由专门方法处理，这里只放行更靠后的阶段。
            if next.rank > stage.rank {
                stage = next
            }
        }
    }

    /// 推进转写片号：总片数固定，当前片号只增不减（Property 3）。
    ///
    /// 从非转写阶段首次进入时直接置为转写态；已在转写态时，仅当 `current` 不小于已发布片号才更新。
    private func advanceTranscription(current: Int, total: Int) {
        if case let .transcribing(published, _) = stage {
            guard current >= published else { return }
            stage = .transcribing(current: current, total: total)
        } else if stage.rank < ProcessingStage.transcribing(current: 0, total: 0).rank {
            stage = .transcribing(current: current, total: total)
        }
    }
}

// MARK: - 处理流程编排（需求 8.1-8.5）

extension ProcessingPipeline {
    /// 执行完整处理流程：校验配置 → 保存音频 → 转写 → 生成 → 落库。
    ///
    /// 进入处理前先做配置阻断（需求 15.6、Property 4）；任一阶段抛错则进入 `failed` 终态，
    /// 已完成阶段不回退（需求 8 错误处理）。
    /// - Parameter input: 录音结束后的输入快照。
    /// - Returns: 成功时返回生成并落库的纪要；阻断或失败时返回 nil（错误见 `lastError` / `stage`）。
    @discardableResult
    func process(_ input: ProcessingInput) async -> MeetingNote? {
        // 新一轮处理：清空上轮产物并把阶段归零，使单调推进守护从 idle 起算。
        stage = .idle
        audioInfo = nil
        generatedNote = nil
        lastError = nil
        willNotifyOnCompletion = false

        // 0) 配置校验：转写或总结服务未配置则阻断，不进入处理（需求 15.6、Property 4）。
        let unconfigured = settingsStore.unconfiguredServices
        guard unconfigured.isEmpty else {
            fail(.servicesNotConfigured(unconfigured))
            return nil
        }

        let transcriptionConfig = settingsStore.config(for: .transcription)
        let summaryConfig = settingsStore.config(for: .summary)
        transcriptionModel = transcriptionConfig.model

        let noteId = UUID()

        // 1) 保存音频阶段：校验文件可读，计算时长与文件大小（需求 8.1、8.3）。
        advance(to: .savingAudio)
        let info: ProcessedAudioInfo
        do {
            info = try makeAudioInfo(for: input)
        } catch let error as ProcessingError {
            fail(error)
            return nil
        } catch {
            fail(.audioUnavailable(reason: error.localizedDescription))
            return nil
        }
        audioInfo = info

        // 2) 语音转写阶段：逐片转写，透传片号进度（需求 8.4、9.3）。
        advanceTranscription(current: 0, total: 1)
        let transcript: String
        do {
            transcript = try await transcriptionService.transcribe(
                audio: input.audioURL,
                config: transcriptionConfig
            ) { [weak self] current, total in
                Task { @MainActor in
                    self?.advanceTranscription(current: current, total: total)
                }
            }
        } catch {
            fail(.transcriptionFailed(reason: errorReason(error)))
            return nil
        }

        // 3) 生成纪要阶段：调用总结服务生成结构化纪要（需求 8.5）。
        advance(to: .summarizing)
        let context = SummaryContext(
            noteId: noteId,
            startedAt: input.startedAt,
            duration: input.duration,
            audioPath: input.audioURL.path,
            transcriptPath: ""
        )
        let note: MeetingNote
        do {
            note = try await summarize(
                transcript: transcript,
                input: input,
                config: summaryConfig,
                context: context
            )
        } catch {
            fail(.summarizationFailed(reason: errorReason(error)))
            return nil
        }

        // 4) 落库：归档音频、原始转写、正文 JSON 并写入元数据。
        let saved: MeetingNote
        do {
            saved = try noteRepository.save(
                note,
                audioSource: input.audioURL,
                transcriptText: transcript
            )
        } catch {
            fail(.persistenceFailed(reason: errorReason(error)))
            return nil
        }

        generatedNote = saved
        advance(to: .done)
        // 切换完成态后（需求 8.8），若用户此前选择了后台继续，发出完成通知（需求 8.7）。
        if willNotifyOnCompletion {
            await completionNotifier.notifyCompletion(meetingTitle: saved.title)
        }
        return saved
    }

    /// 调用总结服务生成纪要。优先使用 `LLMSummaryService` 的带上下文重载以回填元数据，
    /// 否则退回协议方法。
    private func summarize(transcript: String,
                           input: ProcessingInput,
                           config: ServiceConfig,
                           context: SummaryContext) async throws -> MeetingNote {
        let imageMode = settingsStore.settings.imageMode
        if let llm = summaryService as? LLMSummaryService {
            return try await llm.summarize(
                transcript: transcript,
                template: input.template,
                highlights: input.highlights,
                imageMode: imageMode,
                config: config,
                context: context
            )
        }
        return try await summaryService.summarize(
            transcript: transcript,
            template: input.template,
            highlights: input.highlights,
            imageMode: imageMode,
            config: config
        )
    }

    /// 计算录音时长与文件大小（需求 8.3）；文件缺失或不可读时抛 `ProcessingError`。
    private func makeAudioInfo(for input: ProcessingInput) throws -> ProcessedAudioInfo {
        guard fileManager.fileExists(atPath: input.audioURL.path) else {
            throw ProcessingError.audioUnavailable(reason: "音频文件不存在")
        }
        let attributes = try fileManager.attributesOfItem(atPath: input.audioURL.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        return ProcessedAudioInfo(duration: input.duration, fileSizeBytes: size)
    }

    /// 进入失败终态并记录错误（需求 15.6、错误处理）。
    private func fail(_ error: ProcessingError) {
        lastError = error
        stage = .failed(error)
    }

    /// 重置回待机态，清空上次产物（处理态面板关闭后复用，对应状态机「完成/失败 → 待机」）。
    func reset() {
        stage = .idle
        audioInfo = nil
        transcriptionModel = ""
        generatedNote = nil
        lastError = nil
        willNotifyOnCompletion = false
    }

    /// 把领域层错误转为面向用户的中文原因；已是 `ProcessingError` 则取其 message。
    private func errorReason(_ error: Error) -> String {
        if let processing = error as? ProcessingError {
            return processing.message
        }
        return error.localizedDescription
    }
}
