import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/meeting_asset_lifecycle.dart';
import '../../app_services/providers.dart';
import '../../domain/models/meeting_note.dart';
import '../../domain/models/recording_asset.dart';
import '../../domain/models/transcript_document.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetings = ref.watch(meetingTrashProvider);
    final notes = ref.watch(trashProvider);
    final assets = ref.watch(independentAssetTrashProvider);
    if (meetings.isLoading || notes.isLoading || assets.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (meetings.hasError || notes.hasError || assets.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('回收站')),
        body: Center(
          child: FilledButton.icon(
            onPressed: () {
              ref.read(meetingTrashProvider.notifier).load();
              ref.read(trashProvider.notifier).load();
              ref.read(independentAssetTrashProvider.notifier).load();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('无法读取回收站，重新加载'),
          ),
        ),
      );
    }

    final trashedMeetings = meetings.valueOrNull ?? const [];
    final meetingIds = trashedMeetings.map((item) => item.meeting.id).toSet();
    final independentlyDeletedNotes = (notes.valueOrNull ?? const [])
        .where(
          (note) =>
              note.meetingId == null || !meetingIds.contains(note.meetingId),
        )
        .toList(growable: false);
    final assetValue = assets.valueOrNull;
    final recordings = (assetValue?.recordings ?? const <RecordingAsset>[])
        .where((asset) => !meetingIds.contains(asset.meetingId))
        .toList(growable: false);
    final transcripts =
        (assetValue?.transcripts ?? const <TranscriptDocument>[])
            .where((asset) => !meetingIds.contains(asset.meetingId))
            .toList(growable: false);
    final empty =
        trashedMeetings.isEmpty &&
        independentlyDeletedNotes.isEmpty &&
        recordings.isEmpty &&
        transcripts.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('回收站')),
      body: empty
          ? const Center(child: Text('回收站为空'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final bundle in trashedMeetings)
                  _MeetingTrashCard(bundle: bundle),
                for (final note in independentlyDeletedNotes)
                  _NoteTrashCard(note: note),
                for (final recording in recordings)
                  _RecordingTrashCard(recording: recording),
                for (final transcript in transcripts)
                  _TranscriptTrashCard(transcript: transcript),
              ],
            ),
    );
  }
}

class _RecordingTrashCard extends ConsumerWidget {
  const _RecordingTrashCard({required this.recording});

  final RecordingAsset recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const Icon(Icons.graphic_eq),
      title: const Text('会议录音'),
      subtitle: Text('仅录音 · 约 ${_remainingDays(recording.deletedAt)} 天后自动清理'),
      trailing: Wrap(
        children: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(independentAssetTrashProvider.notifier)
                  .restoreRecording(recording.id);
              ref.invalidate(meetingLibraryProvider);
            },
            child: const Text('恢复'),
          ),
          TextButton(
            onPressed: () => _confirmAssetDelete(
              context,
              title: '永久删除录音？',
              message: '录音文件会立即删除且无法恢复；已有转写和纪要不受影响。',
              delete: () => ref
                  .read(independentAssetTrashProvider.notifier)
                  .deleteRecording(recording.id),
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    ),
  );
}

class _TranscriptTrashCard extends ConsumerWidget {
  const _TranscriptTrashCard({required this.transcript});

  final TranscriptDocument transcript;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const Icon(Icons.subtitles_outlined),
      title: Text('正式转写 v${transcript.revision}'),
      subtitle: Text('仅转写 · 约 ${_remainingDays(transcript.deletedAt)} 天后自动清理'),
      trailing: Wrap(
        children: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(independentAssetTrashProvider.notifier)
                  .restoreTranscript(transcript.id);
              ref.invalidate(meetingLibraryProvider);
            },
            child: const Text('恢复'),
          ),
          TextButton(
            onPressed: () => _confirmAssetDelete(
              context,
              title: '永久删除转写？',
              message: '转写正文会立即删除且无法恢复；录音和已有纪要不受影响。',
              delete: () => ref
                  .read(independentAssetTrashProvider.notifier)
                  .deleteTranscript(transcript.id),
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    ),
  );
}

class _MeetingTrashCard extends ConsumerWidget {
  const _MeetingTrashCard({required this.bundle});

  final TrashedMeetingBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meeting = bundle.meeting;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.meeting_room_outlined),
        title: Text(bundle.note?.title ?? '会议 ${_date(meeting.startedAt)}'),
        subtitle: Text('整场会议 · 约 ${_remainingDays(meeting.deletedAt)} 天后自动清理'),
        trailing: Wrap(
          children: [
            TextButton(
              onPressed: () async {
                await ref
                    .read(meetingTrashProvider.notifier)
                    .restore(meeting.id);
                ref.invalidate(meetingLibraryProvider);
                ref.invalidate(notesProvider);
                ref.invalidate(trashProvider);
                ref.invalidate(independentAssetTrashProvider);
              },
              child: const Text('恢复'),
            ),
            TextButton(
              onPressed: () => _confirmMeetingDelete(context, ref, meeting.id),
              child: const Text('永久删除'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteTrashCard extends ConsumerWidget {
  const _NoteTrashCard({required this.note});

  final MeetingNote note;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(note.title),
      subtitle: Text('仅纪要 · 约 ${_remainingDays(note.deletedAt)} 天后自动清理'),
      trailing: Wrap(
        children: [
          TextButton(
            onPressed: () async {
              await ref.read(trashProvider.notifier).restore(note.id);
              ref.invalidate(meetingLibraryProvider);
              ref.invalidate(notesProvider);
            },
            child: const Text('恢复'),
          ),
          TextButton(
            onPressed: () => _confirmNoteDelete(context, ref, note.id),
            child: const Text('永久删除'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _confirmMeetingDelete(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('永久删除整场会议？'),
      content: const Text('录音、转写和纪要文件都会被删除，且无法恢复。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('永久删除'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(meetingTrashProvider.notifier).permanentlyDelete(id);
    ref.invalidate(trashProvider);
    ref.invalidate(meetingLibraryProvider);
    ref.invalidate(notesProvider);
    ref.invalidate(independentAssetTrashProvider);
  }
}

Future<void> _confirmNoteDelete(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('永久删除这条纪要？'),
      content: const Text('只会永久删除纪要；录音和转写保持不变。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('永久删除'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(trashProvider.notifier).permanentlyDelete(id);
  }
}

Future<void> _confirmAssetDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() delete,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('永久删除'),
        ),
      ],
    ),
  );
  if (confirmed == true) await delete();
}

int _remainingDays(DateTime? deletedAt) => deletedAt == null
    ? 30
    : (30 - DateTime.now().difference(deletedAt).inDays).clamp(0, 30);

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
