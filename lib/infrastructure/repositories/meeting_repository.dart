import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/meeting_record.dart';
import '../../domain/models/note_template.dart';
import '../../domain/models/recording_asset.dart';
import '../database/app_database.dart' as db;

abstract interface class MeetingRepository {
  Future<MeetingRecord> create(MeetingDraft draft);
  Future<void> updateCaptureMetadata(
    String id, {
    required NoteTemplate template,
    required List<Duration> highlights,
  });
  Future<void> markRecorded(String id, RecordingAsset asset);
  Future<List<MeetingRecord>> list({String query = ''});
  Future<List<MeetingRecord>> listTrash();
  Future<MeetingRecord?> load(String id);
  Future<void> moveToTrash(String id);
  Future<void> restore(String id);
  Future<void> permanentlyDelete(String id);
  Future<void> deleteDraft(String id);
}

class LocalMeetingRepository implements MeetingRepository {
  const LocalMeetingRepository(this.database);

  final db.AppDatabase database;

  @override
  Future<MeetingRecord> create(MeetingDraft draft) async {
    if (draft.id.trim().isEmpty) {
      throw ArgumentError.value(draft.id, 'draft.id', 'must not be empty');
    }
    final now = DateTime.now();
    await database
        .into(database.meetings)
        .insert(
          db.MeetingsCompanion.insert(
            id: draft.id,
            startedAt: draft.startedAt,
            durationMs: 0,
            templateJson: jsonEncode(draft.templateSnapshot.toJson()),
            highlightsJson: jsonEncode(
              draft.highlights.map((value) => value.inMilliseconds).toList(),
            ),
            status: MeetingStatus.recording.name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return MeetingRecord(
      id: draft.id,
      startedAt: draft.startedAt,
      duration: Duration.zero,
      templateSnapshot: draft.templateSnapshot,
      highlights: List.unmodifiable(draft.highlights),
      status: MeetingStatus.recording,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> updateCaptureMetadata(
    String id, {
    required NoteTemplate template,
    required List<Duration> highlights,
  }) async {
    final now = DateTime.now();
    final changed =
        await (database.update(database.meetings)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.status.equals(MeetingStatus.recording.name)))
            .write(
              db.MeetingsCompanion(
                templateJson: Value(jsonEncode(template.toJson())),
                highlightsJson: Value(
                  jsonEncode(
                    highlights
                        .map((value) => value.inMilliseconds)
                        .toList(growable: false),
                  ),
                ),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) {
      throw StateError('Capture metadata requires an active meeting draft.');
    }
  }

  @override
  Future<void> markRecorded(String id, RecordingAsset asset) async {
    if (asset.meetingId != id) {
      throw ArgumentError('Recording asset belongs to another meeting.');
    }
    await database.transaction(() async {
      final persistedAsset =
          await (database.select(database.recordingAssets)
                ..where((row) => row.id.equals(asset.id))
                ..where((row) => row.meetingId.equals(id)))
              .getSingleOrNull();
      if (persistedAsset == null) {
        throw StateError(
          'Recording asset must be persisted before the meeting.',
        );
      }
      final changed =
          await (database.update(database.meetings)
                ..where((row) => row.id.equals(id))
                ..where(
                  (row) => row.status.equals(MeetingStatus.recording.name),
                ))
              .write(
                db.MeetingsCompanion(
                  endedAt: Value(asset.finalizedAt),
                  durationMs: Value(asset.duration.inMilliseconds),
                  status: Value(MeetingStatus.recorded.name),
                  updatedAt: Value(DateTime.now()),
                ),
              );
      if (changed != 1) {
        throw StateError('Only a recording meeting can be marked recorded.');
      }
    });
  }

  @override
  Future<List<MeetingRecord>> list({String query = ''}) async {
    final statement = database.select(database.meetings)
      ..where((row) => row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.desc(row.startedAt)]);
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final pattern = '%${_escapeLike(trimmed)}%';
      final matchingNotes =
          await (database.select(database.notes)..where(
                (row) =>
                    row.meetingId.isNotNull() &
                    (row.title.like(pattern, escapeChar: r'\') |
                        row.searchText.like(pattern, escapeChar: r'\')),
              ))
              .get();
      final meetingIds = matchingNotes
          .map((note) => note.meetingId)
          .whereType<String>()
          .toSet();
      statement.where(
        (row) =>
            row.templateJson.like(pattern, escapeChar: r'\') |
            row.id.isIn(meetingIds),
      );
    }
    return Future.wait((await statement.get()).map(_fromRow));
  }

  @override
  Future<List<MeetingRecord>> listTrash() async {
    final rows =
        await (database.select(database.meetings)
              ..where((row) => row.deletedAt.isNotNull())
              ..orderBy([(row) => OrderingTerm.desc(row.deletedAt)]))
            .get();
    return Future.wait(rows.map(_fromRow));
  }

  @override
  Future<MeetingRecord?> load(String id) async {
    final row = await (database.select(
      database.meetings,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<void> moveToTrash(String id) async {
    final now = DateTime.now();
    await database.transaction(() async {
      final changed =
          await (database.update(database.meetings)
                ..where((row) => row.id.equals(id))
                ..where((row) => row.deletedAt.isNull())
                ..where(
                  (row) =>
                      row.status.equals(MeetingStatus.recording.name).not(),
                ))
              .write(
                db.MeetingsCompanion(
                  status: Value(MeetingStatus.trashed.name),
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) {
        throw StateError('正在录音的会议不能删除；请先结束并保存录音。');
      }
      await (database.update(
        database.recordingAssets,
      )..where((row) => row.meetingId.equals(id))).write(
        db.RecordingAssetsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await (database.update(
        database.transcripts,
      )..where((row) => row.meetingId.equals(id))).write(
        db.TranscriptsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await (database.update(
        database.notes,
      )..where((row) => row.meetingId.equals(id))).write(
        db.NotesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  @override
  Future<void> restore(String id) async {
    final now = DateTime.now();
    await database.transaction(() async {
      final noteIdCount = database.notes.id.count();
      final noteCount =
          await (database.selectOnly(database.notes)
                ..addColumns([noteIdCount])
                ..where(database.notes.meetingId.equals(id)))
              .map((row) => row.read(noteIdCount) ?? 0)
              .getSingle();
      final restoredStatus = noteCount > 0
          ? MeetingStatus.archived
          : MeetingStatus.recorded;
      final changed =
          await (database.update(database.meetings)
                ..where((row) => row.id.equals(id))
                ..where((row) => row.deletedAt.isNotNull()))
              .write(
                db.MeetingsCompanion(
                  status: Value(restoredStatus.name),
                  deletedAt: const Value(null),
                  updatedAt: Value(now),
                ),
              );
      if (changed != 1) throw StateError('Meeting is not in trash.');
      await (database.update(
        database.recordingAssets,
      )..where((row) => row.meetingId.equals(id))).write(
        db.RecordingAssetsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (database.update(
        database.transcripts,
      )..where((row) => row.meetingId.equals(id))).write(
        db.TranscriptsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (database.update(
        database.notes,
      )..where((row) => row.meetingId.equals(id))).write(
        db.NotesCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
      );
    });
  }

  @override
  Future<void> permanentlyDelete(String id) async {
    await database.transaction(() async {
      await (database.delete(
        database.notes,
      )..where((row) => row.meetingId.equals(id))).go();
      await (database.delete(
        database.processingJobs,
      )..where((row) => row.meetingId.equals(id))).go();
      await (database.delete(database.transcriptSegments)..where(
            (segment) => segment.transcriptId.isInQuery(
              database.selectOnly(database.transcripts)
                ..addColumns([database.transcripts.id])
                ..where(database.transcripts.meetingId.equals(id)),
            ),
          ))
          .go();
      await (database.delete(
        database.transcripts,
      )..where((row) => row.meetingId.equals(id))).go();
      await (database.delete(
        database.recordingAssets,
      )..where((row) => row.meetingId.equals(id))).go();
      await (database.delete(
        database.meetings,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<void> deleteDraft(String id) async {
    final changed =
        await (database.delete(database.meetings)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.status.equals(MeetingStatus.recording.name)))
            .go();
    if (changed != 1) {
      throw StateError('Only a recording draft can be deleted.');
    }
  }

  Future<MeetingRecord> _fromRow(db.Meeting row) async {
    final template = NoteTemplate.fromJson(
      jsonDecode(row.templateJson) as Map<String, Object?>,
    );
    final highlights = (jsonDecode(row.highlightsJson) as List<Object?>)
        .whereType<int>()
        .map((value) => Duration(milliseconds: value))
        .toList(growable: false);
    return MeetingRecord(
      id: row.id,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      duration: Duration(milliseconds: row.durationMs),
      templateSnapshot: template,
      highlights: highlights,
      status: MeetingStatus.values.byName(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static String _escapeLike(String source) => source
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
