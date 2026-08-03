import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../domain/models/configuration.dart';
import '../domain/models/meeting_note.dart';
import '../domain/models/processing_job.dart';
import '../domain/summary/summary_service.dart';
import '../domain/transcription/transcription_service.dart';
import '../infrastructure/diagnostics/diagnostic_reporter.dart';
import '../infrastructure/notifications/completion_notifier.dart';
import '../infrastructure/repositories/note_repository.dart';
import '../infrastructure/repositories/processing_job_repository.dart';
import 'recording_coordinator.dart';

class ProcessingPipeline extends ChangeNotifier {
  ProcessingPipeline({
    required this.transcriptionService,
    required this.summaryService,
    required this.noteRepository,
    required this.jobRepository,
    required this.diagnostics,
    required this.settingsProvider,
    this.notifier = const NoopCompletionNotifier(),
  });

  final TranscriptionService transcriptionService;
  final SummaryService summaryService;
  final NoteRepository noteRepository;
  final ProcessingJobRepository jobRepository;
  final DiagnosticReporter diagnostics;
  final CompletionNotifier notifier;
  final Future<AppSettings> Function() settingsProvider;

  ProcessingJob? currentJob;
  MeetingNote? generatedNote;
  int currentSlice = 0;
  int totalSlices = 0;
  bool isRunning = false;

  ProcessingStage get stage => currentJob?.stage ?? ProcessingStage.done;
  String? get errorMessage => currentJob?.failureMessage;

  Future<MeetingNote?> start(RecordingResult recording) async {
    final now = DateTime.now();
    final job = ProcessingJob(
      id: const Uuid().v4(),
      audioPath: recording.audioPath,
      template: recording.template,
      startedAt: recording.startedAt,
      duration: recording.duration,
      highlights: recording.highlights,
      stage: ProcessingStage.saving,
      updatedAt: now,
    );
    await jobRepository.save(job);
    return _run(job);
  }

  Future<MeetingNote?> retry(String jobId) async {
    final job = await jobRepository.load(jobId);
    if (job == null) return null;
    return _run(
      job.copyWith(
        stage: _resumeStage(job),
        updatedAt: DateTime.now(),
        retryCount: job.retryCount + 1,
        clearFailure: true,
      ),
    );
  }

  Future<List<ProcessingJob>> recoverableJobs() => jobRepository.recoverable();

  Future<void> abandonCurrent() async {
    final job = currentJob;
    if (job == null || isRunning) return;
    final work = Directory(
      p.join(File(job.audioPath).parent.path, 'job_${job.id}'),
    );
    await jobRepository.delete(job.id);
    if (await work.exists()) await work.delete(recursive: true);
    currentJob = null;
    generatedNote = null;
    notifyListeners();
  }

  Future<MeetingNote?> resumeLatest() async {
    final pending = await recoverableJobs();
    if (pending.isEmpty || isRunning) return null;
    final job = pending.first;
    final settings = await settingsProvider();
    if (!settings.servicesConfigured) {
      currentJob = job.copyWith(
        stage: ProcessingStage.failed,
        updatedAt: DateTime.now(),
        failureCode: 'missing_configuration',
        failureMessage: '发现未完成任务。请完成服务配置后，从上次成功阶段重试。',
      );
      await jobRepository.save(currentJob!);
      notifyListeners();
      return null;
    }
    return retry(job.id);
  }

  Future<MeetingNote?> _run(ProcessingJob initial) async {
    if (isRunning) return null;
    isRunning = true;
    generatedNote = null;
    currentJob = initial;
    notifyListeners();
    final started = DateTime.now();
    try {
      final settings = await settingsProvider();
      if (!settings.servicesConfigured) {
        throw const _PipelineFailure('missing_configuration', '请先配置转写服务和总结服务。');
      }
      var job = initial;
      final audio = File(job.audioPath);
      if (!await audio.exists()) {
        throw const _PipelineFailure('audio_missing', '录音文件不存在，无法继续处理。');
      }

      if (_rank(job.lastSuccessfulStage) < _rank(ProcessingStage.saving)) {
        job = await _checkpoint(job, ProcessingStage.saving, successful: true);
      }

      String transcript;
      if (job.transcriptPath != null &&
          await File(job.transcriptPath!).exists() &&
          _rank(job.lastSuccessfulStage) >=
              _rank(ProcessingStage.transcribing)) {
        transcript = await File(job.transcriptPath!).readAsString();
      } else {
        job = await _checkpoint(job, ProcessingStage.transcribing);
        final work = Directory(p.join(audio.parent.path, 'job_${job.id}'));
        await work.create(recursive: true);
        transcript = await transcriptionService.transcribe(
          audio,
          Directory(p.join(work.path, 'slices')),
          settings.transcription,
          onProgress: (current, total) {
            currentSlice = current;
            totalSlices = total;
            notifyListeners();
          },
        );
        final transcriptFile = File(p.join(work.path, 'transcript.txt'));
        await _writeAtomic(transcriptFile, transcript);
        job = await _checkpoint(
          job.copyWith(transcriptPath: transcriptFile.path),
          ProcessingStage.transcribing,
          successful: true,
        );
      }

      final work = Directory(p.join(audio.parent.path, 'job_${job.id}'));
      await work.create(recursive: true);
      final draftFile = File(p.join(work.path, 'note_draft.json'));
      MeetingNote note;
      if (_rank(job.lastSuccessfulStage) >=
              _rank(ProcessingStage.summarizing) &&
          await draftFile.exists()) {
        note = MeetingNote.decode(await draftFile.readAsString());
      } else {
        job = await _checkpoint(job, ProcessingStage.summarizing);
        note = await summaryService.summarize(
          transcript: transcript,
          template: job.template,
          highlights: job.highlights,
          imageMode: settings.imageMode,
          config: settings.summary,
          context: SummaryContext(
            noteId: job.noteId,
            startedAt: job.startedAt,
            duration: job.duration,
            audioPath: job.audioPath,
            transcriptPath: job.transcriptPath!,
          ),
        );
        await _writeAtomic(draftFile, note.encode());
        job = await _checkpoint(
          job.copyWith(noteId: note.id),
          ProcessingStage.summarizing,
          successful: true,
        );
      }

      job = await _checkpoint(
        job.copyWith(noteId: note.id),
        ProcessingStage.persisting,
      );
      generatedNote = await noteRepository.save(
        note,
        audioSource: audio,
        transcript: transcript,
      );
      job = await _checkpoint(
        job.copyWith(noteId: generatedNote!.id),
        ProcessingStage.done,
        successful: true,
      );
      currentJob = job;
      await _cleanupCompletedArtifacts(job, audio);
      try {
        await diagnostics.record(
          DiagnosticEvent(
            name: 'processing_completed',
            timestamp: DateTime.now(),
            stage: job.stage.name,
            durationMs: DateTime.now().difference(started).inMilliseconds,
            platform: Platform.operatingSystem,
          ),
        );
      } catch (_) {
        // Diagnostics are best-effort and must never roll back a saved note.
      }
      try {
        await notifier.processingCompleted(generatedNote!.title);
      } catch (_) {
        try {
          await diagnostics.record(
            DiagnosticEvent(
              name: 'notification_failed',
              timestamp: DateTime.now(),
              stage: ProcessingStage.done.name,
              platform: Platform.operatingSystem,
            ),
          );
        } catch (_) {
          // Notification and diagnostic failures are non-fatal side effects.
        }
      }
      notifyListeners();
      return generatedNote;
    } catch (error) {
      final failure = error is _PipelineFailure
          ? error
          : _PipelineFailure(_errorCode(error), _safeMessage(error));
      final failed = (currentJob ?? initial).copyWith(
        stage: ProcessingStage.failed,
        updatedAt: DateTime.now(),
        failureCode: failure.code,
        failureMessage: failure.message,
      );
      currentJob = failed;
      await jobRepository.save(failed);
      try {
        await diagnostics.record(
          DiagnosticEvent(
            name: 'processing_failed',
            timestamp: DateTime.now(),
            stage: failed.lastSuccessfulStage?.name,
            errorCode: failure.code,
            durationMs: DateTime.now().difference(started).inMilliseconds,
            platform: Platform.operatingSystem,
          ),
        );
      } catch (_) {
        // The persisted processing failure remains the source of truth.
      }
      notifyListeners();
      return null;
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  Future<ProcessingJob> _checkpoint(
    ProcessingJob job,
    ProcessingStage stage, {
    bool successful = false,
  }) async {
    final updated = job.copyWith(
      stage: stage,
      lastSuccessfulStage: successful ? stage : job.lastSuccessfulStage,
      updatedAt: DateTime.now(),
      clearFailure: true,
    );
    currentJob = updated;
    await jobRepository.save(updated);
    notifyListeners();
    return updated;
  }

  static ProcessingStage _resumeStage(ProcessingJob job) {
    return switch (job.lastSuccessfulStage) {
      null => ProcessingStage.saving,
      ProcessingStage.saving => ProcessingStage.transcribing,
      ProcessingStage.transcribing => ProcessingStage.summarizing,
      ProcessingStage.summarizing => ProcessingStage.persisting,
      _ => ProcessingStage.saving,
    };
  }

  static int _rank(ProcessingStage? stage) => switch (stage) {
    null => -1,
    ProcessingStage.saving => 0,
    ProcessingStage.transcribing => 1,
    ProcessingStage.summarizing => 2,
    ProcessingStage.persisting => 3,
    ProcessingStage.done => 4,
    ProcessingStage.failed => -1,
  };

  static Future<void> _writeAtomic(File target, String contents) async {
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  Future<void> _cleanupCompletedArtifacts(ProcessingJob job, File audio) async {
    try {
      await jobRepository.delete(job.id);
      final work = Directory(p.join(audio.parent.path, 'job_${job.id}'));
      if (await work.exists()) await work.delete(recursive: true);
      if (await audio.exists() && audio.path != generatedNote?.audioPath) {
        await audio.delete();
      }
    } catch (_) {
      try {
        await diagnostics.record(
          DiagnosticEvent(
            name: 'completed_artifact_cleanup_failed',
            timestamp: DateTime.now(),
            stage: ProcessingStage.done.name,
            platform: Platform.operatingSystem,
          ),
        );
      } catch (_) {
        // Cleanup and diagnostics are both best-effort after durable save.
      }
    }
  }

  static String _errorCode(Object error) => error.runtimeType
      .toString()
      .replaceAll(RegExp('[^A-Za-z0-9_]'), '_')
      .toLowerCase();

  static String _safeMessage(Object error) {
    final message = error.toString();
    if (message.contains('api') || message.contains('Bearer')) {
      return '服务请求失败，请检查配置后重试。';
    }
    return message.length > 240 ? '${message.substring(0, 240)}…' : message;
  }
}

class _PipelineFailure implements Exception {
  const _PipelineFailure(this.code, this.message);
  final String code;
  final String message;
}
