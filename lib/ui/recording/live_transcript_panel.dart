import 'package:flutter/material.dart';

class LiveTranscriptLine {
  const LiveTranscriptLine({
    required this.time,
    required this.text,
    required this.isFinal,
    required this.itemId,
  });

  final Duration time;
  final String text;
  final bool isFinal;
  final String itemId;
}

class LiveTranscriptPanel extends StatefulWidget {
  const LiveTranscriptPanel({
    required this.lines,
    required this.connectionLabel,
    this.degradedMessage,
    super.key,
  });

  final List<LiveTranscriptLine> lines;
  final String connectionLabel;
  final String? degradedMessage;

  @override
  State<LiveTranscriptPanel> createState() => _LiveTranscriptPanelState();
}

class _LiveTranscriptPanelState extends State<LiveTranscriptPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _followLatest = true;

  @override
  void didUpdateWidget(covariant LiveTranscriptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_followLatest && widget.lines.length != oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.subtitles_outlined),
          title: const Text('实时文字'),
          subtitle: Text(widget.degradedMessage ?? widget.connectionLabel),
          trailing: !_followLatest
              ? TextButton.icon(
                  onPressed: () {
                    setState(() => _followLatest = true);
                    _scrollToLatest();
                  },
                  icon: const Icon(Icons.south, size: 18),
                  label: const Text('回到最新'),
                )
              : null,
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.lines.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '等待声音…\n本地录音会独立保存，不受实时服务影响。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification) {
                      final atBottom =
                          _scrollController.position.extentAfter < 24;
                      if (_followLatest != atBottom) {
                        setState(() => _followLatest = atBottom);
                      }
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.lines.length,
                    itemBuilder: (context, index) {
                      final line = widget.lines[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 52,
                              child: Text(
                                _formatTime(line.time),
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                line.text,
                                style: TextStyle(
                                  color: line.isFinal
                                      ? null
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                  fontStyle: line.isFinal
                                      ? FontStyle.normal
                                      : FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  static String _formatTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
