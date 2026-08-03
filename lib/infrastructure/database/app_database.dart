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

  @override
  Set<Column<Object>> get primaryKey => {id};
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

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes, ProcessingJobs])
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notes_started_at ON notes(started_at DESC)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_notes_deleted_at ON notes(deleted_at)',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_processing_jobs_stage ON processing_jobs(stage)',
      );
    },
  );
}
