import 'dart:io';
import 'dart:typed_data';

Future<File> writePcmWav(
  Directory directory, {
  int sampleRate = 16000,
  int channels = 1,
  int samples = 1600,
}) async {
  final blockAlign = channels * 2;
  final pcmLength = samples * blockAlign;
  final bytes = Uint8List(44 + pcmLength);
  final data = ByteData.sublistView(bytes);
  bytes.setAll(0, 'RIFF'.codeUnits);
  data.setUint32(4, 36 + pcmLength, Endian.little);
  bytes.setAll(8, 'WAVEfmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * blockAlign, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setAll(36, 'data'.codeUnits);
  data.setUint32(40, pcmLength, Endian.little);
  for (var offset = 44; offset < bytes.length; offset += 2) {
    data.setInt16(offset, ((offset - 44) ~/ 2) % 1000, Endian.little);
  }
  final file = File('${directory.path}/source.wav');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
