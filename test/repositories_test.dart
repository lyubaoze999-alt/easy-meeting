import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/processing_job.dart' as model;
import 'package:easy_meeting/infrastructure/database/app_database.dart';
import 'package:easy_meeting/infrastructure/repositories/note_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/processing_job_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  late AppDatabase database;
  late Directory directory;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp(
      'easy-meeting-repository-test-',
    );
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test(
    'note can be searched, trashed, restored, and permanently removed',
    () async {
      final repository = LocalNoteRepository(
        database,
        Directory('${directory.path}/notes'),
      );
      final audio = await writePcmWav(directory);
      final note = MeetingNote(
        id: 'n1',
        title: '周会',
        startedAt: DateTime.utc(2026, 7, 31),
        duration: const Duration(minutes: 10),
        audioPath: audio.path,
        transcriptPath: '',
        templateId: 'builtin.default',
        sections: const [NoteSection(heading: '结果', content: 'Flutter 四端交付')],
        todos: const [],
        highlights: const [],
      );
      final saved = await repository.save(
        note,
        audioSource: audio,
        transcript: '完整转写',
      );
      expect(await File(saved.audioPath).exists(), isTrue);
      expect((await repository.list(query: '四端')).single.id, 'n1');
      expect(await repository.list(query: '%'), isEmpty);
      expect(await repository.list(query: '_'), isEmpty);

      await repository.moveToTrash('n1');
      expect(await repository.list(), isEmpty);
      expect((await repository.listTrash()).single.deletedAt, isNotNull);
      await repository.restore('n1');
      expect((await repository.list()).single.deletedAt, isNull);

      await repository.permanentlyDelete('n1');
      expect(await repository.load('n1'), isNull);
      expect(await Directory('${directory.path}/notes/n1').exists(), isFalse);
    },
  );

  test(
    'trash purge keeps recent records and removes items older than 30 days',
    () async {
      final repository = LocalNoteRepository(
        database,
        Directory('${directory.path}/notes'),
      );
      final audio = await writePcmWav(directory);
      MeetingNote note(String id) => MeetingNote(
        id: id,
        title: id,
        startedAt: DateTime.utc(2026, 1, 1),
        duration: const Duration(minutes: 1),
        audioPath: audio.path,
        transcriptPath: '',
        templateId: 'builtin.default',
        sections: const [],
        todos: const [],
        highlights: const [],
      );
      await repository.save(note('old'), audioSource: audio, transcript: 'old');
      await repository.save(
        note('recent'),
        audioSource: audio,
        transcript: 'recent',
      );
      await repository.moveToTrash('old');
      await repository.moveToTrash('recent');
      await (database.update(database.notes)
            ..where((row) => row.id.equals('old')))
          .write(NotesCompanion(deletedAt: Value(DateTime.utc(2026, 6, 1))));
      await (database.update(database.notes)
            ..where((row) => row.id.equals('recent')))
          .write(NotesCompanion(deletedAt: Value(DateTime.utc(2026, 7, 15))));

      expect(await repository.purgeExpired(now: DateTime.utc(2026, 7, 31)), 1);
      expect(await repository.load('old'), isNull);
      expect(await repository.load('recent'), isNotNull);
    },
  );

  test(
    'persisting jobs are recoverable after an application restart',
    () async {
      final repository = LocalProcessingJobRepository(database);
      final job = model.ProcessingJob(
        id: 'job-1',
        audioPath: '/audio.wav',
        template: NoteTemplate.builtins.first,
        startedAt: DateTime.utc(2026, 7, 31),
        duration: const Duration(minutes: 5),
        highlights: const [Duration(seconds: 9)],
        stage: model.ProcessingStage.persisting,
        lastSuccessfulStage: model.ProcessingStage.summarizing,
        transcriptPath: '/transcript.txt',
        noteId: 'note-1',
        updatedAt: DateTime.utc(2026, 7, 31, 1),
      );
      await repository.save(job);
      final recovered = await repository.recoverable();
      expect(recovered.single.id, 'job-1');
      expect(recovered.single.stage, model.ProcessingStage.persisting);
      expect(recovered.single.highlights.single, const Duration(seconds: 9));
    },
  );
}
