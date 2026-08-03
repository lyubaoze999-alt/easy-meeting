import 'package:flutter/material.dart';

import '../../domain/models/meeting_note.dart';
import '../../domain/models/meeting_record.dart';
import '../../domain/models/recording_asset.dart';
import '../../domain/models/transcript_document.dart';
import 'meeting_detail_screen.dart';

typedef MeetingCallback = void Function(MeetingRecord meeting);
typedef RecordingCallback =
    void Function(MeetingRecord meeting, RecordingAsset recording);
typedef RecordingSeekCallback =
    void Function(
      MeetingRecord meeting,
      RecordingAsset recording,
      Duration position,
    );
typedef TranscriptCallback =
    void Function(MeetingRecord meeting, TranscriptDocument transcript);
typedef NoteCallback = void Function(MeetingRecord meeting, MeetingNote note);

class MeetingLibraryItem {
  const MeetingLibraryItem({
    required this.meeting,
    this.recording,
    this.transcript,
    this.note,
    this.transcriptText,
    this.recordingStatus,
    this.noteStatus,
    this.playbackPosition = Duration.zero,
    this.isPlaying = false,
  });

  final MeetingRecord meeting;
  final RecordingAsset? recording;
  final TranscriptDocument? transcript;
  final MeetingNote? note;
  final String? transcriptText;
  final RecordingDisplayStatus? recordingStatus;
  final MeetingNoteDisplayStatus? noteStatus;
  final Duration playbackPosition;
  final bool isPlaying;

  RecordingDisplayStatus get effectiveRecordingStatus {
    if (recording == null &&
        recordingStatus != RecordingDisplayStatus.damaged) {
      return RecordingDisplayStatus.missing;
    }
    return recordingStatus ?? RecordingDisplayStatus.playable;
  }

  MeetingNoteDisplayStatus get effectiveNoteStatus {
    if (note == null && noteStatus == MeetingNoteDisplayStatus.ready) {
      return MeetingNoteDisplayStatus.notGenerated;
    }
    return noteStatus ??
        (note == null
            ? MeetingNoteDisplayStatus.notGenerated
            : MeetingNoteDisplayStatus.ready);
  }
}

class MeetingLibraryScreen extends StatefulWidget {
  const MeetingLibraryScreen({
    required this.items,
    this.onMeetingSelected,
    this.onSearchChanged,
    this.onPlayRecording,
    this.onSeekRecording,
    this.onRevealRecording,
    this.onExportRecording,
    this.onDeleteRecording,
    this.onGenerateTranscript,
    this.onRepairTranscript,
    this.onRetryTranscript,
    this.onRetranscribe,
    this.onDeleteTranscript,
    this.onGenerateNote,
    this.onExportNoteMarkdown,
    this.onDeleteNote,
    this.onDeleteMeeting,
    super.key,
  });

  final List<MeetingLibraryItem> items;
  final MeetingCallback? onMeetingSelected;
  final ValueChanged<String>? onSearchChanged;
  final RecordingCallback? onPlayRecording;
  final RecordingSeekCallback? onSeekRecording;
  final RecordingCallback? onRevealRecording;
  final RecordingCallback? onExportRecording;
  final RecordingCallback? onDeleteRecording;
  final MeetingCallback? onGenerateTranscript;
  final TranscriptCallback? onRepairTranscript;
  final TranscriptCallback? onRetryTranscript;
  final TranscriptCallback? onRetranscribe;
  final TranscriptCallback? onDeleteTranscript;
  final TranscriptCallback? onGenerateNote;
  final NoteCallback? onExportNoteMarkdown;
  final NoteCallback? onDeleteNote;
  final MeetingCallback? onDeleteMeeting;

  @override
  State<MeetingLibraryScreen> createState() => _MeetingLibraryScreenState();
}

class _MeetingLibraryScreenState extends State<MeetingLibraryScreen> {
  String? _selectedMeetingId;

  @override
  void initState() {
    super.initState();
    _selectedMeetingId = widget.items.isEmpty
        ? null
        : widget.items.first.meeting.id;
  }

  @override
  void didUpdateWidget(covariant MeetingLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_itemById(_selectedMeetingId) == null) {
      _selectedMeetingId = widget.items.isEmpty
          ? null
          : widget.items.first.meeting.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final selected = _itemById(_selectedMeetingId);
    final list = _MeetingList(
      items: widget.items,
      selectedMeetingId: wide ? selected?.meeting.id : null,
      onSearchChanged: widget.onSearchChanged,
      onSelected: (item) => _select(context, item, wide: wide),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('会议库')),
      body: widget.items.isEmpty
          ? const _EmptyLibrary()
          : wide
          ? Row(
              children: [
                SizedBox(width: 390, child: list),
                const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? const Center(child: Text('选择一场会议查看详情'))
                      : _detail(selected),
                ),
              ],
            )
          : list,
    );
  }

  MeetingLibraryItem? _itemById(String? id) {
    if (id == null) return null;
    for (final item in widget.items) {
      if (item.meeting.id == id) return item;
    }
    return null;
  }

  void _select(
    BuildContext context,
    MeetingLibraryItem item, {
    required bool wide,
  }) {
    widget.onMeetingSelected?.call(item.meeting);
    if (wide) {
      setState(() => _selectedMeetingId = item.meeting.id);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('会议详情')),
          body: _detail(item),
        ),
      ),
    );
  }

  Widget _detail(MeetingLibraryItem item) {
    final recording = item.recording;
    final transcript = item.transcript;
    final note = item.note;
    return MeetingDetailScreen(
      meeting: item.meeting,
      recording: recording,
      transcript: transcript,
      note: note,
      transcriptText: item.transcriptText,
      recordingStatus: item.effectiveRecordingStatus,
      noteStatus: item.effectiveNoteStatus,
      playbackPosition: item.playbackPosition,
      isPlaying: item.isPlaying,
      onPlayRecording: recording == null || widget.onPlayRecording == null
          ? null
          : () => widget.onPlayRecording!(item.meeting, recording),
      onSeekRecording: recording == null || widget.onSeekRecording == null
          ? null
          : (position) =>
                widget.onSeekRecording!(item.meeting, recording, position),
      onRevealRecording: recording == null || widget.onRevealRecording == null
          ? null
          : () => widget.onRevealRecording!(item.meeting, recording),
      onExportRecording: recording == null || widget.onExportRecording == null
          ? null
          : () => widget.onExportRecording!(item.meeting, recording),
      onDeleteRecording: recording == null || widget.onDeleteRecording == null
          ? null
          : () => widget.onDeleteRecording!(item.meeting, recording),
      onGenerateTranscript: widget.onGenerateTranscript == null
          ? null
          : () => widget.onGenerateTranscript!(item.meeting),
      onRepairTranscript:
          transcript == null || widget.onRepairTranscript == null
          ? null
          : () => widget.onRepairTranscript!(item.meeting, transcript),
      onRetryTranscript: transcript == null || widget.onRetryTranscript == null
          ? null
          : () => widget.onRetryTranscript!(item.meeting, transcript),
      onRetranscribe: transcript == null || widget.onRetranscribe == null
          ? null
          : () => widget.onRetranscribe!(item.meeting, transcript),
      onDeleteTranscript:
          transcript == null || widget.onDeleteTranscript == null
          ? null
          : () => widget.onDeleteTranscript!(item.meeting, transcript),
      onGenerateNote: transcript == null || widget.onGenerateNote == null
          ? null
          : () => widget.onGenerateNote!(item.meeting, transcript),
      onExportNoteMarkdown: note == null || widget.onExportNoteMarkdown == null
          ? null
          : () => widget.onExportNoteMarkdown!(item.meeting, note),
      onDeleteNote: note == null || widget.onDeleteNote == null
          ? null
          : () => widget.onDeleteNote!(item.meeting, note),
      onDeleteMeeting: widget.onDeleteMeeting == null
          ? null
          : () => widget.onDeleteMeeting!(item.meeting),
    );
  }
}

class _MeetingList extends StatelessWidget {
  const _MeetingList({
    required this.items,
    required this.selectedMeetingId,
    required this.onSearchChanged,
    required this.onSelected,
  });

  final List<MeetingLibraryItem> items;
  final String? selectedMeetingId;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<MeetingLibraryItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (onSearchChanged != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: '搜索会议',
              onChanged: onSearchChanged,
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return _MeetingListItem(
                item: item,
                selected: selectedMeetingId == item.meeting.id,
                onTap: () => onSelected(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MeetingListItem extends StatelessWidget {
  const _MeetingListItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final MeetingLibraryItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meeting = item.meeting;
    final recording = item.recording;
    final details = [
      formatDateTime(meeting.startedAt),
      formatDuration(meeting.duration),
      recording == null
          ? '录音来源未知'
          : recordingSourceLabel(recording.sourceProfile),
    ].join(' · ');
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.meeting_room_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meetingDisplayTitle(meeting, item.note),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                details,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _AssetStatus(
                    label: '录音',
                    value: recordingDisplayLabel(item.effectiveRecordingStatus),
                    status: _recordingStatus(item.effectiveRecordingStatus),
                  ),
                  _AssetStatus(
                    label: '转写',
                    value: transcriptDisplayLabel(item.transcript),
                    status: _transcriptStatus(item.transcript),
                  ),
                  _AssetStatus(
                    label: '纪要',
                    value: noteDisplayLabel(item.effectiveNoteStatus),
                    status: _noteStatus(item.effectiveNoteStatus),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AssetTone { neutral, success, warning, error }

class _AssetStatus extends StatelessWidget {
  const _AssetStatus({
    required this.label,
    required this.value,
    required this.status,
  });

  final String label;
  final String value;
  final _AssetTone status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = switch (status) {
      _AssetTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurface),
      _AssetTone.success => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      _AssetTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _AssetTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Semantics(
      label: '$label：$value',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.$1,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label $value',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.$2),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.library_books_outlined, size: 52),
          const SizedBox(height: 12),
          Text('还没有会议', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text('完成录音后，会议及其独立资产会显示在这里。'),
        ],
      ),
    );
  }
}

_AssetTone _recordingStatus(RecordingDisplayStatus status) => switch (status) {
  RecordingDisplayStatus.playable => _AssetTone.success,
  RecordingDisplayStatus.missing => _AssetTone.neutral,
  RecordingDisplayStatus.damaged => _AssetTone.error,
};

_AssetTone _transcriptStatus(TranscriptDocument? transcript) {
  if (transcript == null || transcript.status == TranscriptStatus.trashed) {
    return _AssetTone.neutral;
  }
  return switch (transcript.status) {
    TranscriptStatus.ready => _AssetTone.success,
    TranscriptStatus.collecting ||
    TranscriptStatus.needsRepair ||
    TranscriptStatus.processing => _AssetTone.warning,
    TranscriptStatus.failed => _AssetTone.error,
    TranscriptStatus.trashed => _AssetTone.neutral,
  };
}

_AssetTone _noteStatus(MeetingNoteDisplayStatus status) => switch (status) {
  MeetingNoteDisplayStatus.notGenerated => _AssetTone.neutral,
  MeetingNoteDisplayStatus.processing => _AssetTone.warning,
  MeetingNoteDisplayStatus.ready => _AssetTone.success,
  MeetingNoteDisplayStatus.failed => _AssetTone.error,
};
