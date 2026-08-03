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

  bool get isRecoverable => stage != ProcessingStage.done;

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
  );

  String get templateJson => jsonEncode(template.toJson());
  String get highlightsJson =>
      jsonEncode(highlights.map((item) => item.inMilliseconds).toList());
}
