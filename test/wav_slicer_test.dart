import 'dart:io';
import 'dart:typed_data';

import 'package:easy_meeting/domain/transcription/wav_slicer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  test(
    'slices remain ordered, frame-aligned, and lossless across boundaries',
    () async {
      for (var seconds = 2; seconds <= 12; seconds += 1) {
        final directory = await Directory.systemTemp.createTemp(
          'easy-meeting-wav-test-',
        );
        try {
          final source = await writePcmWav(
            directory,
            samples: 16000 * seconds + 137,
          );
          final slices = await const WavSlicer(
            maximumDuration: Duration(seconds: 2),
          ).slice(source, Directory('${directory.path}/slices'));
          expect(slices.length, greaterThan(1));
          expect(
            slices.map((file) => file.uri.pathSegments.last).toList(),
            orderedEquals(
              List.generate(
                slices.length,
                (index) => 'slice_${index.toString().padLeft(4, '0')}.wav',
              ),
            ),
          );

          final original = await source.readAsBytes();
          final reconstructed = <int>[];
          for (final slice in slices) {
            final bytes = await slice.readAsBytes();
            final pcmLength = ByteData.sublistView(
              bytes,
            ).getUint32(40, Endian.little);
            expect(pcmLength.isEven, isTrue);
            reconstructed.addAll(bytes.sublist(44, 44 + pcmLength));
          }
          expect(reconstructed, orderedEquals(original.sublist(44)));
        } finally {
          await directory.delete(recursive: true);
        }
      }
    },
  );

  test('rejects invalid WAV input with a user-safe format error', () async {
    final directory = await Directory.systemTemp.createTemp(
      'easy-meeting-wav-invalid-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/broken.wav');
    await file.writeAsString('not wav');
    expect(
      () =>
          const WavSlicer().slice(file, Directory('${directory.path}/slices')),
      throwsA(isA<WavFormatException>()),
    );
  });
}
