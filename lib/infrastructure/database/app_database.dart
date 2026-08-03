import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get templateId => text()();
  TextColumn get audioPath => text()();
  TextColumn get transcriptPath => text()();
  TextColumn get bodyPath => text()();
  TextColumn get searchText => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get meetingId => text().nullable().references(
    Meetings,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get transcriptId => text().nullable().references(
    Transcripts,
    #id,
    onDelete: KeyAction.setNull,
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Meetings extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationMs => integer()();
  TextColumn get templateJson => text()();
  TextColumn get highlightsJson => text()();
  TextColumn get status => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RecordingAssets extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get path => text()();
  TextColumn get mimeType => text()();
  IntColumn get sampleRate => integer().nullable()();
  IntColumn get channels => integer().nullable()();
  IntColumn get durationMs => integer()();
  IntColumn get byteLength => integer()();
  TextColumn get sha256 => text().nullable()();
  TextColumn get sourceProfile => text()();
  DateTimeColumn get finalizedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {meetingId},
  ];
}

class Transcripts extends Table {
  TextColumn get id => text()();
  TextColumn get meetingId =>
      text().references(Meetings, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text()();
  TextColumn get status => text()();
  TextColumn get providerProtocol => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get language => text().nullable()();
  IntColumn get coveredDurationMs => integer()();
  TextColumn get bodyPath => text().nullable()();
  IntColumn get revision => integer()();
  TextColumn get gapsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get frozenAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {meetingId, kind, revision},
  ];
}

class TranscriptSegments extends Table {
  TextColumn get id => text()();
  TextColumn get transcriptId =>
      text().references(Transcripts, #id, onDelete: KeyAction.cascade)();
  TextColumn get providerItemId => text()();
  IntColumn get ordinal => integer()();
  IntColumn get startMs => integer()();
  IntColumn get endMs => integer()();
  TextColumn get transcriptText => text().named('text')();
  BoolColumn get isFinal => boolean()();
  TextColumn get source => text()();
  TextColumn get speakerId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {transcriptId, providerItemId},
  ];
}

class ProcessingJobs extends Table {
  TextColumn get id => text()();
  TextColumn get audioPath => text()();
  TextColumn get templateJson => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get highlightsJson => text()();
  TextColumn get stage => text()();
  TextColumn get transcriptPath => text().nullable()();
  TextColumn get noteId => text().nullable()();
  TextColumn get lastSuccessfulStage => text().nullable()();
  TextColumn get failureCode => text().nullable()();
  TextColumn get failureMessage => text().nullable()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get meetingId => text().nullable().references(
    Meetings,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get jobType => text().nullable()();
  TextColumn get checkpointJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Notes,
    Meetings,
    RecordingAssets,
    Transcripts,
    TranscriptSegments,
    ProcessingJobs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  static Future<AppDatabase> open({Directory? baseDirectory}) async {
    final root = baseDirectory ?? await getApplicationSupportDirectory();
    final directory = Directory(p.join(root.path, 'EasyMeeting'));
    await directory.create(recursive: true);
    return AppDatabase(
      NativeDatabase.createInBackground(
        File(p.join(directory.path, 'easy_meeting.sqlite')),
      ),
    );
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('Unsupported database migration: v$from -> v$to');
      }
      await transaction(() async {
        await migrator.createTable(meetings);
        await migrator.createTable(recordingAssets);
        await migrator.createTable(transcripts);
        await migrator.createTable(transcriptSegments);
        await migrator.addColumn(notes, notes.meetingId);
        await migrator.addColumn(notes, notes.transcriptId);
        await migrator.addColumn(processingJobs, processingJobs.meetingId);
        await migrator.addColumn(processingJobs, processingJobs.jobType);
        await migrator.addColumn(processingJobs, processingJobs.checkpointJson);
        await _migrateLegacyNotes();
        await _migrateLegacyProcessingJobs();
        await _createIndexes();
        await _validateMigratedData();
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createIndexes();
    },
  );

  Future<void> _migrateLegacyNotes() async {
    final legacyNotes = await select(notes).get();
    for (final note in legacyNotes) {
      final bodyFile = await _requireLegacyFile(
        note.bodyPath,
        label: 'note body ${note.id}',
      );
      final bodyJson = _decodeJsonObject(
        await bodyFile.readAsString(),
        label: 'note body ${note.id}',
      );
      final meetingId = 'legacy-note-meeting-${note.id}';
      final recordingId = 'legacy-note-recording-${note.id}';
      final transcriptId = note.transcriptPath.isEmpty
          ? null
          : 'legacy-note-transcript-${note.id}';
      final status = note.deletedAt == null ? 'archived' : 'trashed';
      final endedAt = note.startedAt.add(
        Duration(milliseconds: note.durationMs),
      );

      await into(meetings).insert(
        MeetingsCompanion.insert(
          id: meetingId,
          startedAt: note.startedAt,
          endedAt: Value(endedAt),
          durationMs: note.durationMs,
          templateJson: _legacyTemplateJson(note.templateId, bodyJson),
          highlightsJson: jsonEncode(
            bodyJson['highlightsMs'] as List<Object?>? ?? const [],
          ),
          status: status,
          deletedAt: Value(note.deletedAt),
          createdAt: note.createdAt,
          updatedAt: note.updatedAt,
        ),
      );

      if (note.audioPath.isNotEmpty) {
        final audioFile = await _requireLegacyFile(
          note.audioPath,
          label: 'note audio ${note.id}',
        );
        final stat = await audioFile.stat();
        await into(recordingAssets).insert(
          RecordingAssetsCompanion.insert(
            id: recordingId,
            meetingId: meetingId,
            path: note.audioPath,
            mimeType: 'audio/wav',
            durationMs: note.durationMs,
            byteLength: stat.size,
            sourceProfile: 'legacyUnknown',
            finalizedAt: stat.modified,
            deletedAt: Value(note.deletedAt),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
          ),
        );
      }

      if (transcriptId != null) {
        await _requireLegacyFile(
          note.transcriptPath,
          label: 'note transcript ${note.id}',
        );
        await into(transcripts).insert(
          TranscriptsCompanion.insert(
            id: transcriptId,
            meetingId: meetingId,
            kind: 'finalTranscript',
            status: note.deletedAt == null ? 'ready' : 'trashed',
            providerProtocol: const Value('legacyFile'),
            coveredDurationMs: note.durationMs,
            bodyPath: Value(note.transcriptPath),
            revision: 1,
            frozenAt: Value(note.updatedAt),
            deletedAt: Value(note.deletedAt),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
          ),
        );
      }

      await (update(notes)..where((row) => row.id.equals(note.id))).write(
        NotesCompanion(
          meetingId: Value(meetingId),
          transcriptId: Value(transcriptId),
        ),
      );
    }
  }

  Future<void> _migrateLegacyProcessingJobs() async {
    final legacyJobs = await select(processingJobs).get();
    for (final job in legacyJobs) {
      final linkedNote = job.noteId == null
          ? null
          : await (select(
              notes,
            )..where((row) => row.id.equals(job.noteId!))).getSingleOrNull();
      final meetingId = linkedNote?.meetingId ?? 'legacy-job-meeting-${job.id}';
      final existingMeeting = await (select(
        meetings,
      )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
      if (existingMeeting == null) {
        final endedAt = job.startedAt.add(
          Duration(milliseconds: job.durationMs),
        );
        await into(meetings).insert(
          MeetingsCompanion.insert(
            id: meetingId,
            startedAt: job.startedAt,
            endedAt: Value(endedAt),
            durationMs: job.durationMs,
            templateJson: job.templateJson,
            highlightsJson: job.highlightsJson,
            status: 'recorded',
            createdAt: job.updatedAt,
            updatedAt: job.updatedAt,
          ),
        );
      }

      final existingAsset = await (select(
        recordingAssets,
      )..where((row) => row.meetingId.equals(meetingId))).getSingleOrNull();
      if (existingAsset == null) {
        final audioFile = await _requireLegacyFile(
          job.audioPath,
          label: 'processing job audio ${job.id}',
        );
        final stat = await audioFile.stat();
        await into(recordingAssets).insert(
          RecordingAssetsCompanion.insert(
            id: 'legacy-job-recording-${job.id}',
            meetingId: meetingId,
            path: job.audioPath,
            mimeType: 'audio/wav',
            durationMs: job.durationMs,
            byteLength: stat.size,
            sourceProfile: 'legacyUnknown',
            finalizedAt: stat.modified,
            createdAt: job.updatedAt,
            updatedAt: job.updatedAt,
          ),
        );
      }

      String? migratedTranscriptId;
      int? migratedTranscriptRevision;
      if (job.transcriptPath case final transcriptPath?) {
        await _requireLegacyFile(
          transcriptPath,
          label: 'processing job transcript ${job.id}',
        );
        final existingTranscripts =
            await (select(transcripts)
                  ..where((row) => row.meetingId.equals(meetingId))
                  ..orderBy([(row) => OrderingTerm.desc(row.revision)]))
                .get();
        final alreadyReferenced = existingTranscripts.any(
          (transcript) => transcript.bodyPath == transcriptPath,
        );
        if (alreadyReferenced) {
          final referenced = existingTranscripts.firstWhere(
            (transcript) => transcript.bodyPath == transcriptPath,
          );
          migratedTranscriptId = referenced.id;
          migratedTranscriptRevision = referenced.revision;
        } else {
          final revision = existingTranscripts.isEmpty
              ? 1
              : existingTranscripts.first.revision + 1;
          migratedTranscriptId = 'legacy-job-transcript-${job.id}';
          migratedTranscriptRevision = revision;
          await into(transcripts).insert(
            TranscriptsCompanion.insert(
              id: migratedTranscriptId,
              meetingId: meetingId,
              kind: 'finalTranscript',
              status: 'ready',
              providerProtocol: const Value('legacyFile'),
              coveredDurationMs: job.durationMs,
              bodyPath: Value(transcriptPath),
              revision: revision,
              frozenAt: Value(job.updatedAt),
              createdAt: job.updatedAt,
              updatedAt: job.updatedAt,
            ),
          );
        }
      }

      final mapping = _mapLegacyJob(job.stage, job.lastSuccessfulStage);
      final needsReview =
          mapping.needsReview ||
          (mapping.jobType == 'noteSummary' && migratedTranscriptId == null);
      await (update(
        processingJobs,
      )..where((row) => row.id.equals(job.id))).write(
        ProcessingJobsCompanion(
          meetingId: Value(meetingId),
          jobType: Value(mapping.jobType),
          checkpointJson: Value(
            jsonEncode({
              'migratedFromVersion': 1,
              'legacyStage': job.stage,
              'legacyLastSuccessfulStage': job.lastSuccessfulStage,
              'postProcessingStage': needsReview ? 'failed' : 'queued',
              'transcriptId': ?migratedTranscriptId,
              'transcriptRevision': ?migratedTranscriptRevision,
            }),
          ),
          stage: needsReview ? const Value('failed') : const Value('saving'),
          failureCode: needsReview
              ? const Value('migration_review_required')
              : const Value.absent(),
        ),
      );
    }
  }

  Future<void> _validateMigratedData() async {
    final notesWithoutMeetings = await customSelect(
      'SELECT COUNT(*) AS amount FROM notes WHERE meeting_id IS NULL',
    ).getSingle();
    if (notesWithoutMeetings.read<int>('amount') != 0) {
      throw StateError('v1 migration left notes without meetings');
    }
    final jobsWithoutMeetings = await customSelect(
      'SELECT COUNT(*) AS amount FROM processing_jobs WHERE meeting_id IS NULL',
    ).getSingle();
    if (jobsWithoutMeetings.read<int>('amount') != 0) {
      throw StateError('v1 migration left processing jobs without meetings');
    }
    final foreignKeyFailures = await customSelect(
      'PRAGMA foreign_key_check',
    ).get();
    if (foreignKeyFailures.isNotEmpty) {
      throw StateError('v1 migration produced invalid foreign key references');
    }
    for (final note in await select(notes).get()) {
      await _requireLegacyFile(note.bodyPath, label: 'note body ${note.id}');
      if (note.audioPath.isNotEmpty) {
        await _requireLegacyFile(
          note.audioPath,
          label: 'note audio ${note.id}',
        );
      }
      if (note.transcriptPath.isNotEmpty) {
        await _requireLegacyFile(
          note.transcriptPath,
          label: 'note transcript ${note.id}',
        );
      }
    }
    for (final job in await select(processingJobs).get()) {
      await _requireLegacyFile(
        job.audioPath,
        label: 'processing job audio ${job.id}',
      );
      if (job.transcriptPath case final transcriptPath?) {
        await _requireLegacyFile(
          transcriptPath,
          label: 'processing job transcript ${job.id}',
        );
      }
    }
  }

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_notes_started_at ON notes(started_at DESC)',
      'CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON notes(deleted_at)',
      'CREATE INDEX IF NOT EXISTS idx_notes_meeting_id ON notes(meeting_id)',
      'CREATE INDEX IF NOT EXISTS idx_processing_jobs_stage ON processing_jobs(stage)',
      'CREATE INDEX IF NOT EXISTS idx_processing_jobs_meeting_id ON processing_jobs(meeting_id)',
      'CREATE INDEX IF NOT EXISTS idx_processing_jobs_job_type ON processing_jobs(job_type)',
      'CREATE INDEX IF NOT EXISTS idx_meetings_started_at ON meetings(started_at DESC)',
      'CREATE INDEX IF NOT EXISTS idx_meetings_deleted_at ON meetings(deleted_at)',
      'CREATE INDEX IF NOT EXISTS idx_recording_assets_meeting_id ON recording_assets(meeting_id)',
      'CREATE INDEX IF NOT EXISTS idx_transcripts_meeting_id ON transcripts(meeting_id)',
      'CREATE INDEX IF NOT EXISTS idx_transcripts_status ON transcripts(status)',
      'CREATE INDEX IF NOT EXISTS idx_transcript_segments_order ON transcript_segments(transcript_id, start_ms, ordinal)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }
}

Future<File> _requireLegacyFile(String path, {required String label}) async {
  if (path.isEmpty) {
    throw StateError('Missing path for $label');
  }
  final file = File(path);
  if (!await file.exists()) {
    throw StateError('Missing file for $label');
  }
  return file;
}

Map<String, Object?> _decodeJsonObject(String source, {required String label}) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$label is not a JSON object');
  }
  return decoded;
}

String _legacyTemplateJson(String templateId, Map<String, Object?> noteBody) {
  final existing = noteBody['templateSnapshot'];
  if (existing is Map<String, Object?>) return jsonEncode(existing);
  return jsonEncode({
    'id': templateId,
    'name': templateId,
    'instruction': '',
    'isBuiltin': templateId.startsWith('builtin.'),
  });
}

({String? jobType, bool needsReview}) _mapLegacyJob(
  String stage,
  String? lastSuccessfulStage,
) {
  switch (stage) {
    case 'saving':
    case 'transcribing':
      return (jobType: 'transcriptFull', needsReview: false);
    case 'summarizing':
    case 'persisting':
    case 'done':
      return (jobType: 'noteSummary', needsReview: false);
    case 'failed':
      switch (lastSuccessfulStage) {
        case 'saving':
          return (jobType: 'transcriptFull', needsReview: false);
        case 'transcribing':
        case 'summarizing':
        case 'persisting':
          return (jobType: 'noteSummary', needsReview: false);
        default:
          return (jobType: null, needsReview: true);
      }
    default:
      return (jobType: null, needsReview: true);
  }
}
