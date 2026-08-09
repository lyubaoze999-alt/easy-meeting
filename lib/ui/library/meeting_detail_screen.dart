import 'package:flutter/material.dart';

import '../../domain/models/asset_status.dart';
import '../../domain/models/meeting_note.dart';
import '../../domain/models/meeting_record.dart';
import '../../domain/models/recording_asset.dart';
import '../../domain/models/transcript_document.dart';

// Re-export the asset-status enums so existing importers of this screen keep
// compiling; the authoritative definition now lives in the domain layer.
export '../../domain/models/asset_status.dart'
    show RecordingDisplayStatus, MeetingNoteDisplayStatus;

class MeetingDetailScreen extends StatelessWidget {
  const MeetingDetailScreen({
    required this.meeting,
    this.recording,
    this.transcript,
    this.note,
    this.transcriptText,
    this.recordingStatus,
    this.noteStatus,
    this.playbackPosition = Duration.zero,
    this.isPlaying = false,
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

  final MeetingRecord meeting;
  final RecordingAsset? recording;
  final TranscriptDocument? transcript;
  final MeetingNote? note;
  final String? transcriptText;
  final RecordingDisplayStatus? recordingStatus;
  final MeetingNoteDisplayStatus? noteStatus;
  final Duration playbackPosition;
  final bool isPlaying;

  final VoidCallback? onPlayRecording;
  final ValueChanged<Duration>? onSeekRecording;
  final VoidCallback? onRevealRecording;
  final VoidCallback? onExportRecording;
  final VoidCallback? onDeleteRecording;
  final VoidCallback? onGenerateTranscript;
  final VoidCallback? onRepairTranscript;
  final VoidCallback? onRetryTranscript;
  final VoidCallback? onRetranscribe;
  final VoidCallback? onDeleteTranscript;
  final VoidCallback? onGenerateNote;
  final VoidCallback? onExportNoteMarkdown;
  final VoidCallback? onDeleteNote;
  final VoidCallback? onDeleteMeeting;

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MeetingHeader(
            meeting: meeting,
            note: note,
            onDeleteMeeting: onDeleteMeeting == null
                ? null
                : () => _confirmDeleteMeeting(context),
          ),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.graphic_eq), text: '录音'),
              Tab(icon: Icon(Icons.subject_outlined), text: '转写'),
              Tab(icon: Icon(Icons.description_outlined), text: '纪要'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RecordingTab(
                  meeting: meeting,
                  recording: recording,
                  status: effectiveRecordingStatus,
                  playbackPosition: playbackPosition,
                  isPlaying: isPlaying,
                  onPlay: onPlayRecording,
                  onSeek: onSeekRecording,
                  onReveal: onRevealRecording,
                  onExport: onExportRecording,
                  onDelete: onDeleteRecording == null
                      ? null
                      : () => _confirmDeleteRecording(context),
                ),
                _TranscriptTab(
                  meeting: meeting,
                  transcript: transcript,
                  transcriptText: transcriptText,
                  onGenerate: onGenerateTranscript,
                  onRepair: onRepairTranscript,
                  onRetry: onRetryTranscript,
                  onRetranscribe: onRetranscribe,
                  onDelete: onDeleteTranscript == null
                      ? null
                      : () => _confirmDeleteTranscript(context),
                ),
                _NoteTab(
                  note: note,
                  status: effectiveNoteStatus,
                  canGenerate:
                      transcript?.status == TranscriptStatus.ready &&
                      onGenerateNote != null,
                  onGenerate: onGenerateNote,
                  onExportMarkdown: onExportNoteMarkdown,
                  onDelete: onDeleteNote == null
                      ? null
                      : () => _confirmDeleteNote(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteRecording(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除录音？'),
        content: const Text('只会删除录音，不会删除转写和纪要。删除后将失去播放、导出和重新转写能力。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除录音'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteRecording?.call();
  }

  Future<void> _confirmDeleteTranscript(BuildContext context) async {
    final noteCopy = note == null ? '' : '现有纪要不会同步变化。';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除转写？'),
        content: Text('只会删除转写，不会删除录音。$noteCopy'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除转写'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteTranscript?.call();
  }

  Future<void> _confirmDeleteNote(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除纪要？'),
        content: const Text('只会删除纪要，不会删除转写和录音。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除纪要'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteNote?.call();
  }

  Future<void> _confirmDeleteMeeting(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除整场会议？'),
        content: const Text('录音、转写和纪要会一并移入 30 天回收站，期间可以恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('移入回收站'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDeleteMeeting?.call();
  }
}

class _MeetingHeader extends StatelessWidget {
  const _MeetingHeader({
    required this.meeting,
    required this.note,
    required this.onDeleteMeeting,
  });

  final MeetingRecord meeting;
  final MeetingNote? note;
  final VoidCallback? onDeleteMeeting;

  @override
  Widget build(BuildContext context) {
    final details =
        '${formatDateTime(meeting.startedAt)} · '
        '${formatDuration(meeting.duration)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meetingDisplayTitle(meeting, note),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                details,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 520 || onDeleteMeeting == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                if (onDeleteMeeting != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onDeleteMeeting,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('删除整场会议'),
                    ),
                  ),
                ],
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              TextButton.icon(
                onPressed: onDeleteMeeting,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除整场会议'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordingTab extends StatelessWidget {
  const _RecordingTab({
    required this.meeting,
    required this.recording,
    required this.status,
    required this.playbackPosition,
    required this.isPlaying,
    required this.onPlay,
    required this.onSeek,
    required this.onReveal,
    required this.onExport,
    required this.onDelete,
  });

  final MeetingRecord meeting;
  final RecordingAsset? recording;
  final RecordingDisplayStatus status;
  final Duration playbackPosition;
  final bool isPlaying;
  final VoidCallback? onPlay;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onReveal;
  final VoidCallback? onExport;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (status != RecordingDisplayStatus.playable || recording == null) {
      final damaged = status == RecordingDisplayStatus.damaged;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _EmptyAsset(
            icon: damaged
                ? Icons.broken_image_outlined
                : Icons.audio_file_outlined,
            title: damaged ? '录音文件损坏' : '录音文件缺失',
            message: damaged
                ? '当前录音无法安全播放或导出，转写和纪要仍会独立保留。'
                : '未找到可用录音，已有转写和纪要仍会独立保留。',
          ),
          if (recording != null && onDelete != null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除录音'),
              ),
            ),
          ],
        ],
      );
    }

    final duration = recording!.duration > Duration.zero
        ? recording!.duration
        : meeting.duration;
    final maxMilliseconds = duration.inMilliseconds > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;
    final position = playbackPosition.inMilliseconds
        .clamp(0, maxMilliseconds.toInt())
        .toDouble();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton.filled(
                      tooltip: isPlaying ? '暂停' : '播放',
                      onPressed: onPlay,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: position,
                        max: maxMilliseconds,
                        onChanged: onSeek == null
                            ? null
                            : (value) => onSeek!(
                                Duration(milliseconds: value.round()),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatClock(playbackPosition)} / '
                      '${formatClock(duration)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _Metadata(
                      label: '录音来源',
                      value: recordingSourceLabel(recording!.sourceProfile),
                    ),
                    _Metadata(label: '时长', value: formatDuration(duration)),
                    _Metadata(
                      label: '文件大小',
                      value: formatFileSize(recording!.byteLength),
                    ),
                    _Metadata(label: '格式', value: recording!.mimeType),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onReveal,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('在文件夹中显示'),
            ),
            OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('导出录音'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除录音'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TranscriptTab extends StatelessWidget {
  const _TranscriptTab({
    required this.meeting,
    required this.transcript,
    required this.transcriptText,
    required this.onGenerate,
    required this.onRepair,
    required this.onRetry,
    required this.onRetranscribe,
    required this.onDelete,
  });

  final MeetingRecord meeting;
  final TranscriptDocument? transcript;
  final String? transcriptText;
  final VoidCallback? onGenerate;
  final VoidCallback? onRepair;
  final VoidCallback? onRetry;
  final VoidCallback? onRetranscribe;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final status = transcriptDisplayLabel(transcript);
    final action = _actionFor(transcript);
    final text = transcriptText?.trim() ?? '';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '转写状态',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    _StatusChip(
                      label: status,
                      tone: _transcriptTone(transcript),
                    ),
                  ],
                ),
                if (transcript?.status == TranscriptStatus.processing) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('正在生成正式转写，请稍候。'),
                ],
                if (transcript != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _Metadata(
                        label: '完成度',
                        value: _completionLabel(meeting, transcript!),
                      ),
                      _Metadata(
                        label: '语言',
                        value: transcript!.language ?? '未标注',
                      ),
                      _Metadata(
                        label: '生成方式',
                        value: transcript!.kind == TranscriptKind.realtimeDraft
                            ? '实时转写'
                            : '正式转写',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('转写正文', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SelectableText(
                  text.isEmpty ? _emptyTranscriptMessage(transcript) : text,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (action != null)
              FilledButton.icon(
                onPressed: action.$2,
                icon: Icon(action.$3),
                label: Text(action.$1),
              ),
            if (transcript != null)
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除转写'),
              ),
          ],
        ),
      ],
    );
  }

  (String, VoidCallback?, IconData)? _actionFor(TranscriptDocument? document) {
    if (document == null || document.status == TranscriptStatus.trashed) {
      return ('生成正式转写', onGenerate, Icons.auto_awesome_outlined);
    }
    return switch (document.status) {
      TranscriptStatus.collecting => (
        '生成正式转写',
        onRetranscribe,
        Icons.auto_awesome_outlined,
      ),
      TranscriptStatus.needsRepair => ('补全转写', onRepair, Icons.build_outlined),
      TranscriptStatus.processing => null,
      TranscriptStatus.ready => ('重新转写', onRetranscribe, Icons.refresh),
      TranscriptStatus.failed => ('重试转写', onRetry, Icons.refresh),
      TranscriptStatus.trashed => null,
    };
  }

  static String _completionLabel(
    MeetingRecord meeting,
    TranscriptDocument transcript,
  ) {
    if (transcript.status == TranscriptStatus.ready) return '100%';
    final total = meeting.duration.inMilliseconds;
    if (total <= 0) return '0%';
    final ratio = transcript.coveredDuration.inMilliseconds / total;
    return '${(ratio.clamp(0, 1) * 100).round()}%';
  }

  static String _emptyTranscriptMessage(TranscriptDocument? document) {
    if (document == null || document.status == TranscriptStatus.trashed) {
      return '尚未生成转写正文。';
    }
    return switch (document.status) {
      TranscriptStatus.collecting => '实时草稿暂无可显示正文。',
      TranscriptStatus.needsRepair => '现有转写需要补全，暂无可显示正文。',
      TranscriptStatus.processing => '正式转写生成后将在这里显示。',
      TranscriptStatus.ready => '暂无可显示的转写正文。',
      TranscriptStatus.failed => '转写失败，暂无可显示正文。',
      TranscriptStatus.trashed => '尚未生成转写正文。',
    };
  }
}

class _NoteTab extends StatelessWidget {
  const _NoteTab({
    required this.note,
    required this.status,
    required this.canGenerate,
    required this.onGenerate,
    required this.onExportMarkdown,
    required this.onDelete,
  });

  final MeetingNote? note;
  final MeetingNoteDisplayStatus status;
  final bool canGenerate;
  final VoidCallback? onGenerate;
  final VoidCallback? onExportMarkdown;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (status != MeetingNoteDisplayStatus.ready || note == null) {
      final content = switch (status) {
        MeetingNoteDisplayStatus.notGenerated => (
          Icons.description_outlined,
          '尚未生成纪要',
          '完成正式转写后，可以生成会议纪要。',
        ),
        MeetingNoteDisplayStatus.processing => (
          Icons.pending_outlined,
          '纪要处理中',
          '纪要正在生成，完成后会在这里显示。',
        ),
        MeetingNoteDisplayStatus.ready => (
          Icons.description_outlined,
          '纪要不可用',
          '未找到可显示的纪要内容。',
        ),
        MeetingNoteDisplayStatus.failed => (
          Icons.error_outline,
          '纪要生成失败',
          '可以重试生成，录音和转写不会受到影响。',
        ),
      };
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _EmptyAsset(icon: content.$1, title: content.$2, message: content.$3),
          if (status != MeetingNoteDisplayStatus.processing) ...[
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: canGenerate ? onGenerate : null,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  status == MeetingNoteDisplayStatus.failed
                      ? '重试生成纪要'
                      : '生成会议纪要',
                ),
              ),
            ),
          ],
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...note!.sections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (section.isHighlighted) ...[
                          const Icon(Icons.bookmark, size: 18),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            section.heading,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SelectableText(section.content),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (note!.todos.isNotEmpty) ...[
          Text('待办事项', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: note!.todos
                  .map(
                    (todo) => CheckboxListTile(
                      value: todo.done,
                      onChanged: null,
                      title: Text(todo.text),
                      subtitle: _todoSubtitle(todo),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (note!.visuals != null && !note!.visuals!.isEmpty) ...[
          _NoteVisuals(visuals: note!.visuals!),
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onExportMarkdown,
              icon: const Icon(Icons.download_outlined),
              label: const Text('导出 Markdown'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除纪要'),
            ),
          ],
        ),
      ],
    );
  }

  static Widget? _todoSubtitle(TodoItem todo) {
    final parts = [
      if (todo.owner != null) '负责人：${todo.owner}',
      if (todo.dueDate != null) '截止：${todo.dueDate}',
    ];
    return parts.isEmpty ? null : Text(parts.join(' · '));
  }
}

class _NoteVisuals extends StatelessWidget {
  const _NoteVisuals({required this.visuals});

  final NoteVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('图文概览', style: Theme.of(context).textTheme.titleLarge),
            if (visuals.keyNumbers?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: visuals.keyNumbers!
                    .map(
                      (item) =>
                          Chip(label: Text('${item.label}：${item.value}')),
                    )
                    .toList(),
              ),
            ],
            if (visuals.timeline?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Text('时间线', style: Theme.of(context).textTheme.titleMedium),
              ...visuals.timeline!.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Text(item.time),
                  title: Text(item.title),
                  subtitle: item.detail == null ? null : Text(item.detail!),
                ),
              ),
            ],
            if (visuals.mindmap != null) ...[
              const SizedBox(height: 12),
              Text('思维导图', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _MindmapBranch(node: visuals.mindmap!),
            ],
          ],
        ),
      ),
    );
  }
}

class _MindmapBranch extends StatelessWidget {
  const _MindmapBranch({required this.node, this.depth = 0});

  final MindmapNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('${depth == 0 ? '' : '• '}${node.title}'),
          ),
          ...node.children.map(
            (child) => _MindmapBranch(node: child, depth: depth + 1),
          ),
        ],
      ),
    );
  }
}

class _EmptyAsset extends StatelessWidget {
  const _EmptyAsset({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label：$value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

enum _StatusTone { neutral, success, warning, error }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});

  final String label;
  final _StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = switch (tone) {
      _StatusTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurface),
      _StatusTone.success => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      _StatusTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _StatusTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: colors.$2)),
    );
  }
}

_StatusTone _transcriptTone(TranscriptDocument? transcript) {
  if (transcript == null || transcript.status == TranscriptStatus.trashed) {
    return _StatusTone.neutral;
  }
  return switch (transcript.status) {
    TranscriptStatus.ready => _StatusTone.success,
    TranscriptStatus.collecting ||
    TranscriptStatus.needsRepair ||
    TranscriptStatus.processing => _StatusTone.warning,
    TranscriptStatus.failed => _StatusTone.error,
    TranscriptStatus.trashed => _StatusTone.neutral,
  };
}

String meetingDisplayTitle(MeetingRecord meeting, MeetingNote? note) {
  final noteTitle = note?.title.trim();
  if (noteTitle != null && noteTitle.isNotEmpty) return noteTitle;
  final value = meeting.startedAt.toLocal();
  return '${value.month}月${value.day}日 ${_twoDigits(value.hour)}:'
      '${_twoDigits(value.minute)} 会议';
}

String transcriptDisplayLabel(TranscriptDocument? transcript) {
  if (transcript == null || transcript.status == TranscriptStatus.trashed) {
    return '未生成';
  }
  return switch (transcript.status) {
    TranscriptStatus.collecting => '实时草稿',
    TranscriptStatus.needsRepair => '需补全',
    TranscriptStatus.processing => '处理中',
    TranscriptStatus.ready => '已完成',
    TranscriptStatus.failed => '失败',
    TranscriptStatus.trashed => '未生成',
  };
}

String recordingDisplayLabel(RecordingDisplayStatus status) => switch (status) {
  RecordingDisplayStatus.playable => '可播放',
  RecordingDisplayStatus.missing => '缺失',
  RecordingDisplayStatus.damaged => '损坏',
};

String noteDisplayLabel(MeetingNoteDisplayStatus status) => switch (status) {
  MeetingNoteDisplayStatus.notGenerated => '未生成',
  MeetingNoteDisplayStatus.processing => '处理中',
  MeetingNoteDisplayStatus.ready => '已完成',
  MeetingNoteDisplayStatus.failed => '失败',
};

String recordingSourceLabel(AudioCaptureProfile profile) => switch (profile) {
  AudioCaptureProfile.dualSource => '系统声音 + 麦克风',
  AudioCaptureProfile.microphoneOnly => '仅麦克风',
  AudioCaptureProfile.legacyUnknown => '来源未知',
};

String formatDateTime(DateTime source) {
  final value = source.toLocal();
  return '${value.year}年${value.month}月${value.day}日 '
      '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String formatDuration(Duration value) {
  if (value.inHours > 0) {
    final minutes = value.inMinutes.remainder(60);
    return '${value.inHours} 小时 ${minutes == 0 ? '' : '$minutes 分钟'}'.trim();
  }
  if (value.inMinutes > 0) return '${value.inMinutes} 分钟';
  return '${value.inSeconds} 秒';
}

String formatClock(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }
  return '${_twoDigits(minutes)}:${_twoDigits(seconds)}';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
