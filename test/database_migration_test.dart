import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show MigrationStrategy, Value;
import 'package:drift/native.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart' as model;
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'easy-meeting-migration-test-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('v1 notes and jobs migrate without moving or rewriting files', () async {
    final fixture = await _createV1Fixture(directory);
    final originalAudio = await fixture.audio.readAsBytes();
    final originalTranscript = await fixture.transcript.readAsString();
    final originalBody = await fixture.body.readAsString();

    final database = AppDatabase(NativeDatabase(fixture.databaseFile));
    final migratedNote = await database.select(database.notes).getSingle();
    final meeting = await database.select(database.meetings).getSingle();
    final recording = await database
        .select(database.recordingAssets)
        .getSingle();
    final transcript = await database.select(database.transcripts).getSingle();
    final job = await database.select(database.processingJobs).getSingle();

    expect(migratedNote.audioPath, fixture.audio.path);
    expect(migratedNote.transcriptPath, fixture.transcript.path);
    expect(migratedNote.bodyPath, fixture.body.path);
    expect(migratedNote.meetingId, meeting.id);
    expect(migratedNote.transcriptId, transcript.id);
    expect(meeting.status, 'archived');
    expect(jsonDecode(meeting.highlightsJson), [9000]);
    expect(recording.path, fixture.audio.path);
    expect(recording.sha256, isNull);
    expect(transcript.bodyPath, fixture.transcript.path);
    expect(transcript.kind, 'finalTranscript');
    expect(transcript.status, 'ready');
    expect(job.meetingId, meeting.id);
    expect(job.jobType, 'noteSummary');
    final checkpoint = jsonDecode(job.checkpointJson!) as Map<String, Object?>;
    expect(checkpoint['migratedFromVersion'], 1);
    expect(checkpoint['postProcessingStage'], 'queued');
    expect(checkpoint['transcriptId'], transcript.id);
    expect(checkpoint['transcriptRevision'], transcript.revision);
    expect(await fixture.audio.readAsBytes(), originalAudio);
    expect(await fixture.transcript.readAsString(), originalTranscript);
    expect(await fixture.body.readAsString(), originalBody);
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
    expect(
      (await database.customSelect('PRAGMA user_version').getSingle())
          .read<int>('user_version'),
      2,
    );
    await database.close();
  });

  test('a missing legacy file rolls the entire v1 migration back', () async {
    final fixture = await _createV1Fixture(
      directory,
      audioPathOverride: '${directory.path}/missing.wav',
      includeJob: false,
    );
    final migrating = AppDatabase(NativeDatabase(fixture.databaseFile));

    await expectLater(
      migrating.select(migrating.meetings).get(),
      throwsA(isA<StateError>()),
    );
    await migrating.close();

    final v1 = _V1FixtureDatabase(NativeDatabase(fixture.databaseFile));
    final version = await v1.customSelect('PRAGMA user_version').getSingle();
    final tables = await v1
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
        )
        .get();
    final noteColumns = await v1.customSelect('PRAGMA table_info(notes)').get();
    expect(version.read<int>('user_version'), 1);
    expect(
      tables.map((row) => row.read<String>('name')),
      isNot(contains('meetings')),
    );
    expect(
      noteColumns.map((row) => row.read<String>('name')),
      isNot(contains('meeting_id')),
    );
    expect(
      (await v1.select(v1.notes).getSingle()).audioPath,
      fixture.audioPath,
    );
    await v1.close();
  });
}

class _V1Fixture {
  const _V1Fixture({
    required this.databaseFile,
    required this.audio,
    required this.audioPath,
    required this.transcript,
    required this.body,
  });

  final File databaseFile;
  final File audio;
  final String audioPath;
  final File transcript;
  final File body;
}

Future<_V1Fixture> _createV1Fixture(
  Directory directory, {
  String? audioPathOverride,
  bool includeJob = true,
}) async {
  final audio = await writePcmWav(directory);
  final transcript = File('${directory.path}/legacy-transcript.txt');
  await transcript.writeAsString('原始转写正文', flush: true);
  final body = File('${directory.path}/legacy-note.json');
  final note = model.MeetingNote(
    id: 'legacy-note',
    title: '历史周会',
    startedAt: DateTime.utc(2026, 7, 31),
    duration: const Duration(minutes: 10),
    audioPath: audioPathOverride ?? audio.path,
    transcriptPath: transcript.path,
    templateId: 'builtin.default',
    sections: const [model.NoteSection(heading: '结论', content: '保持原文')],
    todos: const [],
    highlights: const [Duration(seconds: 9)],
  );
  await body.writeAsString(note.encode(), flush: true);
  final databaseFile = File('${directory.path}/v1.sqlite');
  final v1 = _V1FixtureDatabase(NativeDatabase(databaseFile));
  final now = DateTime.utc(2026, 7, 31, 1);
  await v1
      .into(v1.notes)
      .insert(
        NotesCompanion.insert(
          id: note.id,
          title: note.title,
          startedAt: note.startedAt,
          durationMs: note.duration.inMilliseconds,
          templateId: note.templateId,
          audioPath: note.audioPath,
          transcriptPath: note.transcriptPath,
          bodyPath: body.path,
          searchText: '历史周会 保持原文',
          createdAt: now,
          updatedAt: now,
        ),
      );
  if (includeJob) {
    await v1
        .into(v1.processingJobs)
        .insert(
          ProcessingJobsCompanion.insert(
            id: 'legacy-job',
            audioPath: note.audioPath,
            templateJson: jsonEncode(NoteTemplate.builtins.first.toJson()),
            startedAt: note.startedAt,
            durationMs: note.duration.inMilliseconds,
            highlightsJson: jsonEncode([9000]),
            stage: 'persisting',
            transcriptPath: Value(transcript.path),
            noteId: Value(note.id),
            lastSuccessfulStage: const Value('summarizing'),
            updatedAt: now,
          ),
        );
  }
  await v1.close();
  return _V1Fixture(
    databaseFile: databaseFile,
    audio: audio,
    audioPath: note.audioPath,
    transcript: transcript,
    body: body,
  );
}

class _V1FixtureDatabase extends AppDatabase {
  _V1FixtureDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
        CREATE TABLE notes (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          duration_ms INTEGER NOT NULL,
          template_id TEXT NOT NULL,
          audio_path TEXT NOT NULL,
          transcript_path TEXT NOT NULL,
          body_path TEXT NOT NULL,
          search_text TEXT NOT NULL,
          deleted_at INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE processing_jobs (
          id TEXT NOT NULL PRIMARY KEY,
          audio_path TEXT NOT NULL,
          template_json TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          duration_ms INTEGER NOT NULL,
          highlights_json TEXT NOT NULL,
          stage TEXT NOT NULL,
          transcript_path TEXT,
          note_id TEXT,
          last_successful_stage TEXT,
          failure_code TEXT,
          failure_message TEXT,
          retry_count INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL
        )
      ''');
    },
  );
}
