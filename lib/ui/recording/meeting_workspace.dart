import 'package:flutter/material.dart';

import 'live_transcript_panel.dart';

class MeetingWorkspace extends StatelessWidget {
  const MeetingWorkspace({
    required this.elapsed,
    required this.systemLevel,
    required this.microphoneLevel,
    required this.systemAudioAvailable,
    required this.microphoneAvailable,
    required this.isPaused,
    required this.transitioning,
    required this.highlightCount,
    required this.connectionLabel,
    required this.transcriptLines,
    required this.onPauseResume,
    required this.onStop,
    required this.onHighlight,
    this.degradationReason,
    this.liveDegradedMessage,
    super.key,
  });

  final Duration elapsed;
  final double systemLevel;
  final double microphoneLevel;
  final bool systemAudioAvailable;
  final bool microphoneAvailable;
  final bool isPaused;
  final bool transitioning;
  final int highlightCount;
  final String connectionLabel;
  final List<LiveTranscriptLine> transcriptLines;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final VoidCallback onHighlight;
  final String? degradationReason;
  final String? liveDegradedMessage;

  @override
  Widget build(BuildContext context) {
    final controls = _RecordingControls(
      elapsed: elapsed,
      systemLevel: systemLevel,
      microphoneLevel: microphoneLevel,
      systemAudioAvailable: systemAudioAvailable,
      microphoneAvailable: microphoneAvailable,
      isPaused: isPaused,
      transitioning: transitioning,
      highlightCount: highlightCount,
      degradationReason: degradationReason,
      onPauseResume: onPauseResume,
      onStop: onStop,
      onHighlight: onHighlight,
    );
    final transcript = LiveTranscriptPanel(
      lines: transcriptLines,
      connectionLabel: connectionLabel,
      degradedMessage: liveDegradedMessage,
    );
    if (MediaQuery.sizeOf(context).width < 760) {
      return Column(
        children: [
          Expanded(child: transcript),
          controls,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 310, child: controls),
        const SizedBox(width: 16),
        Expanded(child: transcript),
      ],
    );
  }
}

class _RecordingControls extends StatelessWidget {
  const _RecordingControls({
    required this.elapsed,
    required this.systemLevel,
    required this.microphoneLevel,
    required this.systemAudioAvailable,
    required this.microphoneAvailable,
    required this.isPaused,
    required this.transitioning,
    required this.highlightCount,
    required this.degradationReason,
    required this.onPauseResume,
    required this.onStop,
    required this.onHighlight,
  });

  final Duration elapsed;
  final double systemLevel;
  final double microphoneLevel;
  final bool systemAudioAvailable;
  final bool microphoneAvailable;
  final bool isPaused;
  final bool transitioning;
  final int highlightCount;
  final String? degradationReason;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;
  final VoidCallback onHighlight;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isPaused ? Icons.pause_circle : Icons.graphic_eq,
            size: 52,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            isPaused ? '录音已暂停' : '正在录音',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            _duration(elapsed),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          _Level(
            label: '系统声音',
            value: systemLevel,
            available: systemAudioAvailable,
          ),
          _Level(
            label: '麦克风',
            value: microphoneLevel,
            available: microphoneAvailable,
          ),
          if (degradationReason != null) ...[
            const SizedBox(height: 8),
            Text(
              degradationReason!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const Spacer(),
          OutlinedButton.icon(
            onPressed: transitioning ? null : onHighlight,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text('标记重点（$highlightCount）'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: transitioning ? null : onPauseResume,
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            label: Text(isPaused ? '继续录音' : '暂停录音'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: transitioning ? null : onStop,
            icon: const Icon(Icons.stop),
            label: const Text('结束录音'),
          ),
        ],
      ),
    ),
  );

  static String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}

class _Level extends StatelessWidget {
  const _Level({
    required this.label,
    required this.value,
    required this.available,
  });

  final String label;
  final double value;
  final bool available;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(child: LinearProgressIndicator(value: value.clamp(0, 1))),
        const SizedBox(width: 8),
        Text(available ? '正常' : '不可用'),
      ],
    ),
  );
}
