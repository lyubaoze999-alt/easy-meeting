import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:easy_meeting/app_services/processing_pipeline.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/domain/models/configuration.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/processing_job.dart';
import 'package:easy_meeting/domain/summary/summary_service.dart';
import 'package:easy_meeting/domain/transcription/transcription_service.dart';
import 'package:easy_meeting/domain/transcription/wav_slicer.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart';
import 'package:easy_meeting/infrastructure/diagnostics/diagnostic_reporter.dart';
import 'package:easy_meeting/infrastructure/network/openai_compatible_client.dart';
import 'package:easy_meeting/infrastructure/notifications/completion_notifier.dart';
import 'package:easy_meeting/infrastructure/repositories/note_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/processing_job_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  test('concurrent starts create only one persistent processing job', () async {
    final directory = await Directory.systemTemp.createTemp(
      'easy-meeting-pipeline-mutex-test-',
    );
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final client = OpenAICompatibleClient();
    final jobs = LocalProcessingJobRepository(database);
    final pipeline = ProcessingPipeline(
      transcriptionService: TranscriptionService(
        client: client,
        slicer: const WavSlicer(),
      ),
      summaryService: SummaryService(client),
      noteRepository: LocalNoteRepository(
        database,
        Directory('${directory.path}/notes'),
      ),
      jobRepository: jobs,
      diagnostics: LocalDiagnosticReporter(
        File('${directory.path}/events.jsonl'),
        exportDirectory: directory,
      ),
      settingsProvider: () async => const AppSettings(),
    );
    final recording = RecordingResult(
      audioPath: '${directory.path}/meeting.wav',
      startedAt: DateTime.utc(2026, 8, 3),
      duration: const Duration(minutes: 1),
      highlights: const [],
      template: NoteTemplate.builtins.first,
    );

    final first = pipeline.start(recording);
    await expectLater(pipeline.start(recording), throwsStateError);
    await first;

    expect(await jobs.recoverable(), hasLength(1));
    expect(pipeline.stage, ProcessingStage.failed);
    expect(pipeline.currentJob?.failureCode, 'missing_configuration');
  });

  test(
    'retry reuses transcript checkpoint and completes the local workflow',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'easy-meeting-pipeline-test-',
      );
      final database = AppDatabase(NativeDatabase.memory());
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        await database.close();
        await directory.delete(recursive: true);
      });

      var transcriptionRequests = 0;
      var summaryRequests = 0;
      server.listen((request) async {
        await request.drain<void>();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path.endsWith('/audio/transcriptions')) {
          transcriptionRequests += 1;
          request.response.write(jsonEncode({'text': '先确认范围，再完成四端交付。'}));
        } else if (request.uri.path.endsWith('/chat/completions')) {
          summaryRequests += 1;
          if (summaryRequests == 1) {
            request.response.statusCode = HttpStatus.internalServerError;
            request.response.write(jsonEncode({'error': 'temporary'}));
          } else {
            request.response.write(
              jsonEncode({
                'choices': [
                  {
                    'message': {
                      'content': jsonEncode({
                        'title': '四端交付会',
                        'sections': [
                          {
                            'heading': '结论',
                            'content': '完成 Flutter 四端交付',
                            'isHighlighted': true,
                          },
                        ],
                        'todos': [
                          {
                            'text': '完成验收',
                            'done': false,
                            'owner': null,
                            'dueDate': null,
                          },
                        ],
                      }),
                    },
                  },
                ],
              }),
            );
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final client = OpenAICompatibleClient();
      final notes = LocalNoteRepository(
        database,
        Directory('${directory.path}/notes'),
      );
      final jobs = LocalProcessingJobRepository(database);
      final localDiagnostics = LocalDiagnosticReporter(
        File('${directory.path}/events.jsonl'),
        exportDirectory: directory,
      );
      final pipeline = ProcessingPipeline(
        transcriptionService: TranscriptionService(
          client: client,
          slicer: const WavSlicer(maximumDuration: Duration(minutes: 20)),
        ),
        summaryService: SummaryService(client),
        noteRepository: notes,
        jobRepository: jobs,
        diagnostics: _ThrowingAfterWriteReporter(localDiagnostics),
        notifier: const _ThrowingNotifier(),
        settingsProvider: () async => AppSettings(
          transcription: ServiceConfig(
            baseUrl: 'http://${server.address.host}:${server.port}/v1',
            apiKey: 'test-key-never-persisted',
            model: 'mock-transcribe',
          ),
          summary: ServiceConfig(
            baseUrl: 'http://${server.address.host}:${server.port}/v1',
            apiKey: 'test-key-never-persisted',
            model: 'mock-summary',
          ),
        ),
      );
      final audio = await writePcmWav(directory);
      final first = await pipeline.start(
        RecordingResult(
          audioPath: audio.path,
          startedAt: DateTime.utc(2026, 7, 31),
          duration: const Duration(minutes: 3),
          highlights: const [Duration(seconds: 12)],
          template: NoteTemplate.builtins.first,
        ),
      );

      expect(first, isNull);
      expect(pipeline.stage, ProcessingStage.failed);
      expect(
        pipeline.currentJob?.lastSuccessfulStage,
        ProcessingStage.transcribing,
      );
      expect(transcriptionRequests, 1);

      final completed = await pipeline.retry(pipeline.currentJob!.id);
      expect(completed?.title, '四端交付会');
      expect(pipeline.stage, ProcessingStage.done);
      expect(
        transcriptionRequests,
        1,
        reason: 'retry must reuse the atomic transcript checkpoint',
      );
      expect(summaryRequests, 2);
      expect((await notes.list(query: 'Flutter')).single.id, completed?.id);
      expect(await jobs.load(pipeline.currentJob!.id), isNull);
      expect(
        await audio.exists(),
        isFalse,
        reason: 'completed jobs must remove the temporary recording',
      );
      await notes.moveToTrash(completed!.id);
      expect((await notes.listTrash()).single.id, completed.id);
      await notes.restore(completed.id);
      expect((await notes.list()).single.id, completed.id);

      final diagnostics = await File(
        '${directory.path}/events.jsonl',
      ).readAsString();
      expect(diagnostics, isNot(contains('test-key-never-persisted')));
      expect(diagnostics, isNot(contains('先确认范围')));
    },
  );
}

class _ThrowingAfterWriteReporter implements DiagnosticReporter {
  const _ThrowingAfterWriteReporter(this.delegate);
  final DiagnosticReporter delegate;

  @override
  Future<void> record(DiagnosticEvent event) async {
    await delegate.record(event);
    throw StateError('diagnostic storage unavailable');
  }

  @override
  Future<File> exportBundle() => delegate.exportBundle();
}

class _ThrowingNotifier implements CompletionNotifier {
  const _ThrowingNotifier();

  @override
  Future<void> processingCompleted(String title) =>
      throw StateError('notification unavailable');

  @override
  Future<bool> requestPermission() async => false;
}
