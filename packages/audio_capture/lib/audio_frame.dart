import 'dart:typed_data';

/// One normalized copy of the audio being persisted by the native recorder.
///
/// Frames use signed 16-bit little-endian PCM. Regular frames contain 200 ms
/// of 24 kHz mono audio (4,800 samples / 9,600 bytes). A native implementation
/// may emit a shorter terminal frame when recording stops.
class AudioFrame {
  const AudioFrame({
    required this.sessionId,
    required this.sequence,
    required this.startSample,
    required this.sampleRate,
    required this.channels,
    required this.bytes,
  });

  static const int canonicalSampleRate = 24000;
  static const int canonicalChannels = 1;
  static const int bytesPerSample = 2;
  static const Duration canonicalDuration = Duration(milliseconds: 200);
  static const int canonicalSamplesPerFrame = 4800;
  static const int canonicalBytesPerFrame = 9600;

  final String sessionId;
  final int sequence;
  final int startSample;
  final int sampleRate;
  final int channels;
  final Uint8List bytes;

  int get sampleCount => bytes.lengthInBytes ~/ (bytesPerSample * channels);
  int get endSample => startSample + sampleCount;

  bool follows(AudioFrame previous) =>
      sessionId == previous.sessionId &&
      sequence == previous.sequence + 1 &&
      startSample == previous.endSample;

  factory AudioFrame.fromMap(Map<Object?, Object?> map) {
    final sessionId = map['sessionId'];
    final sequence = map['sequence'];
    final startSample = map['startSample'];
    final sampleRate = map['sampleRate'];
    final channels = map['channels'];
    final bytes = map['bytes'];

    if (sessionId is! String || sessionId.isEmpty) {
      throw const FormatException('Audio frame sessionId is missing.');
    }
    if (sequence is! int || sequence < 0) {
      throw const FormatException('Audio frame sequence is invalid.');
    }
    if (startSample is! int || startSample < 0) {
      throw const FormatException('Audio frame startSample is invalid.');
    }
    if (sampleRate is! int || sampleRate != canonicalSampleRate) {
      throw const FormatException('Audio frame sampleRate must be 24000 Hz.');
    }
    if (channels is! int || channels != canonicalChannels) {
      throw const FormatException('Audio frame must contain mono audio.');
    }
    if (bytes is! Uint8List ||
        bytes.isEmpty ||
        bytes.lengthInBytes > canonicalBytesPerFrame ||
        bytes.lengthInBytes % (bytesPerSample * channels) != 0) {
      throw const FormatException(
        'Audio frame bytes must be a frame-aligned Uint8List of at most 200 ms.',
      );
    }

    return AudioFrame(
      sessionId: sessionId,
      sequence: sequence,
      startSample: startSample,
      sampleRate: sampleRate,
      channels: channels,
      bytes: bytes,
    );
  }
}
