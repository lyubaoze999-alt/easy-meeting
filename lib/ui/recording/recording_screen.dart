import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/live_transcription_controller.dart';
import '../../app_services/managed_live_transcription_session.dart';
import '../../app_services/meeting_session_controller.dart';
import '../../app_services/meeting_session_state.dart';
import '../../app_services/providers.dart';
import '../../domain/models/configuration.dart';
import '../../domain/models/note_template.dart';
import '../../domain/models/processing_job.dart';
import '../../domain/models/recording_asset.dart';
import '../../domain/models/transcript_document.dart';
import '../library/meeting_detail_screen.dart' show meetingDisplayTitle;
import 'live_transcript_panel.dart';
import 'meeting_workspace.dart';
import 'recording_saved_panel.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  const RecordingScreen({super.key});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  NoteTemplate _template = NoteTemplate.builtins.first;
  bool? _liveRequested;
  final Set<String> _postProcessingMeetings = <String>{};
  final Map<String, TranscriptDocument> _generatedTranscripts =
      <String, TranscriptDocument>{};
  bool _recoveryDeferred = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetingSessionProvider);
    final live = ref.watch(liveTranscriptionProvider);
    final settings = ref.watch(settingsProvider).valueOrNull;
    final recording = session.recording;
    final phase = session.state.capturePhase;
    final realtime = settings?.realtimeTranscription;
    final recovery = ref.watch(recordingRecoveryProvider);
    final supportsRealtimePcm = ref
        .watch(platformProfileProvider)
        .supportsRealtimePcm;
    _liveRequested ??= supportsRealtimePcm && (realtime?.enabled ?? false);
    final library = ref.watch(meetingLibraryProvider);
    final recentMeetings = (library.valueOrNull ?? const <MeetingAssetBundle>[])
        .take(kRecentMeetingsLimit)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('会议纪要'),
        actions: [
          if (phase == CapturePhase.recording || phase == CapturePhase.paused)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: _LiveStatusChip(phase: live.phase)),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (phase) {
          CapturePhase.idle => _PreparationPanel(
            template: _template,
            realtime: realtime,
            liveRequested: _liveRequested!,
            realtimeSupported: supportsRealtimePcm,
            orphanRecordings: _recoveryDeferred
                ? const <OrphanRecording>[]
                : recovery.pending,
            isRecordingRecoveryBusy: recovery.isProcessing,
            onTemplateChanged: (value) => setState(() => _template = value),
            onLiveChanged: (value) => setState(() => _liveRequested = value),
            onArchiveRecording: _archiveRecording,
            onDeleteRecording: _confirmDeleteRecording,
            onDeferRecovery: () => setState(() => _recoveryDeferred = true),
            onStart: () => _startMeeting(session, realtime),
            recentMeetings: recentMeetings,
            onRecentMeetingTap: (id) =>
                ref.read(selectedMeetingIdProvider.notifier).state = id,
          ),
          CapturePhase.starting => const _TransitionPanel(
            icon: Icons.mic_none,
            title: '正在启动录音',
            message: '先建立本地录音；实时服务稍后独立连接。',
          ),
          CapturePhase.recording ||
          CapturePhase.pausing ||
          CapturePhase.paused ||
          CapturePhase.resuming ||
          CapturePhase.stopping ||
          CapturePhase.finalizingFile => MeetingWorkspace(
            elapsed: recording.elapsed,
            systemLevel: recording.systemLevel,
            microphoneLevel: recording.microphoneLevel,
            systemAudioAvailable: recording.systemAudioAvailable,
            microphoneAvailable: recording.microphoneAvailable,
            isPaused:
                phase == CapturePhase.paused || phase == CapturePhase.pausing,
            transitioning:
                phase == CapturePhase.pausing ||
                phase == CapturePhase.resuming ||
                phase == CapturePhase.stopping ||
                phase == CapturePhase.finalizingFile,
            highlightCount: recording.highlights.length,
            connectionLabel: _liveLabel(live.phase),
            liveDegradedMessage: _liveDegradedMessage(live.phase),
            transcriptLines: live.items
                .where((item) => item.text.trim().isNotEmpty)
                .map(_lineFromItem)
                .toList(growable: false),
            realtimeSupported: supportsRealtimePcm,
            degradationReason: recording.degradationReason,
            onPauseResume: () => _run(
              phase == CapturePhase.paused
                  ? session.resumeRecording
                  : session.pauseRecording,
            ),
            onStop: () => _stopMeeting(session),
            onHighlight: session.markHighlight,
          ),
          CapturePhase.recorded => _savedPanel(session, live),
          CapturePhase.failed => _FailurePanel(
            message: '${session.state.captureError ?? '录音未能完成，请检查权限和存储空间。'}',
            onReset: () => _run(session.prepareNextMeeting),
          ),
        },
      ),
    );
  }

  Widget _savedPanel(
    MeetingSessionController session,
    ManagedLiveTranscriptionSession live,
  ) {
    final asset = ref.read(appServicesProvider).persistentCapture.lastAsset;
    if (asset == null) {
      return const _TransitionPanel(
        icon: Icons.save_outlined,
        title: '正在确认录音文件',
        message: '录音不会在确认归档完成前显示为已保存。',
      );
    }
    final stopResult = live.stopResultForMeeting(asset.meetingId);
    final transcriptStatus = switch ((
      _postProcessingMeetings.contains(asset.meetingId),
      live.hasPendingFinalization,
      stopResult?.outcome,
    )) {
      (true, _, _) => SavedTranscriptStatus.processing,
      (_, true, _) => SavedTranscriptStatus.processing,
      (_, _, LiveTranscriptionStopOutcome.frozen) =>
        SavedTranscriptStatus.ready,
      (_, _, LiveTranscriptionStopOutcome.needsRepair) =>
        SavedTranscriptStatus.needsRepair,
      _ when _generatedTranscripts.containsKey(asset.meetingId) =>
        SavedTranscriptStatus.ready,
      _ => SavedTranscriptStatus.missing,
    };
    final finalTranscript =
        stopResult?.finalTranscript ?? _generatedTranscripts[asset.meetingId];
    return RecordingSavedPanel(
      duration: asset.duration,
      byteLength: asset.byteLength,
      sourceLabel: switch (asset.sourceProfile.name) {
        'dualSource' => '系统声音 + 麦克风',
        'microphoneOnly' => '仅麦克风',
        _ => '录音来源未知',
      },
      transcriptStatus: transcriptStatus,
      onPlay: () => unawaited(_openAsset(asset.path)),
      onReveal: () => unawaited(_revealAsset(asset.path)),
      onGenerateTranscript: () => _enqueueTranscript(asset.meetingId),
      onGenerateNote: finalTranscript == null
          ? null
          : () => _enqueueSummary(asset.meetingId, finalTranscript.id),
      onNextMeeting: () => _run(() async {
        await session.prepareNextMeeting();
        if (mounted) {
          setState(() {});
        }
        ref.invalidate(meetingLibraryProvider);
      }),
    );
  }

  Future<void> _startMeeting(
    MeetingSessionController session,
    RealtimeServiceConfig? realtime,
  ) {
    final requested = _liveRequested ?? false;
    if (requested && !(realtime?.canStream ?? false)) {
      _message('实时转写尚未完成配置，本场仍会正常保存本地录音。');
    }
    return _run(
      () => session.startMeeting(
        MeetingStartOptions(
          enableLiveTranscription: requested && (realtime?.canStream ?? false),
          template: _template,
        ),
      ),
    );
  }

  Future<void> _stopMeeting(MeetingSessionController session) async {
    // Safe-end: require explicit confirmation before stopping (design spec:
    // double-confirm or long-press). The recording is saved safely and no AI
    // work is promised on this screen.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束录音？'),
        content: const Text('录音会安全保存到本地。本页不会自动生成纪要，可在会议库中继续。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续录音'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('结束录音'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _run(() async {
      await session.stopRecording();
      if (mounted) ref.invalidate(meetingLibraryProvider);
    });
  }

  Future<void> _enqueueTranscript(String meetingId) => _run(() async {
    setState(() => _postProcessingMeetings.add(meetingId));
    try {
      final queue = ref.read(postProcessingProvider);
      final job = await queue.enqueueTranscript(meetingId);
      _message('正式转写任务已开始，录音可继续正常使用。');
      await queue.waitUntilIdle();
      final savedJob = await ref.read(appServicesProvider).jobs.load(job.id);
      if (savedJob?.stage == ProcessingStage.failed) {
        throw StateError(savedJob?.failureMessage ?? '正式转写失败，请在会议库中重试。');
      }
      final transcript = await ref
          .read(appServicesProvider)
          .transcripts
          .finalForMeeting(meetingId);
      if (mounted) {
        setState(() {
          if (transcript != null) _generatedTranscripts[meetingId] = transcript;
        });
        _message('正式转写已完成');
      }
      ref.invalidate(meetingLibraryProvider);
    } finally {
      if (mounted) {
        setState(() => _postProcessingMeetings.remove(meetingId));
      }
    }
  });

  Future<void> _enqueueSummary(String meetingId, String transcriptId) => _run(
    () async {
      setState(() => _postProcessingMeetings.add(meetingId));
      try {
        final queue = ref.read(postProcessingProvider);
        final job = await queue.enqueueSummary(meetingId, transcriptId);
        _message('会议纪要生成任务已开始。');
        await queue.waitUntilIdle();
        final savedJob = await ref.read(appServicesProvider).jobs.load(job.id);
        if (savedJob?.stage == ProcessingStage.failed) {
          throw StateError(savedJob?.failureMessage ?? '会议纪要生成失败，请重试。');
        }
        _message('会议纪要已生成，可在会议库查看。');
        ref.invalidate(meetingLibraryProvider);
      } finally {
        if (mounted) {
          setState(() => _postProcessingMeetings.remove(meetingId));
        }
      }
    },
  );

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _archiveRecording(OrphanRecording orphan) => _run(() async {
    await ref.read(recordingRecoveryProvider).archive(orphan);
    ref.invalidate(meetingLibraryProvider);
    _message('录音已归档到会议库。');
  });

  Future<void> _confirmDeleteRecording(OrphanRecording orphan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('永久删除这个录音？'),
        content: const Text('此操作无法撤销。建议先归档，确认不需要后再删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      await ref.read(recordingRecoveryProvider).discard(orphan);
      _message('未归档录音已永久删除。');
    });
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static LiveTranscriptLine _lineFromItem(LiveTranscriptItem item) =>
      LiveTranscriptLine(
        time: item.start ?? Duration.zero,
        text: item.text,
        isFinal: item.isFinal,
        itemId: item.itemId,
      );

  static Future<void> _openAsset(String path) async {
    if (Platform.isMacOS) await Process.run('open', [path]);
    if (Platform.isWindows) await Process.run('cmd', ['/c', 'start', '', path]);
  }

  static Future<void> _revealAsset(String path) async {
    if (Platform.isMacOS) await Process.run('open', ['-R', path]);
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,$path']);
    }
  }
}

class _PreparationPanel extends StatelessWidget {
  const _PreparationPanel({
    required this.template,
    required this.realtime,
    required this.liveRequested,
    required this.realtimeSupported,
    required this.orphanRecordings,
    required this.isRecordingRecoveryBusy,
    required this.onTemplateChanged,
    required this.onLiveChanged,
    required this.onArchiveRecording,
    required this.onDeleteRecording,
    required this.onDeferRecovery,
    required this.onStart,
    required this.recentMeetings,
    required this.onRecentMeetingTap,
  });

  final NoteTemplate template;
  final RealtimeServiceConfig? realtime;
  final bool liveRequested;
  final bool realtimeSupported;
  final List<OrphanRecording> orphanRecordings;
  final bool Function(OrphanRecording) isRecordingRecoveryBusy;
  final ValueChanged<NoteTemplate> onTemplateChanged;
  final ValueChanged<bool> onLiveChanged;
  final ValueChanged<OrphanRecording> onArchiveRecording;
  final ValueChanged<OrphanRecording> onDeleteRecording;
  final VoidCallback onDeferRecovery;
  final VoidCallback onStart;
  final List<MeetingAssetBundle> recentMeetings;
  final ValueChanged<String> onRecentMeetingTap;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mic_none, size: 68),
            const SizedBox(height: 16),
            Text(
              '准备记录下一场会议',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<NoteTemplate>(
              initialValue: template,
              decoration: const InputDecoration(labelText: '纪要模板'),
              items: NoteTemplate.builtins
                  .map(
                    (item) =>
                        DropdownMenuItem(value: item, child: Text(item.name)),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onTemplateChanged(value);
              },
            ),
            const SizedBox(height: 14),
            if (orphanRecordings.isNotEmpty) ...[
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '发现 ${orphanRecordings.length} 个待恢复录音',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('它们不会被自动上传或创建会议，请逐个选择如何处理。'),
                      const SizedBox(height: 10),
                      for (final orphan in orphanRecordings)
                        Card.outlined(
                          child: Column(
                            children: [
                              ListTile(
                                leading: isRecordingRecoveryBusy(orphan)
                                    ? const SizedBox.square(
                                        dimension: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.audio_file_outlined),
                                title: Text(
                                  orphan.path
                                      .split(Platform.pathSeparator)
                                      .last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${(orphan.byteLength / 1024 / 1024).toStringAsFixed(1)} MB · ${orphan.modifiedAt.toLocal()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                child: OverflowBar(
                                  alignment: MainAxisAlignment.end,
                                  spacing: 6,
                                  children: [
                                    TextButton(
                                      onPressed: isRecordingRecoveryBusy(orphan)
                                          ? null
                                          : () => onDeleteRecording(orphan),
                                      child: const Text('删除文件'),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: isRecordingRecoveryBusy(orphan)
                                          ? null
                                          : () => onArchiveRecording(orphan),
                                      child: const Text('归档到会议库'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onDeferRecovery,
                          child: const Text('稍后处理'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            Card(
              child: SwitchListTile(
                value: liveRequested,
                onChanged: realtimeSupported ? onLiveChanged : null,
                secondary: const Icon(Icons.cloud_outlined),
                title: const Text('会议中显示实时文字'),
                subtitle: Text(
                  !realtimeSupported
                      ? '当前版本仅在 macOS 提供实时 PCM；本平台仍可录音后转写。'
                      : realtime?.canStream == true
                      ? '实时服务已配置；本地录音始终独立保存。'
                      : '尚未完成实时服务配置，仍可只录音。',
                ),
              ),
            ),
            if (liveRequested)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 6, 12, 16),
                child: Text('开启后，会议音频片段会在录音过程中持续发送给你配置的服务商。'),
              ),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('开始录音'),
              ),
            ),
            if (recentMeetings.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('最近会议', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final bundle in recentMeetings)
                _RecentMeetingTile(
                  bundle: bundle,
                  onTap: () => onRecentMeetingTap(bundle.meeting.id),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// How many of the most recent meetings the recording-prep "recent meetings"
/// section shows. The library provider is already ordered by `startedAt`
/// descending, so the first N entries are the most recent.
const int kRecentMeetingsLimit = 5;

class _RecentMeetingTile extends StatelessWidget {
  const _RecentMeetingTile({required this.bundle, required this.onTap});

  final MeetingAssetBundle bundle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meeting = bundle.meeting;
    final note = bundle.note;
    final (label, success) = recentMeetingAssetStatus(bundle);
    final scheme = Theme.of(context).colorScheme;
    final chipColors = success
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.surfaceContainerHighest, scheme.onSurface);
    final started = meeting.startedAt.toLocal();
    final date =
        '${started.month}月${started.day}日 '
        '${_twoDigits(started.hour)}:${_twoDigits(started.minute)}';
    return Card.outlined(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.meeting_room_outlined),
        title: Text(
          meetingDisplayTitle(meeting, note),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(date),
        trailing: Semantics(
          label: '状态：$label',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipColors.$1,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: chipColors.$2),
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Classifies a meeting's most advanced asset for the "recent meetings" list.
/// Doc-level truth: a saved recording is not a generated transcript or note, so
/// the status reflects whatever real asset actually exists (note > transcript >
/// recording > none). Returns `(label, isReady)` where `isReady` selects the
/// success chip tone.
(String, bool) recentMeetingAssetStatus(MeetingAssetBundle bundle) {
  if (bundle.note != null) return ('纪要就绪', true);
  if (bundle.transcript != null) return ('转写就绪', true);
  if (bundle.recording != null) return ('录音已保存', false);
  return ('新会议', false);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _LiveStatusChip extends StatelessWidget {
  const _LiveStatusChip({required this.phase});
  final LiveTranscriptPhase phase;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      phase == LiveTranscriptPhase.streaming
          ? Icons.cloud_done_outlined
          : Icons.cloud_off_outlined,
      size: 18,
    ),
    label: Text(_liveLabel(phase)),
  );
}

class _TransitionPanel extends StatelessWidget {
  const _TransitionPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 58),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        const CircularProgressIndicator(),
      ],
    ),
  );
}

class _FailurePanel extends StatelessWidget {
  const _FailurePanel({required this.message, required this.onReset});
  final String message;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 58,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text('录音遇到问题', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: onReset, child: const Text('返回录音准备')),
        ],
      ),
    ),
  );
}

String _liveLabel(LiveTranscriptPhase phase) => switch (phase) {
  LiveTranscriptPhase.disabled => '未开启实时转写',
  LiveTranscriptPhase.connecting => '正在连接实时转写…',
  LiveTranscriptPhase.streaming => '实时转写已连接',
  LiveTranscriptPhase.reconnecting => '正在重新连接实时转写…',
  LiveTranscriptPhase.degraded => '实时转写已中断',
  LiveTranscriptPhase.closing => '正在整理实时文字…',
  LiveTranscriptPhase.completed => '实时转写已完成',
  LiveTranscriptPhase.failed => '实时转写不可用',
};

String? _liveDegradedMessage(LiveTranscriptPhase phase) => switch (phase) {
  LiveTranscriptPhase.reconnecting ||
  LiveTranscriptPhase.degraded => '实时转写已中断，录音仍在继续',
  LiveTranscriptPhase.failed => '实时转写不可用，录音仍在继续',
  _ => null,
};
