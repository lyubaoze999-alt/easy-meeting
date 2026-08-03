import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/models/meeting_record.dart';
import '../domain/models/note_template.dart';
import '../domain/models/recording_asset.dart';
import '../infrastructure/files/file_digest.dart';
import '../infrastructure/files/wav_recovery.dart';
import '../infrastructure/repositories/meeting_repository.dart';
import '../infrastructure/repositories/recording_repository.dart';

/// Presents finalized WAV files that are not indexed in the database and only
/// mutates them after an explicit user action.
class RecordingRecoveryService extends ChangeNotifier {
  RecordingRecoveryService({
    required this.meetings,
    required this.recordings,
    required Iterable<Directory> allowedDirectories,
    Iterable<OrphanRecording> initialRecordings = const [],
  }) : _allowedDirectories = List.unmodifiable(allowedDirectories),
       _pending = List.of(initialRecordings);

  final MeetingRepository meetings;
  final RecordingRepository recordings;
  final List<Directory> _allowedDirectories;
  final List<OrphanRecording> _pending;
  final Set<String> _inFlightPaths = <String>{};

  UnmodifiableListView<OrphanRecording> get pending =>
      UnmodifiableListView(_pending);
  bool isProcessing(OrphanRecording orphan) =>
      _inFlightPaths.contains(orphan.path);

  Future<void> refresh() async {
    _pending
      ..clear()
      ..addAll(await recordings.scanOrphans());
    notifyListeners();
  }

  Future<RecordingAsset> archive(OrphanRecording orphan) async {
    _begin(orphan);
    try {
      final file = File(orphan.path);
      if (!await file.exists()) {
        _remove(orphan);
        throw StateError('录音文件已不存在，恢复列表已刷新。');
      }
      await _requireAllowedWav(file);

      final meetingId = 'recovered-${const Uuid().v4()}';
      final temporary = File('${file.path}.$meetingId.recovery');
      var draftCreated = false;
      try {
        await createRecoverablePcmWavCopy(file, temporary);
        await meetings.create(
          MeetingDraft(
            id: meetingId,
            startedAt: orphan.modifiedAt,
            templateSnapshot: NoteTemplate.builtins.first,
          ),
        );
        draftCreated = true;
        final asset = await recordings.importNativeResult(
          meetingId,
          NativeRecordingResult(
            path: temporary.path,
            duration: Duration.zero,
            sourceProfile: AudioCaptureProfile.legacyUnknown,
            sha256: await calculateSha256(temporary),
          ),
        );
        await meetings.markRecorded(meetingId, asset);
        await file.delete();
        _remove(orphan);
        return asset;
      } catch (_) {
        if (await temporary.exists()) await temporary.delete();
        if (draftCreated) {
          final asset = await recordings.loadForMeeting(meetingId);
          if (asset == null) await meetings.deleteDraft(meetingId);
        }
        rethrow;
      }
    } finally {
      _end(orphan);
    }
  }

  Future<void> discard(OrphanRecording orphan) async {
    _begin(orphan);
    try {
      final file = File(orphan.path);
      await _requireAllowedWav(file);
      if (await file.exists()) await file.delete();
      _remove(orphan);
    } finally {
      _end(orphan);
    }
  }

  void _requirePending(OrphanRecording orphan) {
    if (!_pending.any((item) => item.path == orphan.path)) {
      throw StateError('该录音已处理，请刷新后重试。');
    }
  }

  void _begin(OrphanRecording orphan) {
    _requirePending(orphan);
    if (!_inFlightPaths.add(orphan.path)) {
      throw StateError('该录音正在处理中，请稍候。');
    }
    notifyListeners();
  }

  void _end(OrphanRecording orphan) {
    if (_inFlightPaths.remove(orphan.path)) notifyListeners();
  }

  Future<void> _requireAllowedWav(File file) async {
    if (p.extension(file.path).toLowerCase() != '.wav') {
      throw StateError('只能处理 WAV 录音文件。');
    }
    final target = await _canonicalPath(file);
    for (final directory in _allowedDirectories) {
      final root = await _canonicalPath(directory);
      if (target == root || p.isWithin(root, target)) return;
    }
    throw StateError('录音文件不在应用允许的恢复目录中。');
  }

  static Future<String> _canonicalPath(FileSystemEntity entity) async {
    try {
      return await entity.resolveSymbolicLinks();
    } on FileSystemException {
      return p.normalize(entity.absolute.path);
    }
  }

  void _remove(OrphanRecording orphan) {
    _pending.removeWhere((item) => item.path == orphan.path);
    notifyListeners();
  }
}
