import 'dart:io';

import 'package:uuid/uuid.dart';

import '../domain/models/meeting_record.dart';
import '../domain/models/note_template.dart';
import '../domain/models/recording_asset.dart';
import '../infrastructure/files/file_digest.dart';
import '../infrastructure/repositories/meeting_repository.dart';
import '../infrastructure/repositories/recording_repository.dart';
import 'meeting_session_controller.dart';
import 'recording_coordinator.dart';

/// Persists the meeting draft before native capture and archives the WAV before
/// the meeting can become `recorded`.
final class PersistentMeetingCapture
    implements MeetingCapturePort, PendingCaptureFinalizationPort {
  PersistentMeetingCapture({
    required this.coordinator,
    required this.meetings,
    required this.recordings,
    this.idFactory = _defaultId,
  });

  final RecordingCoordinator coordinator;
  final MeetingRepository meetings;
  final RecordingRepository recordings;
  final String Function() idFactory;

  String? activeMeetingId;
  String? lastMeetingId;
  RecordingAsset? lastAsset;
  RecordingResult? _pendingNativeResult;
  String? _pendingDigest;

  @override
  bool get hasPendingFinalization => _pendingNativeResult != null;

  @override
  Future<void> start() async {
    if (activeMeetingId != null) {
      throw StateError('已有会议正在录音或等待归档。');
    }
    final meetingId = idFactory();
    await meetings.create(
      MeetingDraft(
        id: meetingId,
        startedAt: DateTime.now(),
        templateSnapshot: coordinator.selectedTemplate,
      ),
    );
    activeMeetingId = meetingId;
    try {
      await coordinator.start();
    } catch (_) {
      activeMeetingId = null;
      await meetings.deleteDraft(meetingId);
      rethrow;
    }
  }

  @override
  Future<void> pause() => coordinator.pause();

  @override
  Future<void> resume() => coordinator.resume();

  @override
  Future<RecordingResult> stopAndSave() async {
    final meetingId = activeMeetingId;
    if (meetingId == null) throw StateError('没有可归档的活动会议。');
    final result = _pendingNativeResult ?? await coordinator.stop();
    _pendingNativeResult = result;

    var asset = await recordings.loadForMeeting(meetingId);
    if (asset == null) {
      _pendingDigest ??= await calculateSha256(File(result.audioPath));
      asset = await recordings.importNativeResult(
        meetingId,
        result.toNativeResult(sha256: _pendingDigest),
      );
    }
    await meetings.updateCaptureMetadata(
      meetingId,
      template: result.template,
      highlights: result.highlights,
    );
    await meetings.markRecorded(meetingId, asset);

    lastMeetingId = meetingId;
    lastAsset = asset;
    activeMeetingId = null;
    _pendingNativeResult = null;
    _pendingDigest = null;
    return result;
  }

  @override
  void reset() {
    coordinator.reset();
    lastMeetingId = null;
    lastAsset = null;
  }

  @override
  void addHighlight() => coordinator.addHighlight();

  @override
  void selectTemplate(NoteTemplate template) =>
      coordinator.selectTemplate(template);

  static String _defaultId() => const Uuid().v4();
}
