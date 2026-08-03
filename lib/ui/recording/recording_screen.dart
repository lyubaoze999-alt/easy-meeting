import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../app_services/providers.dart';
import '../../app_services/meeting_session_controller.dart';
import '../../app_services/processing_pipeline.dart';
import '../../app_services/recording_coordinator.dart';
import '../../domain/models/note_template.dart';
import '../../domain/models/processing_job.dart';

class RecordingScreen extends ConsumerWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(meetingSessionProvider);
    final recording = session.recording;
    final processing = session.processing;
    final notes = ref.watch(notesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('会议纪要')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: switch (session.phase) {
              MeetingSessionPhase.initializing => const _TransitionPanel(
                icon: Icons.sync,
                title: '正在恢复未完成任务',
                message: '检查本地处理检查点，请稍候。',
              ),
              MeetingSessionPhase.ready => _IdlePanel(
                recentNotes: notes.take(3).map((item) => item.title).toList(),
                onStart: () => _run(context, session.startRecording),
              ),
              MeetingSessionPhase.starting => const _TransitionPanel(
                icon: Icons.mic_none,
                title: '正在启动录音',
                message: '正在连接系统声音与麦克风。',
              ),
              MeetingSessionPhase.recording ||
              MeetingSessionPhase.pausing ||
              MeetingSessionPhase.paused ||
              MeetingSessionPhase.resuming ||
              MeetingSessionPhase.stopping => _RecordingPanel(
                coordinator: recording,
                phase: session.phase,
                onPauseResume: () => _run(
                  context,
                  session.phase == MeetingSessionPhase.paused
                      ? session.resumeRecording
                      : session.pauseRecording,
                ),
                onStop: () async {
                  try {
                    await session.stopAndProcess();
                    ref.invalidate(notesProvider);
                  } catch (error) {
                    if (context.mounted) _showError(context, error);
                  }
                },
                onHighlight: session.addHighlight,
                onTemplateChanged: session.selectTemplate,
              ),
              MeetingSessionPhase.processing => _ProcessingPanel(
                pipeline: processing,
                onRetry: null,
                onNext: null,
                onBackground: () => _continueInBackground(context, ref),
              ),
              MeetingSessionPhase.failed => _ProcessingPanel(
                pipeline: processing,
                forceFailed: true,
                errorOverride: session.lastError?.toString(),
                onRetry: processing.currentJob == null
                    ? null
                    : () => _run(context, session.retryProcessing),
                onNext: () async {
                  await session.prepareNextMeeting();
                  ref.invalidate(notesProvider);
                },
                onBackground: () => _continueInBackground(context, ref),
              ),
              MeetingSessionPhase.completed => _ProcessingPanel(
                pipeline: processing,
                onRetry: null,
                onNext: () async {
                  await session.prepareNextMeeting();
                  ref.invalidate(notesProvider);
                },
                onBackground: () => _continueInBackground(context, ref),
              ),
            },
          ),
        ),
      ),
    );
  }

  static Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  static void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$error')));
  }

  static Future<void> _continueInBackground(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final granted = await ref
        .read(appServicesProvider)
        .notifications
        .requestPermission();
    if (!context.mounted) return;
    if (Platform.isMacOS || Platform.isWindows) {
      await windowManager.hide();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted ? '处理将在后台尽力继续，完成后通知你。' : '处理将在后台尽力继续；通知权限未开启。'),
        ),
      );
    }
  }
}

class _IdlePanel extends StatelessWidget {
  const _IdlePanel({required this.recentNotes, required this.onStart});
  final List<String> recentNotes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(Icons.mic_none, size: 72),
      const SizedBox(height: 20),
      Text(
        '准备记录下一场会议',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      const Text('同时记录可用的系统声音与麦克风，结束后自动生成纪要。', textAlign: TextAlign.center),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.fiber_manual_record),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('开始记录'),
        ),
      ),
      if (recentNotes.isNotEmpty) ...[
        const SizedBox(height: 32),
        Text('最近纪要', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: recentNotes
                .map(
                  (title) => ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(title),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ],
  );
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({
    required this.coordinator,
    required this.phase,
    required this.onPauseResume,
    required this.onStop,
    required this.onHighlight,
    required this.onTemplateChanged,
  });
  final RecordingCoordinator coordinator;
  final MeetingSessionPhase phase;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final VoidCallback onHighlight;
  final ValueChanged<NoteTemplate> onTemplateChanged;

  @override
  Widget build(BuildContext context) {
    final paused = phase == MeetingSessionPhase.paused;
    final status = switch (phase) {
      MeetingSessionPhase.pausing => ('正在暂停录音…', Icons.pause_circle),
      MeetingSessionPhase.resuming => ('正在继续录音…', Icons.play_circle),
      MeetingSessionPhase.stopping => ('正在结束并保存录音…', Icons.stop_circle),
      MeetingSessionPhase.paused => ('录音已暂停', Icons.pause_circle),
      _ => ('正在录音', Icons.graphic_eq),
    };
    final transitioning = switch (phase) {
      MeetingSessionPhase.pausing ||
      MeetingSessionPhase.resuming ||
      MeetingSessionPhase.stopping => true,
      _ => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(status.$2, size: 64, color: Theme.of(context).colorScheme.error),
        const SizedBox(height: 12),
        Text(
          status.$1,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          _duration(coordinator.elapsed),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontFeatures: const []),
        ),
        const SizedBox(height: 24),
        _LevelRow(
          label: '系统声音',
          value: coordinator.systemLevel,
          unavailable: !coordinator.systemAudioAvailable,
          silent: coordinator.systemSilent,
        ),
        _LevelRow(
          label: '麦克风',
          value: coordinator.microphoneLevel,
          unavailable: !coordinator.microphoneAvailable,
          silent: coordinator.microphoneSilent,
        ),
        if (coordinator.degradationReason != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              coordinator.degradationReason!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        DropdownButtonFormField<NoteTemplate>(
          initialValue: coordinator.selectedTemplate,
          decoration: const InputDecoration(labelText: '纪要模板'),
          items: NoteTemplate.builtins
              .map(
                (template) => DropdownMenuItem(
                  value: template,
                  child: Text(template.name),
                ),
              )
              .toList(),
          onChanged: transitioning
              ? null
              : (template) {
                  if (template != null) onTemplateChanged(template);
                },
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: transitioning ? null : onHighlight,
          icon: const Icon(Icons.bookmark_add_outlined),
          label: Text('标记重点（${coordinator.highlights.length}）'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: transitioning ? null : onPauseResume,
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                label: Text(paused ? '继续' : '暂停'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: transitioning ? null : onStop,
                icon: const Icon(Icons.stop),
                label: const Text('结束并生成纪要'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.value,
    required this.unavailable,
    required this.silent,
  });
  final String label;
  final double value;
  final bool unavailable;
  final bool silent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 88, child: Text(label)),
        Expanded(child: LinearProgressIndicator(value: value.clamp(0, 1))),
        const SizedBox(width: 10),
        Text(unavailable ? '不可用' : (silent ? '静音' : '正常')),
      ],
    ),
  );
}

class _ProcessingPanel extends StatelessWidget {
  const _ProcessingPanel({
    required this.pipeline,
    required this.onRetry,
    required this.onNext,
    required this.onBackground,
    this.forceFailed = false,
    this.errorOverride,
  });
  final ProcessingPipelinePort pipeline;
  final VoidCallback? onRetry;
  final VoidCallback? onNext;
  final VoidCallback onBackground;
  final bool forceFailed;
  final String? errorOverride;

  @override
  Widget build(BuildContext context) {
    final stage = pipeline.stage;
    if (stage == ProcessingStage.done && pipeline.generatedNote != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 68, color: Colors.green),
          const SizedBox(height: 12),
          Text(
            '纪要已生成',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                pipeline.generatedNote!.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onNext, child: const Text('开始下一场会议')),
        ],
      );
    }
    final failed = forceFailed || stage == ProcessingStage.failed;
    final errorMessage = errorOverride ?? pipeline.errorMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(failed ? Icons.error_outline : Icons.hourglass_top, size: 64),
        const SizedBox(height: 16),
        Text(
          failed ? '处理失败' : _stageName(stage),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (stage == ProcessingStage.transcribing)
          Text(
            '正在转写第 ${pipeline.currentSlice}/${pipeline.totalSlices} 个片段',
            textAlign: TextAlign.center,
          ),
        if (errorMessage != null)
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 20),
        if (!failed) const LinearProgressIndicator(),
        if (!failed) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onBackground,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('在后台继续，完成后通知我'),
          ),
        ],
        if (failed && onRetry != null)
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('从上次成功阶段重试'),
          ),
        if (failed && onNext != null)
          TextButton(onPressed: onNext, child: const Text('放弃并开始下一场')),
      ],
    );
  }

  static String _stageName(ProcessingStage stage) => switch (stage) {
    ProcessingStage.saving => '正在保存音频',
    ProcessingStage.transcribing => '正在语音转写',
    ProcessingStage.summarizing => '正在生成纪要',
    ProcessingStage.persisting => '正在保存纪要',
    ProcessingStage.done => '处理完成',
    ProcessingStage.failed => '处理失败',
  };
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 64),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      const LinearProgressIndicator(),
    ],
  );
}
