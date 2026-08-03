import 'package:flutter/material.dart';

enum SavedTranscriptStatus { processing, ready, needsRepair, missing }

class RecordingSavedPanel extends StatelessWidget {
  const RecordingSavedPanel({
    required this.duration,
    required this.byteLength,
    required this.sourceLabel,
    required this.transcriptStatus,
    required this.onPlay,
    required this.onReveal,
    required this.onNextMeeting,
    this.onGenerateTranscript,
    this.onGenerateNote,
    super.key,
  });

  final Duration duration;
  final int byteLength;
  final String sourceLabel;
  final SavedTranscriptStatus transcriptStatus;
  final VoidCallback onPlay;
  final VoidCallback onReveal;
  final VoidCallback? onGenerateTranscript;
  final VoidCallback? onGenerateNote;
  final VoidCallback onNextMeeting;

  @override
  Widget build(BuildContext context) {
    final transcript = switch (transcriptStatus) {
      SavedTranscriptStatus.processing => ('正在整理实时文字，录音已经可以安全使用', Icons.sync),
      SavedTranscriptStatus.ready => ('正式转写已就绪', Icons.check_circle_outline),
      SavedTranscriptStatus.needsRepair => (
        '转写存在缺口，需要补全',
        Icons.warning_amber_rounded,
      ),
      SavedTranscriptStatus.missing => ('尚未生成正式转写', Icons.notes_outlined),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                Text(
                  '录音已安全保存',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${_duration(duration)} · $sourceLabel · ${_size(byteLength)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('播放'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReveal,
                        icon: const Icon(Icons.folder_open_outlined),
                        label: const Text('在文件夹中显示'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(transcript.$2),
                  title: const Text('转写状态'),
                  subtitle: Text(transcript.$1),
                ),
                FilledButton(
                  onPressed:
                      transcriptStatus == SavedTranscriptStatus.ready ||
                          transcriptStatus == SavedTranscriptStatus.processing
                      ? null
                      : onGenerateTranscript,
                  child: Text(
                    transcriptStatus == SavedTranscriptStatus.needsRepair
                        ? '补全正式转写'
                        : '生成正式转写',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: transcriptStatus == SavedTranscriptStatus.ready
                      ? onGenerateNote
                      : null,
                  child: const Text('生成会议纪要'),
                ),
                if (transcriptStatus != SavedTranscriptStatus.ready)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      '需要先完成正式转写，才能生成会议纪要。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: onNextMeeting,
                  child: const Text('开始下一场会议'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
