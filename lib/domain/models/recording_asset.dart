class RecordingAsset {
  const RecordingAsset({
    required this.id,
    required this.meetingId,
    required this.path,
    required this.mimeType,
    required this.sampleRate,
    required this.channels,
    required this.duration,
    required this.byteLength,
    required this.sha256,
    required this.sourceProfile,
    required this.finalizedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String meetingId;
  final String path;
  final String mimeType;
  final int? sampleRate;
  final int? channels;
  final Duration duration;
  final int byteLength;
  final String? sha256;
  final AudioCaptureProfile sourceProfile;
  final DateTime finalizedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  String get audioPath => path;
}

enum AudioCaptureProfile { dualSource, microphoneOnly, legacyUnknown }

class NativeRecordingResult {
  const NativeRecordingResult({
    required this.path,
    required this.duration,
    required this.sourceProfile,
    this.sha256,
  });

  final String path;
  final Duration duration;
  final AudioCaptureProfile sourceProfile;
  final String? sha256;
}

class OrphanRecording {
  const OrphanRecording({
    required this.path,
    required this.byteLength,
    required this.modifiedAt,
  });

  final String path;
  final int byteLength;
  final DateTime modifiedAt;
}
