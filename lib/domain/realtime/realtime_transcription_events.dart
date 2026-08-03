enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  closing,
  closed,
  failed,
}

enum TranscriptGapReason {
  sequenceDiscontinuity,
  sampleDiscontinuity,
  transportUnavailable,
  unfinishedItem,
}

sealed class RealtimeTranscriptEvent {
  const RealtimeTranscriptEvent();
}

final class TranscriptDelta extends RealtimeTranscriptEvent {
  const TranscriptDelta({
    required this.itemId,
    required this.contentIndex,
    required this.delta,
    required this.draftTranscript,
  });

  final String itemId;
  final int contentIndex;
  final String delta;
  final String draftTranscript;
}

final class TranscriptCompleted extends RealtimeTranscriptEvent {
  const TranscriptCompleted({
    required this.itemId,
    required this.contentIndex,
    required this.transcript,
    this.languages = const <String>[],
  });

  final String itemId;
  final int contentIndex;
  final String transcript;
  final List<String> languages;
}

final class TranscriptTurnCommitted extends RealtimeTranscriptEvent {
  const TranscriptTurnCommitted({
    required this.itemId,
    required this.endSample,
    this.previousItemId,
  });

  final String itemId;
  final String? previousItemId;
  final int endSample;
}

final class TranscriptConnectionChanged extends RealtimeTranscriptEvent {
  const TranscriptConnectionChanged(this.state, {this.reasonCode});

  final RealtimeConnectionState state;
  final String? reasonCode;
}

final class TranscriptGapDetected extends RealtimeTranscriptEvent {
  const TranscriptGapDetected({
    required this.reason,
    this.expectedSequence,
    this.receivedSequence,
    this.startSample,
    this.endSample,
    this.itemId,
  });

  final TranscriptGapReason reason;
  final int? expectedSequence;
  final int? receivedSequence;
  final int? startSample;
  final int? endSample;
  final String? itemId;

  int? get missingFrameCount {
    final expected = expectedSequence;
    final received = receivedSequence;
    if (expected == null || received == null || received <= expected) {
      return null;
    }
    return received - expected;
  }
}

final class TranscriptServiceError extends RealtimeTranscriptEvent {
  const TranscriptServiceError({
    required this.code,
    required this.message,
    required this.isRetryable,
  });

  final String code;
  final String message;
  final bool isRetryable;

  @override
  String toString() => 'TranscriptServiceError($code)';
}
