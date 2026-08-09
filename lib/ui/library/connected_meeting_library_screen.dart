import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/providers.dart';
import '../../domain/models/meeting_note.dart';
import '../../domain/models/processing_job.dart';
import '../../domain/models/recording_asset.dart';
import 'meeting_library_screen.dart';
import 'note_exporter.dart';

class ConnectedMeetingLibraryScreen extends ConsumerWidget {
  const ConnectedMeetingLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(meetingLibraryProvider);
    return state.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('会议库')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('会议库')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => ref.read(meetingLibraryProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
            label: Text('读取失败，重新加载\n$error'),
          ),
        ),
      ),
      data: (bundles) => MeetingLibraryScreen(
        initialMeetingId: ref.watch(selectedMeetingIdProvider),
        items: bundles
            .map(
              (bundle) => MeetingLibraryItem(
                meeting: bundle.meeting,
                recording: bundle.recording,
                transcript: bundle.transcript,
                note: bundle.note,
                transcriptText: bundle.transcriptText,
              ),
            )
            .toList(growable: false),
        onSearchChanged: (query) =>
            ref.read(meetingLibraryProvider.notifier).load(query: query),
        onPlayRecording: (_, recording) =>
            unawaited(_openRecording(context, recording)),
        onRevealRecording: (_, recording) =>
            unawaited(_revealRecording(context, recording)),
        onExportRecording: (_, recording) =>
            unawaited(_exportRecording(context, recording)),
        onDeleteRecording: (_, recording) => unawaited(
          _run(
            context,
            () => ref
                .read(meetingLibraryProvider.notifier)
                .moveRecordingToTrash(recording.id),
          ),
        ),
        onGenerateTranscript: (meeting) =>
            unawaited(_enqueueTranscript(context, ref, meeting.id)),
        onRepairTranscript: (meeting, _) =>
            unawaited(_enqueueTranscript(context, ref, meeting.id)),
        onRetranscribe: (meeting, _) =>
            unawaited(_enqueueTranscript(context, ref, meeting.id)),
        onDeleteTranscript: (_, transcript) => unawaited(
          _run(context, () async {
            await ref
                .read(appServicesProvider)
                .transcripts
                .moveToTrash(transcript.id);
            await ref.read(meetingLibraryProvider.notifier).load();
          }),
        ),
        onGenerateNote: (meeting, transcript) =>
            unawaited(_enqueueSummary(context, ref, meeting.id, transcript.id)),
        onExportNoteMarkdown: (_, note) =>
            unawaited(_exportNote(context, note)),
        onDeleteNote: (_, note) => unawaited(
          _run(context, () async {
            await ref.read(appServicesProvider).notes.moveToTrash(note.id);
            await ref.read(meetingLibraryProvider.notifier).load();
          }),
        ),
        onDeleteMeeting: (meeting) => unawaited(
          _run(
            context,
            () => ref
                .read(meetingLibraryProvider.notifier)
                .moveMeetingToTrash(meeting.id),
          ),
        ),
      ),
    );
  }

  static Future<void> _openRecording(
    BuildContext context,
    RecordingAsset recording,
  ) async {
    if (Platform.isMacOS) {
      await Process.run('open', [recording.path]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', recording.path]);
      return;
    }
    _message(context, '当前移动端内置播放器尚未接入。');
  }

  static Future<void> _revealRecording(
    BuildContext context,
    RecordingAsset recording,
  ) async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', recording.path]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,${recording.path}']);
      return;
    }
    _message(context, '当前平台不支持在文件管理器中定位。');
  }

  static Future<void> _exportRecording(
    BuildContext context,
    RecordingAsset recording,
  ) async {
    final destination = await getSaveLocation(
      suggestedName: 'meeting-${recording.meetingId}.wav',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'WAV', extensions: ['wav']),
      ],
    );
    if (destination == null) return;
    await File(recording.path).copy(destination.path);
    if (context.mounted) _message(context, '录音已导出');
  }

  static Future<void> _exportNote(
    BuildContext context,
    MeetingNote note,
  ) async {
    final destination = await getSaveLocation(
      suggestedName: '${note.title}.md',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Markdown', extensions: ['md']),
      ],
    );
    if (destination == null) return;
    await File(
      destination.path,
    ).writeAsString(NoteExporter.markdown(note), flush: true);
    if (context.mounted) _message(context, '纪要已导出');
  }

  static Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) _message(context, '$error');
    }
  }

  static Future<void> _enqueueTranscript(
    BuildContext context,
    WidgetRef ref,
    String meetingId,
  ) => _run(context, () async {
    final queue = ref.read(postProcessingProvider);
    final job = await queue.enqueueTranscript(meetingId);
    if (context.mounted) _message(context, '正式转写任务已开始。');
    await queue.waitUntilIdle();
    final saved = await ref.read(appServicesProvider).jobs.load(job.id);
    if (saved?.stage == ProcessingStage.failed) {
      throw StateError(saved?.failureMessage ?? '正式转写失败，请重试。');
    }
    await ref.read(meetingLibraryProvider.notifier).load();
    if (context.mounted) _message(context, '正式转写已完成');
  });

  static Future<void> _enqueueSummary(
    BuildContext context,
    WidgetRef ref,
    String meetingId,
    String transcriptId,
  ) => _run(context, () async {
    final queue = ref.read(postProcessingProvider);
    final job = await queue.enqueueSummary(meetingId, transcriptId);
    if (context.mounted) _message(context, '会议纪要生成任务已开始。');
    await queue.waitUntilIdle();
    final saved = await ref.read(appServicesProvider).jobs.load(job.id);
    if (saved?.stage == ProcessingStage.failed) {
      throw StateError(saved?.failureMessage ?? '会议纪要生成失败，请重试。');
    }
    await ref.read(meetingLibraryProvider.notifier).load();
    if (context.mounted) _message(context, '会议纪要已生成');
  });

  static void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
