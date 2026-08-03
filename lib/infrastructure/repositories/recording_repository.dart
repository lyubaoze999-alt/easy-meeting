import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/meeting_record.dart';
import '../../domain/models/recording_asset.dart';
import '../database/app_database.dart' as db;

typedef FileDigestCalculator = Future<String> Function(File file);
typedef RecordingImport = NativeRecordingResult;

abstract interface class RecordingRepository {
  Future<RecordingAsset> importNativeResult(
    String meetingId,
    NativeRecordingResult result,
  );
  Future<RecordingAsset?> loadForMeeting(String meetingId);
  Future<List<OrphanRecording>> scanOrphans();
  Future<List<RecordingAsset>> listTrash();
  Future<void> moveToTrash(String id);
  Future<void> restore(String id);
  Future<void> permanentlyDelete(String id);
  Future<int> purgeExpired({DateTime? now});
}

class LocalRecordingRepository implements RecordingRepository {
  LocalRecordingRepository(
    this.database,
    this.baseDirectory, {
    this.digestCalculator,
    this.orphanDirectory,
  });

  final db.AppDatabase database;
  final Directory baseDirectory;
  final FileDigestCalculator? digestCalculator;
  final Directory? orphanDirectory;

  static Future<LocalRecordingRepository> open(
    db.AppDatabase database, {
    FileDigestCalculator? digestCalculator,
    Directory? orphanDirectory,
  }) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(support.path, 'EasyMeeting', 'Meetings'),
    );
    await directory.create(recursive: true);
    return LocalRecordingRepository(
      database,
      directory,
      digestCalculator: digestCalculator,
      orphanDirectory: orphanDirectory,
    );
  }

  @override
  Future<RecordingAsset> importNativeResult(
    String meetingId,
    NativeRecordingResult result,
  ) async {
    final meeting = await (database.select(
      database.meetings,
    )..where((row) => row.id.equals(meetingId))).getSingleOrNull();
    if (meeting == null || meeting.status != MeetingStatus.recording.name) {
      throw StateError('A recording asset requires an active meeting draft.');
    }
    final existing = await loadForMeeting(meetingId);
    if (existing != null) return existing;

    final source = File(result.path);
    final directory = Directory(
      p.join(baseDirectory.path, meetingId, 'recording'),
    );
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, 'audio.wav'));
    final sourceExists = await source.exists();
    final targetExists = await target.exists();
    if (!sourceExists && !targetExists) {
      throw StateError('Recording file does not exist.');
    }
    // A previous attempt may have completed the atomic rename and then failed
    // before inserting the asset row. Recover that durable target in place.
    final durableInput = targetExists ? target : source;
    final metadata = await _inspectPcmWav(durableInput);
    final digest = result.sha256 ?? await digestCalculator?.call(durableInput);
    if (digest == null || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(digest)) {
      throw StateError(
        'A valid SHA-256 digest or FileDigestCalculator is required.',
      );
    }

    final temporary = File('${target.path}.tmp');
    if (!targetExists && source.absolute.path != target.absolute.path) {
      final output = temporary.openWrite(mode: FileMode.writeOnly);
      try {
        await for (final chunk in source.openRead()) {
          output.add(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
      }
      await temporary.rename(target.path);
    }

    final archivedFile = targetExists
        ? target
        : source.absolute.path == target.absolute.path
        ? source
        : target;
    final stat = await archivedFile.stat();
    final now = DateTime.now();
    final asset = RecordingAsset(
      id: const Uuid().v4(),
      meetingId: meetingId,
      path: archivedFile.path,
      mimeType: 'audio/wav',
      sampleRate: metadata.sampleRate,
      channels: metadata.channels,
      // The finalized WAV header is the durable source of truth. Wall-clock
      // elapsed time includes command latency and can drift from audio samples.
      duration: metadata.duration,
      byteLength: stat.size,
      sha256: digest.toLowerCase(),
      sourceProfile: result.sourceProfile,
      finalizedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    await database
        .into(database.recordingAssets)
        .insert(
          db.RecordingAssetsCompanion.insert(
            id: asset.id,
            meetingId: asset.meetingId,
            path: asset.path,
            mimeType: asset.mimeType,
            sampleRate: Value(asset.sampleRate),
            channels: Value(asset.channels),
            durationMs: asset.duration.inMilliseconds,
            byteLength: asset.byteLength,
            sha256: Value(asset.sha256),
            sourceProfile: asset.sourceProfile.name,
            finalizedAt: asset.finalizedAt,
            createdAt: asset.createdAt,
            updatedAt: asset.updatedAt,
          ),
        );

    if (await source.exists() &&
        source.absolute.path != archivedFile.absolute.path) {
      try {
        await source.delete();
      } on FileSystemException {
        // The finalized asset is already durable and referenced. The native
        // source remains discoverable as an orphan if cleanup is unavailable.
      }
    }
    return asset;
  }

  Future<RecordingAsset> importRecording(
    String meetingId,
    RecordingImport result,
  ) => importNativeResult(meetingId, result);

  @override
  Future<RecordingAsset?> loadForMeeting(String meetingId) async {
    final row =
        await (database.select(database.recordingAssets)
              ..where((item) => item.meetingId.equals(meetingId))
              ..where((item) => item.deletedAt.isNull()))
            .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<OrphanRecording>> scanOrphans() async {
    final rows = await database.select(database.recordingAssets).get();
    final referencedPaths = rows
        .map((row) => File(row.path).absolute.path)
        .toSet();
    final roots = <Directory>{baseDirectory, ?orphanDirectory};
    final orphanPaths = <String>{};
    final result = <OrphanRecording>[];
    for (final root in roots) {
      if (!await root.exists()) continue;
      await for (final entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File ||
            p.extension(entity.path).toLowerCase() != '.wav') {
          continue;
        }
        final absolutePath = entity.absolute.path;
        if (referencedPaths.contains(absolutePath) ||
            !orphanPaths.add(absolutePath)) {
          continue;
        }
        final stat = await entity.stat();
        result.add(
          OrphanRecording(
            path: entity.path,
            byteLength: stat.size,
            modifiedAt: stat.modified,
          ),
        );
      }
    }
    result.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return result;
  }

  @override
  Future<void> moveToTrash(String id) async {
    final now = DateTime.now();
    final changed =
        await (database.update(database.recordingAssets)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.deletedAt.isNull()))
            .write(
              db.RecordingAssetsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) {
      throw StateError('Recording asset does not exist or is already trashed.');
    }
  }

  @override
  Future<List<RecordingAsset>> listTrash() async {
    final rows =
        await (database.select(database.recordingAssets)
              ..where((row) => row.deletedAt.isNotNull())
              ..orderBy([(row) => OrderingTerm.desc(row.deletedAt)]))
            .get();
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<void> restore(String id) async {
    final now = DateTime.now();
    final changed =
        await (database.update(database.recordingAssets)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.deletedAt.isNotNull()))
            .write(
              db.RecordingAssetsCompanion(
                deletedAt: const Value(null),
                updatedAt: Value(now),
              ),
            );
    if (changed != 1) throw StateError('Recording is not in trash.');
  }

  @override
  Future<void> permanentlyDelete(String id) async {
    final row =
        await (database.select(database.recordingAssets)
              ..where((item) => item.id.equals(id))
              ..where((item) => item.deletedAt.isNotNull()))
            .getSingleOrNull();
    if (row == null) throw StateError('Recording is not in trash.');
    await database.transaction(() async {
      await (database.delete(
        database.recordingAssets,
      )..where((item) => item.id.equals(id))).go();
      final file = File(row.path);
      if (await file.exists()) await file.delete();
    });
  }

  @override
  Future<int> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 30));
    final expired = (await listTrash())
        .where(
          (asset) =>
              asset.deletedAt != null && asset.deletedAt!.isBefore(cutoff),
        )
        .toList(growable: false);
    for (final asset in expired) {
      await permanentlyDelete(asset.id);
    }
    return expired.length;
  }

  static RecordingAsset _fromRow(db.RecordingAsset row) => RecordingAsset(
    id: row.id,
    meetingId: row.meetingId,
    path: row.path,
    mimeType: row.mimeType,
    sampleRate: row.sampleRate,
    channels: row.channels,
    duration: Duration(milliseconds: row.durationMs),
    byteLength: row.byteLength,
    sha256: row.sha256,
    sourceProfile: AudioCaptureProfile.values.firstWhere(
      (profile) => profile.name == row.sourceProfile,
      orElse: () => AudioCaptureProfile.legacyUnknown,
    ),
    finalizedAt: row.finalizedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
  );
}

class _WavMetadata {
  const _WavMetadata({
    required this.sampleRate,
    required this.channels,
    required this.duration,
  });

  final int sampleRate;
  final int channels;
  final Duration duration;
}

Future<_WavMetadata> _inspectPcmWav(File file) async {
  final handle = await file.open();
  try {
    final length = await handle.length();
    if (length < 44) throw const FormatException('WAV file is incomplete.');
    final header = await handle.read(12);
    if (ascii.decode(header.sublist(0, 4)) != 'RIFF' ||
        ascii.decode(header.sublist(8, 12)) != 'WAVE') {
      throw const FormatException('Recording is not a RIFF/WAVE file.');
    }
    int? sampleRate;
    int? channels;
    int? byteRate;
    int? dataLength;
    var position = 12;
    while (position + 8 <= length) {
      await handle.setPosition(position);
      final chunkHeader = await handle.read(8);
      if (chunkHeader.length != 8) break;
      final chunkId = ascii.decode(
        chunkHeader.sublist(0, 4),
        allowInvalid: true,
      );
      final chunkSize = ByteData.sublistView(
        Uint8List.fromList(chunkHeader),
      ).getUint32(4, Endian.little);
      final dataStart = position + 8;
      if (dataStart + chunkSize > length) {
        throw const FormatException(
          'WAV chunk extends past the file boundary.',
        );
      }
      if (chunkId == 'fmt ') {
        if (chunkSize < 16) {
          throw const FormatException('Invalid WAV fmt chunk.');
        }
        await handle.setPosition(dataStart);
        final formatBytes = Uint8List.fromList(await handle.read(16));
        final format = ByteData.sublistView(formatBytes);
        if (format.getUint16(0, Endian.little) != 1 ||
            format.getUint16(14, Endian.little) != 16) {
          throw const FormatException('Recording must be PCM16 WAV audio.');
        }
        channels = format.getUint16(2, Endian.little);
        sampleRate = format.getUint32(4, Endian.little);
        byteRate = format.getUint32(8, Endian.little);
      } else if (chunkId == 'data') {
        dataLength = chunkSize;
      }
      position = dataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }
    if (sampleRate == null ||
        sampleRate <= 0 ||
        channels == null ||
        channels <= 0 ||
        byteRate == null ||
        byteRate <= 0 ||
        dataLength == null ||
        dataLength <= 0) {
      throw const FormatException('WAV metadata or audio data is missing.');
    }
    return _WavMetadata(
      sampleRate: sampleRate,
      channels: channels,
      duration: Duration(milliseconds: dataLength * 1000 ~/ byteRate),
    );
  } finally {
    await handle.close();
  }
}
