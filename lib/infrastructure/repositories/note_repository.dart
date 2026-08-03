import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/models/meeting_note.dart' as model;
import '../database/app_database.dart';

abstract interface class NoteRepository {
  Future<model.MeetingNote> save(
    model.MeetingNote note, {
    File? audioSource,
    String? transcript,
  });
  Future<List<model.MeetingNote>> list({String query = ''});
  Future<List<model.MeetingNote>> listTrash();
  Future<model.MeetingNote?> load(String id);
  Future<void> moveToTrash(String id);
  Future<void> restore(String id);
  Future<void> permanentlyDelete(String id);
  Future<int> purgeExpired({DateTime? now});
}

class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository(this.database, this.baseDirectory);

  final AppDatabase database;
  final Directory baseDirectory;

  static Future<LocalNoteRepository> open(AppDatabase database) async {
    final support = await getApplicationSupportDirectory();
    final base = Directory(p.join(support.path, 'EasyMeeting', 'Notes'));
    await base.create(recursive: true);
    return LocalNoteRepository(database, base);
  }

  @override
  Future<model.MeetingNote> save(
    model.MeetingNote note, {
    File? audioSource,
    String? transcript,
  }) async {
    final existingRow = await (database.select(
      database.notes,
    )..where((row) => row.id.equals(note.id))).getSingleOrNull();
    final noteDirectory = Directory(p.join(baseDirectory.path, note.id));
    await noteDirectory.create(recursive: true);
    final audioFile = File(p.join(noteDirectory.path, 'audio.wav'));
    final transcriptFile = File(p.join(noteDirectory.path, 'transcript.txt'));
    final bodyFile = File(p.join(noteDirectory.path, 'note.json'));
    final usesIndependentAssets =
        note.meetingId != null && note.transcriptId != null;

    if (!usesIndependentAssets &&
        audioSource != null &&
        audioSource.path != audioFile.path) {
      await audioSource.copy(audioFile.path);
    } else if (!usesIndependentAssets &&
        note.audioPath.isNotEmpty &&
        note.audioPath != audioFile.path) {
      await File(note.audioPath).copy(audioFile.path);
    }
    if (!usesIndependentAssets && transcript != null) {
      await _writeAtomic(transcriptFile, transcript);
    } else if (!usesIndependentAssets &&
        note.transcriptPath.isNotEmpty &&
        note.transcriptPath != transcriptFile.path) {
      await File(note.transcriptPath).copy(transcriptFile.path);
    }

    final archived = usesIndependentAssets
        ? note
        : note.copyWith(
            audioPath: audioFile.path,
            transcriptPath: transcriptFile.path,
          );
    await _writeAtomic(bodyFile, archived.encode());
    final now = DateTime.now();
    try {
      await database.transaction(() async {
        final meetingId = archived.meetingId;
        if (meetingId != null) {
          final meeting = await (database.select(
            database.meetings,
          )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
          if (meeting == null || meeting.deletedAt != null) {
            throw StateError('Meeting does not exist or is trashed.');
          }
        }
        await database
            .into(database.notes)
            .insertOnConflictUpdate(
              NotesCompanion.insert(
                id: archived.id,
                title: archived.title,
                startedAt: archived.startedAt,
                durationMs: archived.duration.inMilliseconds,
                templateId: archived.templateId,
                audioPath: archived.audioPath,
                transcriptPath: archived.transcriptPath,
                bodyPath: bodyFile.path,
                searchText: _searchText(archived),
                deletedAt: Value(archived.deletedAt),
                createdAt: now,
                updatedAt: now,
                meetingId: Value(archived.meetingId),
                transcriptId: Value(archived.transcriptId),
              ),
            );
      });
    } on Object {
      if (existingRow == null && await noteDirectory.exists()) {
        await noteDirectory.delete(recursive: true);
      }
      rethrow;
    }
    return archived;
  }

  @override
  Future<List<model.MeetingNote>> list({String query = ''}) async {
    final statement = database.select(database.notes)
      ..where((table) => table.deletedAt.isNull())
      ..orderBy([(table) => OrderingTerm.desc(table.startedAt)]);
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final escaped = trimmed
          .replaceAll(r'\', r'\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      statement.where(
        (table) =>
            table.title.like('%$escaped%', escapeChar: r'\') |
            table.searchText.like('%$escaped%', escapeChar: r'\'),
      );
    }
    return _decodeRows(await statement.get());
  }

  @override
  Future<List<model.MeetingNote>> listTrash() async {
    final statement = database.select(database.notes)
      ..where((table) => table.deletedAt.isNotNull())
      ..orderBy([(table) => OrderingTerm.desc(table.deletedAt)]);
    return _decodeRows(await statement.get());
  }

  @override
  Future<model.MeetingNote?> load(String id) async {
    final row = await (database.select(
      database.notes,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _decodeRow(row);
  }

  @override
  Future<void> moveToTrash(String id) async {
    final deletedAt = DateTime.now();
    await (database.update(
      database.notes,
    )..where((table) => table.id.equals(id))).write(
      NotesCompanion(deletedAt: Value(deletedAt), updatedAt: Value(deletedAt)),
    );
    await _updateBodyDeletion(id, deletedAt: deletedAt);
  }

  @override
  Future<void> restore(String id) async {
    final now = DateTime.now();
    await (database.update(
      database.notes,
    )..where((table) => table.id.equals(id))).write(
      NotesCompanion(deletedAt: const Value(null), updatedAt: Value(now)),
    );
    await _updateBodyDeletion(id, clear: true);
  }

  @override
  Future<void> permanentlyDelete(String id) async {
    final directory = Directory(p.join(baseDirectory.path, id));
    await database.transaction(() async {
      await (database.delete(
        database.notes,
      )..where((table) => table.id.equals(id))).go();
      if (await directory.exists()) await directory.delete(recursive: true);
    });
  }

  @override
  Future<int> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 30));
    final expired = await (database.select(
      database.notes,
    )..where((table) => table.deletedAt.isSmallerThanValue(cutoff))).get();
    for (final row in expired) {
      await permanentlyDelete(row.id);
    }
    return expired.length;
  }

  Future<void> _updateBodyDeletion(
    String id, {
    DateTime? deletedAt,
    bool clear = false,
  }) async {
    final note = await load(id);
    if (note == null) return;
    final updated = note.copyWith(deletedAt: deletedAt, clearDeletedAt: clear);
    await _writeAtomic(
      File(p.join(baseDirectory.path, id, 'note.json')),
      updated.encode(),
    );
  }

  Future<List<model.MeetingNote>> _decodeRows(List<Note> rows) async {
    final result = <model.MeetingNote>[];
    for (final row in rows) {
      final note = await _decodeRow(row);
      if (note != null) result.add(note);
    }
    return result;
  }

  Future<model.MeetingNote?> _decodeRow(Note row) async {
    final body = File(row.bodyPath);
    if (!await body.exists()) return null;
    return model.MeetingNote.decode(await body.readAsString());
  }

  static Future<void> _writeAtomic(File target, String contents) async {
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  static String _searchText(model.MeetingNote note) => [
    note.title,
    ...note.sections.expand((section) => [section.heading, section.content]),
    ...note.todos.expand(
      (todo) => [todo.text, todo.owner ?? '', todo.dueDate ?? ''],
    ),
  ].join('\n');
}
