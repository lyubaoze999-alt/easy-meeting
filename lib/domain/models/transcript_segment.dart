enum TranscriptSegmentSource { realtime, batchRepair, batchFull }

class TranscriptSegment {
  const TranscriptSegment({
    required this.id,
    required this.transcriptId,
    required this.providerItemId,
    required this.ordinal,
    required this.start,
    required this.end,
    required this.text,
    required this.isFinal,
    required this.source,
    required this.updatedAt,
    this.speakerId,
  }) : assert(ordinal >= 0);

  final String id;
  final String transcriptId;
  final String providerItemId;
  final int ordinal;
  final Duration start;
  final Duration end;
  final String text;
  final bool isFinal;
  final TranscriptSegmentSource source;
  final String? speakerId;
  final DateTime updatedAt;
}
