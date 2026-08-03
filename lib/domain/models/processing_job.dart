import 'dart:convert';

import 'note_template.dart';

enum ProcessingStage {
  saving,
  transcribing,
  summarizing,
  persisting,
  done,
  failed,
}

enum JobType { transcriptRepair, transcriptFull, noteSummary }

/// Durable queue state for the redesigned, independent post-processing jobs.
///
/// [ProcessingStage] remains unchanged for the legacy processing pipeline. The
/// new queue stores this value in [ProcessingJob.checkpoint], so adopting the
/// queue does not require another database migration.
enum PostProcessingStage {
  queued,
  preparing,
  uploading,
  processing,
  persisting,
  done,
  failed,
  cancelled,
}

class ProcessingJob {
  const ProcessingJob({
    required this.id,
    required this.audioPath,
    required this.template,
    required this.startedAt,
    required this.duration,
    required this.highlights,
    required this.stage,
    required this.updatedAt,
    this.transcriptPath,
    this.noteId,
    this.lastSuccessfulStage,
    this.failureCode,
    this.failureMessage,
    this.retryCount = 0,
    this.meetingId,
    this.jobType,
    this.checkpoint = const {},
  });

  final String id;
  final String audioPath;
  final NoteTemplate template;
  final DateTime startedAt;
  final Duration duration;
  final List<Duration> highlights;
  final ProcessingStage stage;
  final DateTime updatedAt;
  final String? transcriptPath;
  final String? noteId;
  final ProcessingStage? lastSuccessfulStage;
  final String? failureCode;
  final String? failureMessage;
  final int retryCount;
  final String? meetingId;
  final JobType? jobType;
  final Map<String, Object?> checkpoint;

  PostProcessingStage? get postProcessingStage {
    final name = checkpoint['postProcessingStage'];
    if (name is! String) return null;
    for (final value in PostProcessingStage.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  bool get isRecoverable =>
      stage != ProcessingStage.done &&
      postProcessingStage != PostProcessingStage.cancelled;

  ProcessingJob copyWith({
    ProcessingStage? stage,
    ProcessingStage? lastSuccessfulStage,
    DateTime? updatedAt,
    String? transcriptPath,
    String? noteId,
    String? failureCode,
    String? failureMessage,
    int? retryCount,
    bool clearFailure = false,
    String? meetingId,
    JobType? jobType,
    Map<String, Object?>? checkpoint,
  }) => ProcessingJob(
    id: id,
    audioPath: audioPath,
    template: template,
    startedAt: startedAt,
    duration: duration,
    highlights: highlights,
    stage: stage ?? this.stage,
    updatedAt: updatedAt ?? this.updatedAt,
    transcriptPath: transcriptPath ?? this.transcriptPath,
    noteId: noteId ?? this.noteId,
    lastSuccessfulStage: lastSuccessfulStage ?? this.lastSuccessfulStage,
    failureCode: clearFailure ? null : failureCode ?? this.failureCode,
    failureMessage: clearFailure ? null : failureMessage ?? this.failureMessage,
    retryCount: retryCount ?? this.retryCount,
    meetingId: meetingId ?? this.meetingId,
    jobType: jobType ?? this.jobType,
    checkpoint: checkpoint ?? this.checkpoint,
  );

  String get templateJson => jsonEncode(template.toJson());
  String get highlightsJson =>
      jsonEncode(highlights.map((item) => item.inMilliseconds).toList());
  String get checkpointJson => jsonEncode(checkpoint);
}
