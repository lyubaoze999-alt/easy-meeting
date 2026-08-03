import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:easy_meeting/domain/models/configuration.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/platform_profile.dart';
import 'package:easy_meeting/infrastructure/diagnostics/diagnostic_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meeting note JSON round trip preserves text and visuals', () {
    final note = MeetingNote(
      id: 'note-1',
      title: '产品评审',
      startedAt: DateTime.utc(2026, 7, 31, 8),
      duration: const Duration(minutes: 42),
      audioPath: '/private/audio.wav',
      transcriptPath: '/private/transcript.txt',
      templateId: 'builtin.review',
      sections: const [
        NoteSection(heading: '结论', content: '保留全部正文', isHighlighted: true),
      ],
      todos: const [
        TodoItem(text: '完成四端验收', owner: '小王', dueDate: '2026-08-10'),
      ],
      highlights: const [Duration(seconds: 12)],
      visuals: const NoteVisuals(
        timeline: [TimelineNode(time: '00:12', title: '确认范围')],
        keyNumbers: [KeyNumber(label: '端', value: '4')],
      ),
    );

    final decoded = MeetingNote.decode(note.encode());
    expect(decoded.title, note.title);
    expect(decoded.sections.single.content, '保留全部正文');
    expect(decoded.visuals?.timeline?.single.title, '确认范围');
    expect(decoded.visuals?.keyNumbers?.single.value, '4');
  });

  test('public configuration never serializes an API key', () {
    const secret = 'sk-never-export-this';
    const config = ServiceConfig(
      baseUrl: 'https://example.test/v1',
      model: 'model-a',
      apiKey: secret,
    );
    expect(jsonEncode(config.toPublicJson()), isNot(contains(secret)));
    expect(config.toPublicJson().keys, isNot(contains('apiKey')));
  });

  test('macOS compatibility falls back to microphone before 14.4', () {
    final legacy = PlatformProfile.resolve(
      platform: PlatformKind.macos,
      operatingSystemVersion: 'Version 14.3.1 (Build 23D60)',
    );
    final processTap = PlatformProfile.resolve(
      platform: PlatformKind.macos,
      operatingSystemVersion: 'Version 14.4 (Build 23E214)',
    );
    final future = PlatformProfile.resolve(
      platform: PlatformKind.macos,
      operatingSystemVersion: 'Version 26.5.2 (Build 25F84)',
    );

    expect(legacy.audio, AudioCapability.micOnly);
    expect(processTap.audio, AudioCapability.dualSource);
    expect(future.audio, AudioCapability.dualSource);
  });

  test(
    'diagnostic bundle contains only the allowlisted event fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'easy-meeting-diagnostic-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final log = File('${directory.path}/events.jsonl');
      final reporter = LocalDiagnosticReporter(log, exportDirectory: directory);
      await reporter.record(
        DiagnosticEvent(
          name: 'processing_failed',
          timestamp: DateTime.utc(2026, 7, 31),
          stage: 'summarizing',
          errorCode: 'network_error',
          platform: 'test',
          version: '1.0.0',
        ),
      );

      final bundle = await reporter.exportBundle();
      addTearDown(() async {
        if (await bundle.exists()) await bundle.delete();
      });
      final archive = ZipDecoder().decodeBytes(await bundle.readAsBytes());
      final names = archive.files.map((file) => file.name).toSet();
      expect(names, {'events.jsonl', 'manifest.json'});
      final event = utf8.decode(
        archive.findFile('events.jsonl')!.content as List<int>,
      );
      expect(event, contains('network_error'));
      expect(event, isNot(contains('apiKey')));
      expect(event, isNot(contains('transcript')));
      expect(event, isNot(contains('会议正文')));
    },
  );
}
