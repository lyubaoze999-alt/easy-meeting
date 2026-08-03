import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.name,
    required this.timestamp,
    this.stage,
    this.durationMs,
    this.errorCode,
    this.platform,
    this.version,
  });

  final String name;
  final DateTime timestamp;
  final String? stage;
  final int? durationMs;
  final String? errorCode;
  final String? platform;
  final String? version;

  Map<String, Object?> toJson() => {
    'name': name,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'stage': stage,
    'durationMs': durationMs,
    'errorCode': errorCode,
    'platform': platform,
    'version': version,
  };
}

abstract interface class DiagnosticReporter {
  Future<void> record(DiagnosticEvent event);
  Future<File> exportBundle();
}

class LocalDiagnosticReporter implements DiagnosticReporter {
  LocalDiagnosticReporter(this.logFile, {this.exportDirectory});
  final File logFile;
  final Directory? exportDirectory;

  static Future<LocalDiagnosticReporter> open() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(root.path, 'EasyMeeting', 'Diagnostics'),
    );
    await directory.create(recursive: true);
    return LocalDiagnosticReporter(
      File(p.join(directory.path, 'events.jsonl')),
    );
  }

  @override
  Future<void> record(DiagnosticEvent event) async {
    final line = '${jsonEncode(event.toJson())}\n';
    await logFile.writeAsString(line, mode: FileMode.append, flush: true);
    await _rotateIfNeeded();
  }

  @override
  Future<File> exportBundle() async {
    final root = exportDirectory ?? await getTemporaryDirectory();
    await root.create(recursive: true);
    final output = File(
      p.join(
        root.path,
        'easy-meeting-diagnostics-${DateTime.now().millisecondsSinceEpoch}.zip',
      ),
    );
    final archive = Archive();
    if (await logFile.exists()) {
      final bytes = await logFile.readAsBytes();
      archive.addFile(ArchiveFile('events.jsonl', bytes.length, bytes));
    }
    final manifest = utf8.encode(
      jsonEncode({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'privacy': '不包含 API 密钥、接口参数、转写文本、纪要正文或音频。',
      }),
    );
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    await output.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    return output;
  }

  Future<void> _rotateIfNeeded() async {
    if (!await logFile.exists() || await logFile.length() < 2 * 1024 * 1024) {
      return;
    }
    final lines = await logFile.readAsLines();
    final retained = lines.skip(lines.length ~/ 2).join('\n');
    await logFile.writeAsString('$retained\n', flush: true);
  }
}
