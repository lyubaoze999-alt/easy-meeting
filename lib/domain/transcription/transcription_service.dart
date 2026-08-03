import 'dart:io';

import '../../infrastructure/network/openai_compatible_client.dart';
import '../models/configuration.dart';
import 'wav_slicer.dart';

typedef TranscriptionProgress = void Function(int current, int total);

class TranscriptionService {
  const TranscriptionService({required this.client, required this.slicer});
  final OpenAICompatibleClient client;
  final WavSlicer slicer;

  Future<String> transcribe(
    File audio,
    Directory workingDirectory,
    ServiceConfig config, {
    TranscriptionProgress? onProgress,
  }) async {
    final slices = await slicer.slice(audio, workingDirectory);
    final parts = <String>[];
    for (var index = 0; index < slices.length; index += 1) {
      onProgress?.call(index + 1, slices.length);
      final response = await client.postAudio(
        'audio/transcriptions',
        slices[index],
        config,
      );
      final text = response['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        throw const OpenAIClientException('empty_transcript', '转写服务没有返回文字。');
      }
      parts.add(text.trim());
    }
    return parts.join('\n\n');
  }
}
