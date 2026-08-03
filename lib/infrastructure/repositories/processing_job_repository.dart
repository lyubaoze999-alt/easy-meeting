import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/note_template.dart';
import '../../domain/models/processing_job.dart' as model;
import '../database/app_database.dart';

abstract interface class ProcessingJobRepository {
  Future<void> save(model.ProcessingJob job);
  Future<model.ProcessingJob?> load(String id);
  Future<List<model.ProcessingJob>> recoverable();
  Future<void> delete(String id);
}

class LocalProcessingJobRepository implements ProcessingJobRepository {
  const LocalProcessingJobRepository(this.database);
  final AppDatabase database;

  @override
  Future<void> save(model.ProcessingJob job) async {
    await database
        .into(database.processingJobs)
        .insertOnConflictUpdate(
          ProcessingJobsCompanion.insert(
            id: job.id,
            audioPath: job.audioPath,
            templateJson: job.templateJson,
            startedAt: job.startedAt,
            durationMs: job.duration.inMilliseconds,
            highlightsJson: job.highlightsJson,
            stage: job.stage.name,
            transcriptPath: Value(job.transcriptPath),
            noteId: Value(job.noteId),
            lastSuccessfulStage: Value(job.lastSuccessfulStage?.name),
            failureCode: Value(job.failureCode),
            failureMessage: Value(job.failureMessage),
            retryCount: Value(job.retryCount),
            updatedAt: job.updatedAt,
            meetingId: Value(job.meetingId),
            jobType: Value(job.jobType?.name),
            checkpointJson: Value(job.checkpointJson),
          ),
        );
  }

  @override
  Future<model.ProcessingJob?> load(String id) async {
    final row = await (database.select(
      database.processingJobs,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<model.ProcessingJob>> recoverable() async {
    final rows =
        await (database.select(database.processingJobs)
              ..where(
                (table) =>
                    table.stage.isNotIn([model.ProcessingStage.done.name]),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]))
            .get();
    return rows.map(_fromRow).where((job) => job.isRecoverable).toList();
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.processingJobs,
    )..where((table) => table.id.equals(id))).go();
  }

  static model.ProcessingJob _fromRow(ProcessingJob row) {
    final template = NoteTemplate.fromJson(
      jsonDecode(row.templateJson) as Map<String, Object?>,
    );
    final highlights = (jsonDecode(row.highlightsJson) as List<Object?>)
        .whereType<int>()
        .map((value) => Duration(milliseconds: value))
        .toList();
    return model.ProcessingJob(
      id: row.id,
      audioPath: row.audioPath,
      template: template,
      startedAt: row.startedAt,
      duration: Duration(milliseconds: row.durationMs),
      highlights: highlights,
      stage: model.ProcessingStage.values.byName(row.stage),
      updatedAt: row.updatedAt,
      transcriptPath: row.transcriptPath,
      noteId: row.noteId,
      lastSuccessfulStage: row.lastSuccessfulStage == null
          ? null
          : model.ProcessingStage.values.byName(row.lastSuccessfulStage!),
      failureCode: row.failureCode,
      failureMessage: row.failureMessage,
      retryCount: row.retryCount,
      meetingId: row.meetingId,
      jobType: row.jobType == null
          ? null
          : model.JobType.values.byName(row.jobType!),
      checkpoint: row.checkpointJson == null
          ? const {}
          : jsonDecode(row.checkpointJson!) as Map<String, Object?>,
    );
  }
}
