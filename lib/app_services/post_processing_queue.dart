import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/configuration.dart';
import '../domain/models/meeting_note.dart';
import '../domain/models/note_template.dart';
import '../domain/models/processing_job.dart';
import '../domain/models/transcript_document.dart';
import '../domain/summary/summary_service.dart';
import '../domain/transcription/transcription_service.dart';
import '../infrastructure/repositories/meeting_repository.dart';
import '../infrastructure/repositories/note_repository.dart';
import '../infrastructure/repositories/processing_job_repository.dart';
import '../infrastructure/repositories/recording_repository.dart';
import '../infrastructure/repositories/transcript_repository.dart';

typedef FileTranscriptionWorker =
    Future<String> Function({
      required File audio,
      required Directory workingDirectory,
      required ServiceConfig config,
      TranscriptionProgress? onProgress,
    });

typedef NoteSummaryWorker =
    Future<MeetingNote> Function({
      required String transcript,
      required NoteTemplate template,
      required List<Duration> highlights,
      required bool imageMode,
      required ServiceConfig config,
      required SummaryContext context,
    });

typedef QueueClock = DateTime Function();
typedef QueueIdFactory = String Function();

/// A durable, serial queue for independent file-transcription and summary work.
///
/// Recording finalization never calls this service. Callers explicitly enqueue
/// one job type, and a completed transcription never enqueues a summary.
class PostProcessingQueue extends ChangeNotifier {
  PostProcessingQueue({
    required this.meetingRepository,
    required this.recordingRepository,
    required this.transcriptRepository,
    required this.noteRepository,
    required this.jobRepository,
    required this.settingsProvider,
    required this.transcribe,
    required this.summarize,
    this.workingDirectory,
    this.autoStart = true,
    QueueClock? clock,
    QueueIdFactory? idFactory,
  }) : clock = clock ?? DateTime.now,
       idFactory = idFactory ?? const Uuid().v4;

  factory PostProcessingQueue.fromServices({
    required MeetingRepository meetingRepository,
    required RecordingRepository recordingRepository,
    required TranscriptRepository transcriptRepository,
    required NoteRepository noteRepository,
    required ProcessingJobRepository jobRepository,
    required Future<AppSettings> Function() settingsProvider,
    required TranscriptionService transcriptionService,
    required SummaryService summaryService,
    Directory? workingDirectory,
    bool autoStart = true,
  }) => PostProcessingQueue(
    meetingRepository: meetingRepository,
    recordingRepository: recordingRepository,
    transcriptRepository: transcriptRepository,
    noteRepository: noteRepository,
    jobRepository: jobRepository,
    settingsProvider: settingsProvider,
    transcribe:
        ({
          required audio,
          required workingDirectory,
          required config,
          onProgress,
        }) => transcriptionService.transcribe(
          audio,
          workingDirectory,
          config,
          onProgress: onProgress,
        ),
    summarize:
        ({
          required transcript,
          required template,
          required highlights,
          required imageMode,
          required config,
          required context,
        }) => summaryService.summarize(
          transcript: transcript,
          template: template,
          highlights: highlights,
          imageMode: imageMode,
          config: config,
          context: context,
        ),
    workingDirectory: workingDirectory,
    autoStart: autoStart,
  );

  final MeetingRepository meetingRepository;
  final RecordingRepository recordingRepository;
  final TranscriptRepository transcriptRepository;
  final NoteRepository noteRepository;
  final ProcessingJobRepository jobRepository;
  final Future<AppSettings> Function() settingsProvider;
  final FileTranscriptionWorker transcribe;
  final NoteSummaryWorker summarize;
  final Directory? workingDirectory;
  final bool autoStart;
  final QueueClock clock;
  final QueueIdFactory idFactory;

  Future<void> _mutationTail = Future<void>.value();
  Future<void>? _drainFuture;
  bool _drainRequested = false;
  bool _stopRequested = false;

  ProcessingJob? currentJob;
  bool get isRunning => currentJob != null;
  bool get hasPendingWork =>
      currentJob != null || _drainFuture != null || _drainRequested;

  Future<ProcessingJob> enqueueTranscript(String meetingId) =>
      _withMutation(() async {
        _throwIfStopping();
        await _ensureNoDuplicate(meetingId, JobType.transcriptFull);
        final meeting = await meetingRepository.load(meetingId);
        if (meeting == null || meeting.deletedAt != null) {
          throw StateError('Meeting does not exist or is trashed.');
        }
        final recording = await recordingRepository.loadForMeeting(meetingId);
        if (recording == null) {
          throw StateError('A finalized recording is required.');
        }
        final now = clock();
        final job = ProcessingJob(
          id: idFactory(),
          audioPath: recording.path,
          template: meeting.templateSnapshot,
          startedAt: meeting.startedAt,
          duration: recording.duration,
          highlights: List<Duration>.unmodifiable(meeting.highlights),
          stage: ProcessingStage.saving,
          updatedAt: now,
          meetingId: meetingId,
          jobType: JobType.transcriptFull,
          checkpoint: const {
            'postProcessingStage': 'queued',
            'checkpointVersion': 1,
          },
        );
        await jobRepository.save(job);
        _scheduleDrainIfEnabled();
        return job;
      });

  Future<ProcessingJob> enqueueSummary(String meetingId, String transcriptId) =>
      _withMutation(() async {
        _throwIfStopping();
        await _ensureNoDuplicate(meetingId, JobType.noteSummary);
        final meeting = await meetingRepository.load(meetingId);
        if (meeting == null || meeting.deletedAt != null) {
          throw StateError('Meeting does not exist or is trashed.');
        }
        final transcript = await transcriptRepository.load(transcriptId);
        await _validateFrozenTranscript(
          transcript,
          meetingId: meetingId,
          transcriptId: transcriptId,
        );
        final bodyPath = transcript!.bodyPath!;
        if (!await File(bodyPath).exists()) {
          throw StateError('The final transcript body is unavailable.');
        }
        final recording = await recordingRepository.loadForMeeting(meetingId);
        final settings = await settingsProvider();
        final now = clock();
        final job = ProcessingJob(
          id: idFactory(),
          audioPath: recording?.path ?? '',
          template: meeting.templateSnapshot,
          startedAt: meeting.startedAt,
          duration: meeting.duration,
          highlights: List<Duration>.unmodifiable(meeting.highlights),
          stage: ProcessingStage.saving,
          updatedAt: now,
          transcriptPath: bodyPath,
          meetingId: meetingId,
          jobType: JobType.noteSummary,
          checkpoint: {
            'postProcessingStage': PostProcessingStage.queued.name,
            'checkpointVersion': 1,
            'transcriptId': transcriptId,
            'transcriptRevision': transcript.revision,
            'imageMode': settings.imageMode,
          },
        );
        await jobRepository.save(job);
        _scheduleDrainIfEnabled();
        return job;
      });

  Future<ProcessingJob> retry(String jobId) => _withMutation(() async {
    _throwIfStopping();
    final job = await jobRepository.load(jobId);
    if (job == null) throw StateError('Post-processing job does not exist.');
    if (job.postProcessingStage != PostProcessingStage.failed) {
      throw StateError('Only a failed post-processing job can be retried.');
    }
    final retried = _withPostStage(
      job,
      PostProcessingStage.queued,
      retryCount: job.retryCount + 1,
      clearFailure: true,
    );
    await jobRepository.save(retried);
    _scheduleDrainIfEnabled();
    return retried;
  });

  Future<bool> cancelQueued(String jobId) => _withMutation(() async {
    final job = await jobRepository.load(jobId);
    if (job == null || job.postProcessingStage != PostProcessingStage.queued) {
      return false;
    }
    final cancelled = _withPostStage(
      job,
      PostProcessingStage.cancelled,
      failureCode: 'cancelled',
      failureMessage: '任务已取消。',
    );
    await jobRepository.save(cancelled);
    return true;
  });

  /// Restores queued or interrupted jobs and waits for the queue to become idle.
  Future<void> resumePending() async {
    _scheduleDrain();
    await waitUntilIdle();
  }

  Future<void> waitUntilIdle() async {
    while (true) {
      final drain = _drainFuture;
      if (drain == null) return;
      await drain;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> checkpointAndStop() async {
    _stopRequested = true;
    _drainRequested = false;
    await _mutationTail;
  }

  void _scheduleDrainIfEnabled() {
    if (autoStart) _scheduleDrain();
  }

  void _scheduleDrain() {
    if (_stopRequested) return;
    if (_drainFuture != null) {
      _drainRequested = true;
      return;
    }
    _drainRequested = false;
    notifyListeners();
    late final Future<void> scheduled;
    scheduled = Future<void>.microtask(_drain);
    _drainFuture = scheduled;
    unawaited(
      scheduled
          .whenComplete(() {
            if (identical(_drainFuture, scheduled)) _drainFuture = null;
            if (_drainRequested) _scheduleDrain();
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _drain() async {
    while (!_stopRequested) {
      final job = await _claimNext();
      if (job == null) return;
      currentJob = job;
      notifyListeners();
      try {
        await _run(job);
      } catch (error) {
        if (error is! _PostProcessingPaused) {
          await _recordFailure(job, error);
        }
      } finally {
        currentJob = null;
        notifyListeners();
      }
    }
  }

  Future<ProcessingJob?> _claimNext() => _withMutation(() async {
    final candidates =
        (await jobRepository.recoverable())
            .where(
              (job) =>
                  job.jobType != null &&
                  job.postProcessingStage != null &&
                  job.postProcessingStage != PostProcessingStage.failed &&
                  job.postProcessingStage != PostProcessingStage.cancelled,
            )
            .toList()
          ..sort((left, right) => left.updatedAt.compareTo(right.updatedAt));
    if (candidates.isEmpty) return null;
    final claimed = _withPostStage(
      candidates.first,
      PostProcessingStage.preparing,
    );
    await jobRepository.save(claimed);
    return claimed;
  });

  Future<void> _run(ProcessingJob job) async {
    switch (job.jobType) {
      case JobType.transcriptFull:
      case JobType.transcriptRepair:
        await _runTranscript(job);
      case JobType.noteSummary:
        await _runSummary(job);
      case null:
        throw const _PostProcessingFailure('invalid_job_type', '后处理任务类型无效。');
    }
  }

  Future<void> _runTranscript(ProcessingJob initial) async {
    _throwIfStopping();
    final meetingId = initial.meetingId;
    if (meetingId == null) {
      throw const _PostProcessingFailure('meeting_missing', '后处理任务缺少会议引用。');
    }
    final recording = await recordingRepository.loadForMeeting(meetingId);
    if (recording == null) {
      throw const _PostProcessingFailure(
        'recording_missing',
        '录音资产不存在，无法执行文件转写。',
      );
    }
    final audio = File(recording.path);
    if (!await audio.exists()) {
      throw const _PostProcessingFailure(
        'recording_file_missing',
        '录音文件不存在，无法执行文件转写。',
      );
    }
    final settings = await settingsProvider();
    if (!settings.transcription.isConfigured) {
      throw const _PostProcessingFailure(
        'missing_transcription_configuration',
        '请先完成文件转写服务配置。',
      );
    }

    var job = initial;
    final work = _workDirectory(job);
    await work.create(recursive: true);
    final draft = File(p.join(work.path, 'transcript.txt'));
    String transcript;
    if (job.lastSuccessfulStage == ProcessingStage.transcribing &&
        job.transcriptPath != null &&
        await File(job.transcriptPath!).exists()) {
      transcript = await File(job.transcriptPath!).readAsString();
    } else {
      job = await _checkpoint(job, PostProcessingStage.uploading);
      _throwIfStopping();
      var currentSlice = 0;
      var totalSlices = 0;
      transcript = await transcribe(
        audio: audio,
        workingDirectory: Directory(p.join(work.path, 'slices')),
        config: settings.transcription,
        onProgress: (current, total) {
          currentSlice = current;
          totalSlices = total;
        },
      );
      _throwIfStopping();
      if (transcript.trim().isEmpty) {
        throw const _PostProcessingFailure('empty_transcript', '转写服务没有返回文字。');
      }
      await _writeAtomic(draft, transcript);
      job = await _checkpoint(
        job.copyWith(
          transcriptPath: draft.path,
          checkpoint: {
            ...job.checkpoint,
            'currentSlice': currentSlice,
            'totalSlices': totalSlices,
          },
        ),
        PostProcessingStage.processing,
        successfulStage: ProcessingStage.transcribing,
      );
    }

    var revision = job.checkpoint['transcriptRevision'] as int?;
    job = await _checkpoint(job, PostProcessingStage.persisting);
    _throwIfStopping();
    final BatchFinalTranscriptRepository writer;
    if (transcriptRepository case final BatchFinalTranscriptRepository batch) {
      writer = batch;
    } else {
      throw const _PostProcessingFailure(
        'batch_transcript_unsupported',
        '当前转写仓储不支持文件转写结果持久化。',
      );
    }
    final saved =
        revision == null &&
            transcriptRepository is RevisionAllocatingTranscriptRepository
        ? await (transcriptRepository as RevisionAllocatingTranscriptRepository)
              .saveBatchFinalNext(
                meetingId: meetingId,
                body: transcript,
                coveredDuration: recording.duration,
                idempotencyKey: job.id,
                providerProtocol: 'openaiCompatibleFile',
                model: settings.transcription.model,
              )
        : await writer.saveBatchFinal(
            meetingId: meetingId,
            body: transcript,
            revision:
                revision ??
                ((await transcriptRepository.finalForMeeting(
                          meetingId,
                        ))?.revision ??
                        0) +
                    1,
            coveredDuration: recording.duration,
            providerProtocol: 'openaiCompatibleFile',
            model: settings.transcription.model,
          );
    _throwIfStopping();
    revision = saved.revision;
    await _checkpoint(
      job.copyWith(
        checkpoint: {
          ...job.checkpoint,
          'transcriptId': saved.id,
          'transcriptRevision': saved.revision,
        },
      ),
      PostProcessingStage.done,
      successfulStage: ProcessingStage.persisting,
    );
  }

  Future<void> _runSummary(ProcessingJob initial) async {
    _throwIfStopping();
    final meetingId = initial.meetingId;
    final transcriptId = initial.checkpoint['transcriptId'] as String?;
    final revision = initial.checkpoint['transcriptRevision'] as int?;
    if (meetingId == null || transcriptId == null || revision == null) {
      throw const _PostProcessingFailure(
        'summary_input_missing',
        '总结任务缺少固定的正式转写版本。',
      );
    }
    final frozen = await transcriptRepository.load(transcriptId);
    await _validateFrozenTranscript(
      frozen,
      meetingId: meetingId,
      transcriptId: transcriptId,
      revision: revision,
    );
    final transcriptFile = File(frozen!.bodyPath!);
    if (!await transcriptFile.exists()) {
      throw const _PostProcessingFailure(
        'transcript_file_missing',
        '正式转写正文不存在，无法生成纪要。',
      );
    }
    // Read the frozen body before starting the provider call. A newer revision
    // created while summarization is in flight cannot change this job's input.
    final transcript = await transcriptFile.readAsString();
    final settings = await settingsProvider();
    if (!settings.summary.isConfigured) {
      throw const _PostProcessingFailure(
        'missing_summary_configuration',
        '请先完成总结服务配置。',
      );
    }

    var job = initial;
    final work = _workDirectory(job);
    await work.create(recursive: true);
    final draft = File(p.join(work.path, 'note_draft.json'));
    MeetingNote note;
    if (job.lastSuccessfulStage == ProcessingStage.summarizing &&
        await draft.exists()) {
      note = MeetingNote.decode(await draft.readAsString());
    } else {
      job = await _checkpoint(job, PostProcessingStage.processing);
      _throwIfStopping();
      note = await summarize(
        transcript: transcript,
        template: job.template,
        highlights: job.highlights,
        imageMode: job.checkpoint['imageMode'] == true,
        config: settings.summary,
        context: SummaryContext(
          noteId: job.noteId,
          startedAt: job.startedAt,
          duration: job.duration,
          audioPath: job.audioPath,
          transcriptPath: transcriptFile.path,
        ),
      );
      _throwIfStopping();
      note = note.copyWith(
        audioPath: job.audioPath,
        transcriptPath: transcriptFile.path,
        meetingId: meetingId,
        transcriptId: transcriptId,
      );
      await _writeAtomic(draft, note.encode());
      job = await _checkpoint(
        job.copyWith(noteId: note.id),
        PostProcessingStage.processing,
        successfulStage: ProcessingStage.summarizing,
      );
    }

    final currentMeeting = await meetingRepository.load(meetingId);
    if (currentMeeting == null || currentMeeting.deletedAt != null) {
      throw const _PostProcessingFailure(
        'meeting_trashed_during_processing',
        '会议已移入回收站，本次纪要未保存。',
      );
    }
    job = await _checkpoint(job, PostProcessingStage.persisting);
    _throwIfStopping();
    final saved = await noteRepository.save(note);
    await _checkpoint(
      job.copyWith(noteId: saved.id),
      PostProcessingStage.done,
      successfulStage: ProcessingStage.persisting,
    );
  }

  Future<void> _validateFrozenTranscript(
    TranscriptDocument? transcript, {
    required String meetingId,
    required String transcriptId,
    int? revision,
  }) async {
    if (transcript == null ||
        transcript.id != transcriptId ||
        transcript.meetingId != meetingId ||
        transcript.kind != TranscriptKind.finalTranscript ||
        transcript.status != TranscriptStatus.ready ||
        transcript.deletedAt != null ||
        transcript.bodyPath == null ||
        (revision != null && transcript.revision != revision)) {
      throw StateError(
        'Summary requires the requested ready final transcript revision.',
      );
    }
  }

  Future<ProcessingJob> _checkpoint(
    ProcessingJob job,
    PostProcessingStage stage, {
    ProcessingStage? successfulStage,
  }) async {
    _throwIfStopping();
    final updated = _withPostStage(
      job,
      stage,
      lastSuccessfulStage: successfulStage,
      clearFailure: true,
    );
    await jobRepository.save(updated);
    currentJob = updated;
    notifyListeners();
    return updated;
  }

  Future<void> _recordFailure(ProcessingJob claimed, Object error) async {
    final latest = await jobRepository.load(claimed.id) ?? claimed;
    final controlled = error is _PostProcessingFailure ? error : null;
    final failed = _withPostStage(
      latest,
      PostProcessingStage.failed,
      failureCode: controlled?.code ?? _errorCode(error),
      failureMessage: controlled?.message ?? '后处理失败，请检查服务配置或稍后重试。',
    );
    await jobRepository.save(failed);
    currentJob = failed;
    notifyListeners();
  }

  ProcessingJob _withPostStage(
    ProcessingJob job,
    PostProcessingStage postStage, {
    ProcessingStage? lastSuccessfulStage,
    int? retryCount,
    String? failureCode,
    String? failureMessage,
    bool clearFailure = false,
  }) => job.copyWith(
    stage: _legacyStage(job.jobType, postStage),
    lastSuccessfulStage: lastSuccessfulStage,
    updatedAt: clock(),
    retryCount: retryCount,
    failureCode: failureCode,
    failureMessage: failureMessage,
    clearFailure: clearFailure,
    checkpoint: {...job.checkpoint, 'postProcessingStage': postStage.name},
  );

  static ProcessingStage _legacyStage(
    JobType? type,
    PostProcessingStage stage,
  ) => switch (stage) {
    PostProcessingStage.queued ||
    PostProcessingStage.preparing => ProcessingStage.saving,
    PostProcessingStage.uploading || PostProcessingStage.processing =>
      type == JobType.noteSummary
          ? ProcessingStage.summarizing
          : ProcessingStage.transcribing,
    PostProcessingStage.persisting => ProcessingStage.persisting,
    PostProcessingStage.done => ProcessingStage.done,
    PostProcessingStage.failed ||
    PostProcessingStage.cancelled => ProcessingStage.failed,
  };

  Future<void> _ensureNoDuplicate(String meetingId, JobType type) async {
    final existing = (await jobRepository.recoverable()).where(
      (job) =>
          job.meetingId == meetingId &&
          _sameJobKind(job.jobType, type) &&
          job.postProcessingStage != PostProcessingStage.failed &&
          job.postProcessingStage != PostProcessingStage.cancelled,
    );
    if (existing.isNotEmpty) {
      throw StateError(
        'This meeting already has an unfinished ${type.name} job.',
      );
    }
  }

  void _throwIfStopping() {
    if (_stopRequested) throw const _PostProcessingPaused();
  }

  static bool _sameJobKind(JobType? left, JobType right) {
    if (left == right) return true;
    final leftIsTranscript =
        left == JobType.transcriptFull || left == JobType.transcriptRepair;
    final rightIsTranscript =
        right == JobType.transcriptFull || right == JobType.transcriptRepair;
    return leftIsTranscript && rightIsTranscript;
  }

  Directory _workDirectory(ProcessingJob job) {
    final root = workingDirectory;
    if (root != null) return Directory(p.join(root.path, job.id));
    final anchor = job.audioPath.isNotEmpty
        ? File(job.audioPath)
        : File(job.transcriptPath ?? 'post-processing');
    return Directory(p.join(anchor.parent.path, '.post_processing', job.id));
  }

  Future<T> _withMutation<T>(Future<T> Function() action) async {
    final previous = _mutationTail;
    final release = Completer<void>();
    _mutationTail = release.future;
    await previous;
    try {
      return await action();
    } finally {
      release.complete();
    }
  }

  static Future<void> _writeAtomic(File target, String contents) async {
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  static String _errorCode(Object error) => error.runtimeType
      .toString()
      .replaceAll(RegExp('[^A-Za-z0-9_]'), '_')
      .toLowerCase();
}

class _PostProcessingFailure implements Exception {
  const _PostProcessingFailure(this.code, this.message);

  final String code;
  final String message;
}

class _PostProcessingPaused implements Exception {
  const _PostProcessingPaused();
}
