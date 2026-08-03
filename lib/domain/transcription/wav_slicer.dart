import 'dart:io';
import 'dart:typed_data';

class WavFormatException implements Exception {
  const WavFormatException(this.message);
  final String message;
}

class WavSlicer {
  const WavSlicer({this.maximumDuration = const Duration(minutes: 20)});
  final Duration maximumDuration;

  Future<List<File>> slice(File source, Directory outputDirectory) async {
    final bytes = await source.readAsBytes();
    final info = _parse(bytes);
    final bytesPerSecond = info.sampleRate * info.blockAlign;
    final maximumBytes = bytesPerSecond * maximumDuration.inSeconds;
    if (info.dataLength <= maximumBytes) return [source];

    await outputDirectory.create(recursive: true);
    final slices = <File>[];
    var offset = 0;
    var index = 0;
    while (offset < info.dataLength) {
      var length = (info.dataLength - offset).clamp(0, maximumBytes);
      length -= length % info.blockAlign;
      if (length == 0) break;
      final pcm = bytes.sublist(
        info.dataOffset + offset,
        info.dataOffset + offset + length,
      );
      final output = File(
        '${outputDirectory.path}/slice_${index.toString().padLeft(4, '0')}.wav',
      );
      await output.writeAsBytes(_canonicalWav(info, pcm), flush: true);
      slices.add(output);
      offset += length;
      index += 1;
    }
    return slices;
  }

  _WavInfo _parse(Uint8List bytes) {
    if (bytes.length < 44 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
        String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
      throw const WavFormatException('录音文件不是有效的 WAV。');
    }
    final data = ByteData.sublistView(bytes);
    int? format;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? blockAlign;
    int? dataOffset;
    int? dataLength;
    var cursor = 12;
    while (cursor + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(cursor, cursor + 4));
      final length = data.getUint32(cursor + 4, Endian.little);
      final payload = cursor + 8;
      if (payload + length > bytes.length) break;
      if (id == 'fmt ' && length >= 16) {
        format = data.getUint16(payload, Endian.little);
        channels = data.getUint16(payload + 2, Endian.little);
        sampleRate = data.getUint32(payload + 4, Endian.little);
        blockAlign = data.getUint16(payload + 12, Endian.little);
        bitsPerSample = data.getUint16(payload + 14, Endian.little);
      } else if (id == 'data') {
        dataOffset = payload;
        dataLength = length;
      }
      cursor = payload + length + (length.isOdd ? 1 : 0);
    }
    if (format == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        blockAlign == null ||
        dataOffset == null ||
        dataLength == null) {
      throw const WavFormatException('WAV 文件缺少必要音频信息。');
    }
    if (format != 1) throw const WavFormatException('当前仅支持 PCM WAV。');
    return _WavInfo(
      channels: channels,
      sampleRate: sampleRate,
      bitsPerSample: bitsPerSample,
      blockAlign: blockAlign,
      dataOffset: dataOffset,
      dataLength: dataLength,
    );
  }

  Uint8List _canonicalWav(_WavInfo info, Uint8List pcm) {
    final output = Uint8List(44 + pcm.length);
    final data = ByteData.sublistView(output);
    output.setAll(0, 'RIFF'.codeUnits);
    data.setUint32(4, 36 + pcm.length, Endian.little);
    output.setAll(8, 'WAVEfmt '.codeUnits);
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, info.channels, Endian.little);
    data.setUint32(24, info.sampleRate, Endian.little);
    data.setUint32(28, info.sampleRate * info.blockAlign, Endian.little);
    data.setUint16(32, info.blockAlign, Endian.little);
    data.setUint16(34, info.bitsPerSample, Endian.little);
    output.setAll(36, 'data'.codeUnits);
    data.setUint32(40, pcm.length, Endian.little);
    output.setAll(44, pcm);
    return output;
  }
}

class _WavInfo {
  const _WavInfo({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.blockAlign,
    required this.dataOffset,
    required this.dataLength,
  });
  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int blockAlign;
  final int dataOffset;
  final int dataLength;
}
