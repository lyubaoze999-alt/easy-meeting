import 'dart:typed_data';

import 'realtime_transcription_events.dart';

enum RealtimeProtocol { openAiRealtime, disabled }

enum RealtimeTurnDetection { serverVad, manual }

final class SecretReference {
  const SecretReference(this.id);

  final String id;

  @override
  String toString() => 'SecretReference([redacted])';
}

final class RealtimeTranscriptionConfig {
  const RealtimeTranscriptionConfig({
    required this.websocketUrl,
    required this.model,
    required this.secret,
    this.protocol = RealtimeProtocol.openAiRealtime,
    this.languages = const <String>[],
    this.keywords = const <String>[],
    this.contextPrompt,
    this.turnDetection = RealtimeTurnDetection.serverVad,
    this.sampleRate = 24000,
    this.safetyIdentifier,
  });

  final Uri websocketUrl;
  final String model;
  final RealtimeProtocol protocol;
  final SecretReference secret;
  final List<String> languages;
  final List<String> keywords;
  final String? contextPrompt;
  final RealtimeTurnDetection turnDetection;
  final int sampleRate;
  final String? safetyIdentifier;

  @override
  String toString() {
    final port = websocketUrl.hasPort ? ':${websocketUrl.port}' : '';
    return 'RealtimeTranscriptionConfig('
        '${websocketUrl.scheme}://${websocketUrl.host}$port/[redacted], '
        'model: $model, secret: [redacted])';
  }
}

final class RealtimeAudioFrame {
  const RealtimeAudioFrame({
    required this.sessionId,
    required this.sequence,
    required this.startSample,
    required this.sampleRate,
    required this.channels,
    required this.bytes,
  });

  final String sessionId;
  final int sequence;
  final int startSample;
  final int sampleRate;
  final int channels;
  final Uint8List bytes;

  int get sampleCount => bytes.lengthInBytes ~/ (channels * 2);
}

abstract interface class RealtimeSecretProvider {
  Future<String> read(SecretReference reference);
}

final class RealtimeClientException implements Exception {
  const RealtimeClientException({
    required this.code,
    required this.message,
    required this.isRetryable,
  });

  final String code;
  final String message;
  final bool isRetryable;

  @override
  String toString() => message;
}

abstract interface class RealtimeTranscriptionClient {
  Stream<RealtimeTranscriptEvent> get events;
  RealtimeConnectionState get connectionState;

  Future<void> connect(RealtimeTranscriptionConfig config);
  Future<void> append(RealtimeAudioFrame frame);
  Future<void> commitTurn();
  Future<void> flushAndClose();
  Future<void> abort();
}
