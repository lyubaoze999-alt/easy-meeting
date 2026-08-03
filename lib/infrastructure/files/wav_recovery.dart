import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _maximumRecoverableHeaderLength = 1024 * 1024;

/// Creates a validated working copy of a PCM16 WAV recording.
///
/// If a native recorder was interrupted with zero RIFF/data length fields,
/// the copy receives lengths derived from the actual payload. The source is
/// always read-only and remains untouched until its caller commits the import.
Future<bool> createRecoverablePcmWavCopy(File source, File destination) async {
  final input = await source.open();
  try {
    final fileLength = await input.length();
    if (fileLength < 45 || fileLength - 8 > 0xffffffff) {
      throw const FormatException('WAV file has no recoverable PCM payload.');
    }
    final riffHeader = await input.read(12);
    if (riffHeader.length != 12 ||
        ascii.decode(riffHeader.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
        ascii.decode(riffHeader.sublist(8, 12), allowInvalid: true) != 'WAVE') {
      throw const FormatException('Recording is not a RIFF/WAVE file.');
    }

    var position = 12;
    int? blockAlign;
    int? dataSizeOffset;
    int? dataStart;
    int? declaredDataLength;
    while (position + 8 <= fileLength) {
      await input.setPosition(position);
      final chunkHeader = Uint8List.fromList(await input.read(8));
      if (chunkHeader.length != 8) break;
      final chunkId = ascii.decode(
        chunkHeader.sublist(0, 4),
        allowInvalid: true,
      );
      final chunkSize = ByteData.sublistView(
        chunkHeader,
      ).getUint32(4, Endian.little);
      final chunkDataStart = position + 8;

      if (chunkId == 'fmt ') {
        if (chunkSize < 16 || chunkDataStart + 16 > fileLength) {
          throw const FormatException('Invalid WAV fmt chunk.');
        }
        await input.setPosition(chunkDataStart);
        final bytes = Uint8List.fromList(await input.read(16));
        final format = ByteData.sublistView(bytes);
        final channels = format.getUint16(2, Endian.little);
        final sampleRate = format.getUint32(4, Endian.little);
        final byteRate = format.getUint32(8, Endian.little);
        blockAlign = format.getUint16(12, Endian.little);
        if (format.getUint16(0, Endian.little) != 1 ||
            format.getUint16(14, Endian.little) != 16 ||
            channels < 1 ||
            channels > 8 ||
            sampleRate < 8000 ||
            sampleRate > 384000 ||
            blockAlign != channels * 2 ||
            byteRate != sampleRate * blockAlign) {
          throw const FormatException(
            'Recording must be valid PCM16 WAV audio.',
          );
        }
      } else if (chunkId == 'data') {
        dataSizeOffset = position + 4;
        dataStart = chunkDataStart;
        declaredDataLength = chunkSize;
        break;
      }

      if (chunkDataStart + chunkSize > fileLength) {
        throw const FormatException('WAV chunk exceeds the file boundary.');
      }
      position = chunkDataStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (blockAlign == null ||
        dataSizeOffset == null ||
        dataStart == null ||
        declaredDataLength == null) {
      throw const FormatException('WAV metadata is incomplete.');
    }
    if (declaredDataLength > 0) {
      if (dataStart + declaredDataLength > fileLength) {
        throw const FormatException('WAV data exceeds the file boundary.');
      }
      await source.copy(destination.path);
      return false;
    }

    final actualDataLength = fileLength - dataStart;
    if (dataStart > _maximumRecoverableHeaderLength ||
        actualDataLength <= 0 ||
        actualDataLength > 0xffffffff ||
        actualDataLength % blockAlign != 0) {
      throw const FormatException('WAV PCM payload is incomplete.');
    }

    await input.setPosition(0);
    final header = Uint8List.fromList(await input.read(dataStart));
    if (header.length != dataStart) {
      throw const FormatException('WAV header is incomplete.');
    }
    final patched = ByteData.sublistView(header);
    patched.setUint32(4, fileLength - 8, Endian.little);
    patched.setUint32(dataSizeOffset, actualDataLength, Endian.little);

    final output = destination.openWrite(mode: FileMode.writeOnly);
    try {
      output.add(header);
      await output.addStream(source.openRead(dataStart));
      await output.flush();
    } finally {
      await output.close();
    }
    if (await destination.length() != fileLength) {
      throw const FileSystemException('Recovered WAV copy is incomplete.');
    }
    return true;
  } finally {
    await input.close();
  }
}
