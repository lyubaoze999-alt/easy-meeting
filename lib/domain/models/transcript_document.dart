import 'dart:convert';

enum TranscriptKind { realtimeDraft, finalTranscript }

enum TranscriptStatus {
  collecting,
  needsRepair,
  processing,
  ready,
  failed,
  trashed,
}

class TranscriptGap {
  const TranscriptGap({
    required this.start,
    required this.end,
    required this.reason,
  });

  final Duration start;
  final Duration end;
  final String reason;

  Map<String, Object?> toJson() => {
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
    'reason': reason,
  };

  factory TranscriptGap.fromJson(Map<String, Object?> json) => TranscriptGap(
    start: Duration(milliseconds: json['startMs'] as int? ?? 0),
    end: Duration(milliseconds: json['endMs'] as int? ?? 0),
    reason: json['reason'] as String? ?? 'unknown',
  );
}

class TranscriptDocument {
  const TranscriptDocument({
    required this.id,
    required this.meetingId,
    required this.kind,
    required this.status,
    required this.coveredDuration,
    required this.revision,
    required this.createdAt,
    required this.updatedAt,
    this.providerProtocol,
    this.model,
    this.language,
    this.bodyPath,
    this.frozenAt,
    this.deletedAt,
    this.gaps = const [],
  });

  final String id;
  final String meetingId;
  final TranscriptKind kind;
  final TranscriptStatus status;
  final String? providerProtocol;
  final String? model;
  final String? language;
  final Duration coveredDuration;
  final String? bodyPath;
  final int revision;
  final DateTime? frozenAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<TranscriptGap> gaps;
}

class TranscriptDeltaSnapshot {
  const TranscriptDeltaSnapshot({
    required this.transcriptId,
    required this.pendingTextByItem,
    required this.updatedAt,
  });

  final String transcriptId;
  final Map<String, String> pendingTextByItem;
  final DateTime updatedAt;

  String encode() => jsonEncode({
    'transcriptId': transcriptId,
    'pendingTextByItem': pendingTextByItem,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  });

  factory TranscriptDeltaSnapshot.decode(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final pending =
        json['pendingTextByItem'] as Map<String, Object?>? ?? const {};
    return TranscriptDeltaSnapshot(
      transcriptId: json['transcriptId'] as String,
      pendingTextByItem: pending.map(
        (key, value) => MapEntry(key, value as String? ?? ''),
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}
