import '../app_services/meeting_session_controller.dart';
import '../domain/models/processing_job.dart';

/// Pure, user-visible tray copy and state mapping.
///
/// The capture lifecycle does not prove that a note exists. In particular,
/// [MeetingSessionPhase.completed] is therefore presented as a saved
/// recording; note-generation copy belongs to an explicit processing stage.
abstract final class DesktopTrayPresentation {
  static const stopRecordingLabel = '结束录音';
  static const recordingSavedLabel = '录音已保存';

  static String sessionState(
    MeetingSessionPhase phase, {
    Duration elapsed = Duration.zero,
    ProcessingStage processingStage = ProcessingStage.saving,
  }) => switch (phase) {
    MeetingSessionPhase.initializing => '正在恢复未完成任务',
    MeetingSessionPhase.ready => '准备记录',
    MeetingSessionPhase.starting => '正在启动录音',
    MeetingSessionPhase.recording => '正在录音 ${duration(elapsed)}',
    MeetingSessionPhase.pausing => '正在暂停录音',
    MeetingSessionPhase.paused => '录音已暂停 ${duration(elapsed)}',
    MeetingSessionPhase.resuming => '正在继续录音',
    MeetingSessionPhase.stopping => '正在结束录音',
    MeetingSessionPhase.processing => processingState(processingStage),
    MeetingSessionPhase.completed => recordingSavedLabel,
    MeetingSessionPhase.failed => '处理失败，可重试',
  };

  static String processingState(ProcessingStage stage) => switch (stage) {
    ProcessingStage.saving => '正在保存音频',
    ProcessingStage.transcribing => '正在语音转写',
    ProcessingStage.summarizing => '正在生成纪要',
    ProcessingStage.persisting => '正在保存纪要',
    ProcessingStage.done => '处理完成',
    ProcessingStage.failed => '处理失败',
  };

  static String duration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
