import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/transcript_document.dart';
import '../../domain/models/transcript_segment.dart';
import '../database/app_database.dart' as db;

abstract interface class TranscriptRepository {
  Future<TranscriptDocument> createRealtimeDraft(String meetingId);
  Future<void> upsertDeltaSnapshot(TranscriptDeltaSnapshot snapshot);
  Future<void> saveCompletedSegment(TranscriptSegment segment);
  Future<TranscriptDocument> freeze(String draftId, {required int revision});
  Future<void> markNeedsRepair(String id, List<TranscriptGap> gaps);
  Future<TranscriptDocument?> finalForMeeting(String meetingId);
  Future<TranscriptDocument?> load(String id);
  Future<List<TranscriptSegment>> segments(String transcriptId);
  Future<List<TranscriptDocument>> listTrash();
  Future<void> moveToTrash(String id);
  Future<void> restore(String id);
  Future<void> permanentlyDelete(String id);
  Future<int> purgeExpired({DateTime? now});
}

/// Optional capability used by the file-transcription worker.
///
/// It is separate from [TranscriptRepository] so realtime-only test fakes and
/// clients do not need to implement batch persistence.
abstract interface class BatchFinalTranscriptRepository {
  Future<TranscriptDocument> saveBatchFinal({
    required String meetingId,
    required String body,
    required int revision,
    required Duration coveredDuration,
    String? providerProtocol,
    String? model,
    String? language,
  });
}

/// Allocates final transcript revisions inside one repository-owned critical
/// section so realtime freeze and file transcription cannot claim the same
/// revision or overwrite each other's body file.
abstract interface class RevisionAllocatingTranscriptRepository {
  Future<TranscriptDocument> freezeNext(String draftId);

  Future<TranscriptDocument> saveBatchFinalNext({
    required String meetingId,
    required String body,
    required Duration coveredDuration,
    String? idempotencyKey,
    String? providerProtocol,
    String? model,
    String? language,
  });
}

class LocalTranscriptRepository
    implements
        TranscriptRepository,
        BatchFinalTranscriptRepository,
        RevisionAllocatingTranscriptRepository {
  LocalTranscriptRepository(this.database, this.baseDirectory);

  final db.AppDatabase database;
  final Directory baseDirectory;
  Future<void> _mutationTail = Future<void>.value();

  static Future<LocalTranscriptRepository> open(db.AppDatabase database) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(support.path, 'EasyMeeting', 'Meetings'),
    );
    await directory.create(recursive: true);
    return LocalTranscriptRepository(database, directory);
  }

  @override
  Future<TranscriptDocument> createRealtimeDraft(String meetingId) async {
    final meeting = await (database.select(
      database.meetings,
    )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
    if (meeting == null) throw StateError('Meeting does not exist.');
    final existing =
        await (database.select(database.transcripts)
              ..where((row) => row.meetingId.equals(meetingId))
              ..where(
                (row) => row.kind.equals(TranscriptKind.realtimeDraft.name),
              )
              ..where((row) => row.revision.equals(0)))
            .getSingleOrNull();
    if (existing != null) return _documentFromRow(existing);

    final now = DateTime.now();
    final id = const Uuid().v4();
    await database
        .into(database.transcripts)
        .insert(
          db.TranscriptsCompanion.insert(
            id: id,
            meetingId: meetingId,
            kind: TranscriptKind.realtimeDraft.name,
            status: TranscriptStatus.collecting.name,
            coveredDurationMs: 0,
            revision: 0,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await load(id))!;
  }

  @override
  Future<void> upsertDeltaSnapshot(TranscriptDeltaSnapshot snapshot) async {
    final transcript = await load(snapshot.transcriptId);
    if (transcript == null || transcript.kind != TranscriptKind.realtimeDraft) {
      throw StateError('Delta snapshots require a realtime draft.');
    }
    final file = File(
      p.join(
        baseDirectory.path,
        transcript.meetingId,
        'transcripts',
        'realtime-draft.json',
      ),
    );
    await file.parent.create(recursive: true);
    await _writeAtomic(file, snapshot.encode());
  }

  @override
  Future<void> saveCompletedSegment(TranscriptSegment segment) async {
    if (!segment.isFinal) {
      throw ArgumentError('Only completed transcript segments are persisted.');
    }
    if (segment.start.isNegative || segment.end < segment.start) {
      throw ArgumentError('Transcript segment timestamps are invalid.');
    }
    await database.transaction(() async {
      final transcript = await (database.select(
        database.transcripts,
      )..where((row) => row.id.equals(segment.transcriptId))).getSingleOrNull();
      if (transcript == null || transcript.deletedAt != null) {
        throw StateError('Transcript does not exist or is trashed.');
      }
      final existing =
          await (database.select(database.transcriptSegments)
                ..where((row) => row.transcriptId.equals(segment.transcriptId))
                ..where(
                  (row) => row.providerItemId.equals(segment.providerItemId),
                ))
              .getSingleOrNull();
      await database
          .into(database.transcriptSegments)
          .insertOnConflictUpdate(
            db.TranscriptSegmentsCompanion.insert(
              id: existing?.id ?? segment.id,
              transcriptId: segment.transcriptId,
              providerItemId: segment.providerItemId,
              ordinal: segment.ordinal,
              startMs: segment.start.inMilliseconds,
              endMs: segment.end.inMilliseconds,
              transcriptText: segment.text,
              isFinal: true,
              source: segment.source.name,
              speakerId: Value(segment.speakerId),
              createdAt: existing?.createdAt ?? segment.updatedAt,
              updatedAt: segment.updatedAt,
            ),
          );
      final rows =
          await (database.select(database.transcriptSegments)
                ..where((row) => row.transcriptId.equals(segment.transcriptId))
                ..where((row) => row.isFinal.equals(true))
                ..orderBy([
                  (row) => OrderingTerm.asc(row.startMs),
                  (row) => OrderingTerm.asc(row.endMs),
                ]))
              .get();
      final coveredDuration = _coveredDuration(rows);
      await (database.update(
        database.transcripts,
      )..where((row) => row.id.equals(segment.transcriptId))).write(
        db.TranscriptsCompanion(
          coveredDurationMs: Value(coveredDuration.inMilliseconds),
          updatedAt: Value(segment.updatedAt),
        ),
      );
    });
  }

  @override
  Future<TranscriptDocument> freeze(String draftId, {required int revision}) =>
      _serializeMutation(() => _freezeAtRevision(draftId, revision: revision));

  @override
  Future<TranscriptDocument> freezeNext(String draftId) =>
      _serializeMutation(() async {
        final draft = await load(draftId);
        if (draft == null || draft.kind != TranscriptKind.realtimeDraft) {
          throw StateError('Only a realtime draft can be frozen.');
        }
        final revision = await _nextRevision(draft.meetingId);
        return _freezeAtRevision(draftId, revision: revision);
      });

  Future<TranscriptDocument> _freezeAtRevision(
    String draftId, {
    required int revision,
  }) async {
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    final draft = await load(draftId);
    if (draft == null || draft.kind != TranscriptKind.realtimeDraft) {
      throw StateError('Only a realtime draft can be frozen.');
    }
    if (draft.status == TranscriptStatus.needsRepair || draft.gaps.isNotEmpty) {
      throw StateError(
        'A transcript with gaps must be repaired before freezing.',
      );
    }
    final completedSegments = await segments(draftId);
    if (completedSegments.isEmpty ||
        completedSegments.any((item) => !item.isFinal)) {
      throw StateError(
        'All transcript segments must be completed before freezing.',
      );
    }
    final body = completedSegments.map((segment) => segment.text).join('\n');
    final existingFinal =
        await (database.select(database.transcripts)
              ..where((row) => row.meetingId.equals(draft.meetingId))
              ..where(
                (row) => row.kind.equals(TranscriptKind.finalTranscript.name),
              )
              ..where((row) => row.revision.equals(revision)))
            .getSingleOrNull();
    if (existingFinal != null) {
      final existingBody = existingFinal.bodyPath == null
          ? null
          : File(existingFinal.bodyPath!);
      if (existingBody != null &&
          await existingBody.exists() &&
          await existingBody.readAsString() == body) {
        return _documentFromRow(existingFinal);
      }
      throw StateError(
        'Transcript revision $revision is already occupied by other data.',
      );
    }

    final finalId = const Uuid().v4();
    final target = File(
      p.join(
        baseDirectory.path,
        draft.meetingId,
        'transcripts',
        'final-r$revision-$finalId.txt',
      ),
    );
    await target.parent.create(recursive: true);
    await _writeAtomic(target, body);

    final now = DateTime.now();
    try {
      await database.transaction(() async {
        final currentMeeting = await (database.select(
          database.meetings,
        )..where((row) => row.id.equals(draft.meetingId))).getSingleOrNull();
        if (currentMeeting == null || currentMeeting.deletedAt != null) {
          throw StateError('Meeting does not exist or is trashed.');
        }
        await database
            .into(database.transcripts)
            .insert(
              db.TranscriptsCompanion.insert(
                id: finalId,
                meetingId: draft.meetingId,
                kind: TranscriptKind.finalTranscript.name,
                status: TranscriptStatus.ready.name,
                providerProtocol: Value(draft.providerProtocol),
                model: Value(draft.model),
                language: Value(draft.language),
                coveredDurationMs: draft.coveredDuration.inMilliseconds,
                bodyPath: Value(target.path),
                revision: revision,
                frozenAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
        for (final segment in completedSegments) {
          await database
              .into(database.transcriptSegments)
              .insert(
                db.TranscriptSegmentsCompanion.insert(
                  id: '$finalId-${segment.id}',
                  transcriptId: finalId,
                  providerItemId: segment.providerItemId,
                  ordinal: segment.ordinal,
                  startMs: segment.start.inMilliseconds,
                  endMs: segment.end.inMilliseconds,
                  transcriptText: segment.text,
                  isFinal: true,
                  source: segment.source.name,
                  speakerId: Value(segment.speakerId),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
        await (database.update(
          database.transcripts,
        )..where((row) => row.id.equals(draftId))).write(
          db.TranscriptsCompanion(
            status: Value(TranscriptStatus.ready.name),
            frozenAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      });
    } on Object {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    return (await load(finalId))!;
  }

  @override
  Future<TranscriptDocument> saveBatchFinal({
    required String meetingId,
    required String body,
    required int revision,
    required Duration coveredDuration,
    String? providerProtocol,
    String? model,
    String? language,
  }) => _serializeMutation(
    () => _saveBatchFinalAtRevision(
      meetingId: meetingId,
      body: body,
      revision: revision,
      coveredDuration: coveredDuration,
      providerProtocol: providerProtocol,
      model: model,
      language: language,
    ),
  );

  @override
  Future<TranscriptDocument> saveBatchFinalNext({
    required String meetingId,
    required String body,
    required Duration coveredDuration,
    String? idempotencyKey,
    String? providerProtocol,
    String? model,
    String? language,
  }) => _serializeMutation(() async {
    final stableId = idempotencyKey == null || idempotencyKey.trim().isEmpty
        ? null
        : 'batch-${idempotencyKey.trim()}';
    if (stableId != null) {
      final existing = await load(stableId);
      if (existing != null) {
        final existingBody = existing.bodyPath == null
            ? null
            : File(existing.bodyPath!);
        if (existing.meetingId != meetingId ||
            existing.kind != TranscriptKind.finalTranscript ||
            existingBody == null ||
            !await existingBody.exists() ||
            await existingBody.readAsString() != body) {
          throw StateError('Batch transcript idempotency key is occupied.');
        }
        return existing;
      }
    }
    final revision = await _nextRevision(meetingId);
    return _saveBatchFinalAtRevision(
      meetingId: meetingId,
      body: body,
      revision: revision,
      coveredDuration: coveredDuration,
      providerProtocol: providerProtocol,
      model: model,
      language: language,
      id: stableId,
    );
  });

  Future<TranscriptDocument> _saveBatchFinalAtRevision({
    required String meetingId,
    required String body,
    required int revision,
    required Duration coveredDuration,
    String? providerProtocol,
    String? model,
    String? language,
    String? id,
  }) async {
    if (revision < 1) throw ArgumentError.value(revision, 'revision');
    if (body.trim().isEmpty) {
      throw ArgumentError.value(body, 'body', 'must not be empty');
    }
    final meeting = await (database.select(
      database.meetings,
    )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
    if (meeting == null || meeting.deletedAt != null) {
      throw StateError('Meeting does not exist or is trashed.');
    }
    final existing =
        await (database.select(database.transcripts)
              ..where((row) => row.meetingId.equals(meetingId))
              ..where(
                (row) => row.kind.equals(TranscriptKind.finalTranscript.name),
              )
              ..where((row) => row.revision.equals(revision)))
            .getSingleOrNull();
    if (existing != null) {
      final existingBody = existing.bodyPath == null
          ? null
          : File(existing.bodyPath!);
      if (existing.status != TranscriptStatus.ready.name ||
          existingBody == null ||
          !await existingBody.exists() ||
          await existingBody.readAsString() != body) {
        throw StateError(
          'Transcript revision $revision is already occupied by other data.',
        );
      }
      return _documentFromRow(existing);
    }

    final transcriptId = id ?? const Uuid().v4();
    final target = File(
      p.join(
        baseDirectory.path,
        meetingId,
        'transcripts',
        'final-r$revision-$transcriptId.txt',
      ),
    );
    await target.parent.create(recursive: true);
    await _writeAtomic(target, body);

    final now = DateTime.now();
    try {
      await database.transaction(() async {
        final currentMeeting = await (database.select(
          database.meetings,
        )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
        if (currentMeeting == null || currentMeeting.deletedAt != null) {
          throw StateError('Meeting does not exist or is trashed.');
        }
        await database
            .into(database.transcripts)
            .insert(
              db.TranscriptsCompanion.insert(
                id: transcriptId,
                meetingId: meetingId,
                kind: TranscriptKind.finalTranscript.name,
                status: TranscriptStatus.ready.name,
                providerProtocol: Value(providerProtocol),
                model: Value(model),
                language: Value(language),
                coveredDurationMs: coveredDuration.inMilliseconds,
                bodyPath: Value(target.path),
                revision: revision,
                frozenAt: Value(now),
                createdAt: now,
                updatedAt: now,
              ),
            );
      });
    } on Object {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    return (await load(transcriptId))!;
  }

  Future<int> _nextRevision(String meetingId) async {
    final latest =
        await (database.select(database.transcripts)
              ..where((row) => row.meetingId.equals(meetingId))
              ..where(
                (row) => row.kind.equals(TranscriptKind.finalTranscript.name),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.revision)]))
            .getSingleOrNull();
    return (latest?.revision ?? 0) + 1;
  }

  Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  @override
  Future<void> markNeedsRepair(String id, List<TranscriptGap> gaps) async {
    if (gaps.isEmpty) {
      throw ArgumentError('At least one transcript gap is required.');
    }
    final changed =
        await (database.update(database.transcripts)
              ..where((row) => row.id.equals(id))
              ..where(
                (row) => row.kind.equals(TranscriptKind.realtimeDraft.name),
              ))
            .write(
              db.TranscriptsCompanion(
                status: Value(TranscriptStatus.needsRepair.name),
                gapsJson: Value(
                  jsonEncode(gaps.map((gap) => gap.toJson()).toList()),
                ),
                updatedAt: Value(DateTime.now()),
              ),
            );
    if (changed != 1) throw StateError('Realtime draft does not exist.');
  }

  @override
  Future<TranscriptDocument?> finalForMeeting(String meetingId) async {
    final row =
        await (database.select(database.transcripts)
              ..where((item) => item.meetingId.equals(meetingId))
              ..where(
                (item) => item.kind.equals(TranscriptKind.finalTranscript.name),
              )
              ..where((item) => item.status.equals(TranscriptStatus.ready.name))
              ..where((item) => item.deletedAt.isNull())
              ..orderBy([(item) => OrderingTerm.desc(item.revision)]))
            .getSingleOrNull();
    return row == null ? null : _documentFromRow(row);
  }

  @override
  Future<TranscriptDocument?> load(String id) async {
    final row = await (database.select(
      database.transcripts,
    )..where((item) => item.id.equals(id))).getSingleOrNull();
    return row == null ? null : _documentFromRow(row);
  }

  @override
  Future<List<TranscriptSegment>> segments(String transcriptId) async {
    final rows =
        await (database.select(database.transcriptSegments)
              ..where((item) => item.transcriptId.equals(transcriptId))
              ..orderBy([
                (item) => OrderingTerm.asc(item.startMs),
                (item) => OrderingTerm.asc(item.ordinal),
                (item) => OrderingTerm.asc(item.providerItemId),
              ]))
            .get();
    return rows.map(_segmentFromRow).toList(growable: false);
  }

  @override
  Future<List<TranscriptDocument>> listTrash() async {
    final rows =
        await (database.select(database.transcripts)
              ..where((row) => row.deletedAt.isNotNull())
              ..orderBy([(row) => OrderingTerm.desc(row.deletedAt)]))
            .get();
    return rows.map(_documentFromRow).toList(growable: false);
  }

  @override
  Future<void> moveToTrash(String id) async {
    final now = DateTime.now();
    final changed =
        await (database.update(database.transcripts)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.deletedAt.isNull()))
            .write(
              db.TranscriptsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) {
      throw StateError('Transcript does not exist or is trashed.');
    }
  }

  @override
  Future<void> restore(String id) async {
    final now = DateTime.now();
    final changed =
        await (database.update(database.transcripts)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.deletedAt.isNotNull()))
            .write(
              db.TranscriptsCompanion(
                deletedAt: const Value(null),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) throw StateError('Transcript is not in trash.');
  }

  @override
  Future<void> permanentlyDelete(String id) async {
    final row =
        await (database.select(database.transcripts)
              ..where((item) => item.id.equals(id))
              ..where((item) => item.deletedAt.isNotNull()))
            .getSingleOrNull();
    if (row == null) throw StateError('Transcript is not in trash.');
    await database.transaction(() async {
      await (database.delete(
        database.transcriptSegments,
      )..where((segment) => segment.transcriptId.equals(id))).go();
      await (database.delete(
        database.transcripts,
      )..where((item) => item.id.equals(id))).go();
      final path = row.bodyPath;
      if (path != null) {
        final body = File(path);
        if (await body.exists()) await body.delete();
      }
    });
  }

  @override
  Future<int> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 30));
    final expired = (await listTrash())
        .where(
          (document) =>
              document.deletedAt != null &&
              document.deletedAt!.isBefore(cutoff),
        )
        .toList(growable: false);
    for (final document in expired) {
      await permanentlyDelete(document.id);
    }
    return expired.length;
  }

  static TranscriptDocument _documentFromRow(db.Transcript row) {
    final decodedGaps = jsonDecode(row.gapsJson) as List<Object?>;
    return TranscriptDocument(
      id: row.id,
      meetingId: row.meetingId,
      kind: TranscriptKind.values.byName(row.kind),
      status: TranscriptStatus.values.byName(row.status),
      providerProtocol: row.providerProtocol,
      model: row.model,
      language: row.language,
      coveredDuration: Duration(milliseconds: row.coveredDurationMs),
      bodyPath: row.bodyPath,
      revision: row.revision,
      frozenAt: row.frozenAt,
      deletedAt: row.deletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      gaps: decodedGaps
          .whereType<Map<String, Object?>>()
          .map(TranscriptGap.fromJson)
          .toList(growable: false),
    );
  }

  static TranscriptSegment _segmentFromRow(db.TranscriptSegment row) =>
      TranscriptSegment(
        id: row.id,
        transcriptId: row.transcriptId,
        providerItemId: row.providerItemId,
        ordinal: row.ordinal,
        start: Duration(milliseconds: row.startMs),
        end: Duration(milliseconds: row.endMs),
        text: row.transcriptText,
        isFinal: row.isFinal,
        source: TranscriptSegmentSource.values.byName(row.source),
        speakerId: row.speakerId,
        updatedAt: row.updatedAt,
      );

  static Duration _coveredDuration(List<db.TranscriptSegment> rows) {
    var coveredMs = 0;
    var intervalStart = -1;
    var intervalEnd = -1;
    for (final row in rows) {
      if (intervalStart < 0) {
        intervalStart = row.startMs;
        intervalEnd = row.endMs;
      } else if (row.startMs <= intervalEnd) {
        if (row.endMs > intervalEnd) intervalEnd = row.endMs;
      } else {
        coveredMs += intervalEnd - intervalStart;
        intervalStart = row.startMs;
        intervalEnd = row.endMs;
      }
    }
    if (intervalStart >= 0) coveredMs += intervalEnd - intervalStart;
    return Duration(milliseconds: coveredMs);
  }

  static Future<void> _writeAtomic(File target, String contents) async {
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }
}
