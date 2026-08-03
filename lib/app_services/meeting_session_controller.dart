import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/note_template.dart';
import '../domain/models/processing_job.dart';
import '../domain/realtime/realtime_transcription_client.dart';
import '../domain/realtime/realtime_transcription_events.dart';
import 'meeting_session_state.dart';
import 'processing_pipeline.dart';
import 'post_processing_queue.dart';
import 'recording_coordinator.dart';

/// The narrow capture contract used by the session state machine.
///
/// Keeping the coordinator behind this port makes command serialization
/// testable without coupling the state machine to a native audio plugin.
abstract interface class MeetingCapturePort {
  Future<void> start();
  Future<void> pause();
  Future<void> resume();
  Future<RecordingResult> stopAndSave();
  void reset();
  void addHighlight();
  void selectTemplate(NoteTemplate template);
}

abstract interface class PendingCaptureFinalizationPort {
  bool get hasPendingFinalization;
}

final class RecordingCoordinatorMeetingCapturePort
    implements MeetingCapturePort {
  const RecordingCoordinatorMeetingCapturePort(this.coordinator);

  final RecordingCoordinator coordinator;

  @override
  Future<void> start() => coordinator.start();

  @override
  Future<void> pause() => coordinator.pause();

  @override
  Future<void> resume() => coordinator.resume();

  @override
  Future<RecordingResult> stopAndSave() => coordinator.stop();

  @override
  void reset() => coordinator.reset();

  @override
  void addHighlight() => coordinator.addHighlight();

  @override
  void selectTemplate(NoteTemplate template) =>
      coordinator.selectTemplate(template);
}

/// A meeting-scoped realtime port. Configuration is bound by the adapter so
/// the state machine does not depend on a provider-specific network client.
abstract interface class MeetingLiveTranscriptPort {
  Stream<RealtimeTranscriptEvent> get events;
  Future<void> connect();
  Future<void> send(RealtimeAudioFrame frame);
  Future<void> commitTurn();
  Future<void> close();
  Future<void> abort();
}

/// Optional gate implemented by managed realtime sessions which consume the
/// native PCM stream directly instead of receiving frames through [send].
abstract interface class MeetingLiveAudioGatePort {
  void onCapturePaused();
  void onCaptureResumed();
}

abstract interface class PendingLiveFinalizationPort {
  bool get hasPendingFinalization;
  Future<void> drain();
}

final class RealtimeTranscriptionClientMeetingPort
    implements MeetingLiveTranscriptPort {
  const RealtimeTranscriptionClientMeetingPort({
    required this.client,
    required this.config,
  });

  final RealtimeTranscriptionClient client;
  final RealtimeTranscriptionConfig config;

  @override
  Stream<RealtimeTranscriptEvent> get events => client.events;

  @override
  Future<void> connect() => client.connect(config);

  @override
  Future<void> send(RealtimeAudioFrame frame) => client.append(frame);

  @override
  Future<void> commitTurn() => client.commitTurn();

  @override
  Future<void> close() => client.flushAndClose();

  @override
  Future<void> abort() => client.abort();
}

/// Compatibility projection for callers which have not migrated to [state].
enum MeetingSessionPhase {
  initializing,
  ready,
  starting,
  recording,
  pausing,
  paused,
  resuming,
  stopping,
  processing,
  completed,
  failed,
}

class MeetingSessionController extends ChangeNotifier {
  MeetingSessionController({
    required this.recording,
    required this.processing,
    MeetingCapturePort? capturePort,
    MeetingLiveTranscriptPort? liveTranscript,
    PostProcessingQueue? postProcessingQueue,
  }) : _capture =
           capturePort ?? RecordingCoordinatorMeetingCapturePort(recording),
       _liveTranscript = liveTranscript,
       _postProcessingQueue = postProcessingQueue {
    recording.addListener(_forwardRecordingChange);
    processing.addListener(_forwardLegacyProcessingChange);
    postProcessingQueue?.addListener(_syncTypedPostProcessing);
    _liveEvents = liveTranscript?.events.listen(_handleLiveEvent);
  }

  /// Retained while the current UI migrates to the port/state APIs.
  final RecordingCoordinator recording;

  /// Retained for legacy, explicit post-processing actions only.
  final ProcessingPipelinePort processing;

  final MeetingCapturePort _capture;
  final MeetingLiveTranscriptPort? _liveTranscript;
  final PostProcessingQueue? _postProcessingQueue;
  StreamSubscription<RealtimeTranscriptEvent>? _liveEvents;

  MeetingSessionState _state = const MeetingSessionState();
  bool _captureCommandInFlight = false;
  bool _postProcessingCommandInFlight = false;
  bool _initialized = false;
  bool _liveEnabledForMeeting = false;
  bool _acceptLiveEvents = false;
  int _meetingGeneration = 0;
  Future<void>? _liveCloseFuture;
  RecordingResult? _lastRecording;

  MeetingSessionState get state => _state;
  RecordingResult? get lastRecording => _lastRecording;
  ProcessingStage get processingStage => processing.stage;
  bool get captureCommandInFlight => _captureCommandInFlight;
  bool get postProcessingCommandInFlight => _postProcessingCommandInFlight;
  bool get commandInFlight =>
      _captureCommandInFlight || _postProcessingCommandInFlight;
  Object? get lastError =>
      _state.captureError ??
      _state.postProcessingError ??
      _state.liveTranscriptError;

  /// A temporary view for the old UI. Capture always wins over old background
  /// work, so a recoverable job cannot hide or lock the next recording.
  MeetingSessionPhase get phase {
    if (!_initialized) return MeetingSessionPhase.initializing;
    return switch (_state.capturePhase) {
      CapturePhase.idle => MeetingSessionPhase.ready,
      CapturePhase.starting => MeetingSessionPhase.starting,
      CapturePhase.recording => MeetingSessionPhase.recording,
      CapturePhase.pausing => MeetingSessionPhase.pausing,
      CapturePhase.paused => MeetingSessionPhase.paused,
      CapturePhase.resuming => MeetingSessionPhase.resuming,
      CapturePhase.stopping ||
      CapturePhase.finalizingFile => MeetingSessionPhase.stopping,
      CapturePhase.recorded => MeetingSessionPhase.completed,
      CapturePhase.failed => MeetingSessionPhase.failed,
    };
  }

  bool get blocksExit =>
      _state.hasActiveCapture ||
      _captureCommandInFlight ||
      (_liveTranscript is PendingLiveFinalizationPort &&
          (_liveTranscript as PendingLiveFinalizationPort)
              .hasPendingFinalization);

  /// Resumes old post-processing independently; capture is available as soon
  /// as this method is invoked and is not protected by the post-processing lock.
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    _initialized = true;
    // Typed jobs are the sole post-processing executor in the product path.
    // Do not let the retained legacy pipeline race it or overwrite its state.
    if (_postProcessingQueue != null) return Future<void>.value();
    _beginPostProcessingCommand(PostProcessingPhase.queued);
    return _initializePostProcessing();
  }

  Future<void> _initializePostProcessing() async {
    try {
      await processing.resumeLatest();
      _syncPostProcessing();
    } catch (error) {
      _setState(
        _state.copyWith(
          postProcessingPhase: PostProcessingPhase.failed,
          postProcessingError: error,
        ),
      );
      rethrow;
    } finally {
      _endPostProcessingCommand();
    }
  }

  Future<void> startMeeting(MeetingStartOptions options) {
    _beginCaptureCommand(
      const {CapturePhase.idle, CapturePhase.recorded, CapturePhase.failed},
      CapturePhase.starting,
      liveAudioSendingEnabled: false,
    );
    return _startMeeting(options);
  }

  Future<void> _startMeeting(MeetingStartOptions options) async {
    final generation = ++_meetingGeneration;
    _liveEnabledForMeeting = false;
    try {
      if (_lastRecording != null) {
        _capture.reset();
        _lastRecording = null;
      }
      final template = options.template;
      if (template != null) _capture.selectTemplate(template);
      await _capture.start();
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.recording,
          captureError: null,
        ),
      );

      final live = _liveTranscript;
      if (options.enableLiveTranscription && live != null) {
        _liveEnabledForMeeting = true;
        _acceptLiveEvents = _liveCloseFuture == null;
        _setState(
          _state.copyWith(
            liveTranscriptPhase: LiveTranscriptPhase.connecting,
            liveAudioSendingEnabled: false,
            liveTranscriptError: null,
          ),
        );
        unawaited(_connectLiveTranscript(generation, live));
      } else {
        _setState(
          _state.copyWith(
            liveTranscriptPhase: LiveTranscriptPhase.disabled,
            liveAudioSendingEnabled: false,
            liveTranscriptError: null,
          ),
        );
      }
    } catch (error) {
      _liveEnabledForMeeting = false;
      _acceptLiveEvents = false;
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.failed,
          liveTranscriptPhase: LiveTranscriptPhase.disabled,
          liveAudioSendingEnabled: false,
          captureError: error,
        ),
      );
      rethrow;
    } finally {
      _endCaptureCommand();
    }
  }

  /// Legacy shorthand: starts a local-only meeting.
  Future<void> startRecording() => startMeeting(const MeetingStartOptions());

  Future<void> pauseRecording() {
    _beginCaptureCommand(
      const {CapturePhase.recording},
      CapturePhase.pausing,
      liveAudioSendingEnabled: false,
    );
    final live = _liveTranscript;
    _asLiveAudioGate(live)?.onCapturePaused();
    return _pauseRecording();
  }

  Future<void> _pauseRecording() async {
    try {
      await _capture.pause();
      _setState(_state.copyWith(capturePhase: CapturePhase.paused));
    } catch (error) {
      final live = _liveTranscript;
      _asLiveAudioGate(live)?.onCaptureResumed();
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.recording,
          liveAudioSendingEnabled: _canOpenLiveAudioGate,
          captureError: error,
        ),
      );
      rethrow;
    } finally {
      _endCaptureCommand();
    }
  }

  Future<void> resumeRecording() {
    _beginCaptureCommand(
      const {CapturePhase.paused},
      CapturePhase.resuming,
      liveAudioSendingEnabled: false,
    );
    return _resumeRecording();
  }

  Future<void> _resumeRecording() async {
    try {
      await _capture.resume();
      final live = _liveTranscript;
      _asLiveAudioGate(live)?.onCaptureResumed();
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.recording,
          liveAudioSendingEnabled: _canOpenLiveAudioGate,
          captureError: null,
        ),
      );
    } catch (error) {
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.paused,
          liveAudioSendingEnabled: false,
          captureError: error,
        ),
      );
      rethrow;
    } finally {
      _endCaptureCommand();
    }
  }

  Future<RecordingResult> stopRecording() {
    final previous = _state.capturePhase;
    final canRetryFinalization =
        _capture is PendingCaptureFinalizationPort &&
        (_capture as PendingCaptureFinalizationPort).hasPendingFinalization;
    _beginCaptureCommand(
      {
        CapturePhase.recording,
        CapturePhase.paused,
        if (canRetryFinalization) ...{
          CapturePhase.finalizingFile,
          CapturePhase.failed,
        },
      },
      CapturePhase.stopping,
      liveAudioSendingEnabled: false,
    );
    return _stopRecording(previous);
  }

  Future<RecordingResult> _stopRecording(CapturePhase previous) async {
    final generation = _meetingGeneration;
    final live = _liveTranscript;

    try {
      final save = _capture.stopAndSave();
      // Preserve a synchronously observable `stopping` transition, then expose
      // the durable-file/database finalization window while the save is pending.
      await Future<void>.value();
      _setState(_state.copyWith(capturePhase: CapturePhase.finalizingFile));
      final result = await save;
      _lastRecording = result;
      _asLiveAudioGate(live)?.onCapturePaused();
      _liveEnabledForMeeting = false;
      _acceptLiveEvents = false;
      if (live != null &&
          _state.liveTranscriptPhase != LiveTranscriptPhase.disabled) {
        _setState(
          _state.copyWith(
            liveTranscriptPhase: LiveTranscriptPhase.closing,
            liveAudioSendingEnabled: false,
          ),
        );
        // Native capture is fully stopped before realtime input is closed, so
        // the final PCM frames are not cut off. Network flush remains detached
        // from durable local-file finalization.
        final closeFuture = _closeLiveTranscript(generation, live);
        _liveCloseFuture = closeFuture;
        unawaited(closeFuture);
      }
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.recorded,
          captureError: null,
        ),
      );
      return result;
    } catch (error) {
      final persistencePending =
          _capture is PendingCaptureFinalizationPort &&
          (_capture as PendingCaptureFinalizationPort).hasPendingFinalization;
      _setState(
        _state.copyWith(
          capturePhase: persistencePending
              ? CapturePhase.finalizingFile
              : previous,
          liveAudioSendingEnabled: false,
          captureError: error,
        ),
      );
      rethrow;
    } finally {
      _endCaptureCommand();
    }
  }

  /// Kept for source compatibility. It deliberately does not start
  /// transcription or summarization.
  Future<void> stopAndProcess() async {
    await stopRecording();
  }

  /// Sends a PCM frame only when the synchronous capture gate is open.
  /// Realtime failures are recorded on their own axis and never escape into
  /// the local recording command path.
  Future<bool> sendRealtimeAudio(RealtimeAudioFrame frame) {
    final live = _liveTranscript;
    if (live == null ||
        !_state.liveAudioSendingEnabled ||
        _state.capturePhase != CapturePhase.recording ||
        _state.liveTranscriptPhase != LiveTranscriptPhase.streaming) {
      return Future<bool>.value(false);
    }
    final generation = _meetingGeneration;
    return _sendRealtimeAudio(generation, live, frame);
  }

  Future<bool> _sendRealtimeAudio(
    int generation,
    MeetingLiveTranscriptPort live,
    RealtimeAudioFrame frame,
  ) async {
    try {
      await live.send(frame);
      return true;
    } catch (error) {
      if (generation == _meetingGeneration && _liveEnabledForMeeting) {
        _setState(
          _state.copyWith(
            liveTranscriptPhase: LiveTranscriptPhase.degraded,
            liveAudioSendingEnabled: false,
            liveTranscriptError: error,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _connectLiveTranscript(
    int generation,
    MeetingLiveTranscriptPort live,
  ) async {
    try {
      final previousClose = _liveCloseFuture;
      if (previousClose != null) await previousClose;
      if (generation != _meetingGeneration || !_liveEnabledForMeeting) return;
      _acceptLiveEvents = true;
      await live.connect();
      if (generation != _meetingGeneration || !_liveEnabledForMeeting) return;
      _setState(
        _state.copyWith(
          liveTranscriptPhase: LiveTranscriptPhase.streaming,
          liveAudioSendingEnabled:
              _state.capturePhase == CapturePhase.recording,
          liveTranscriptError: null,
        ),
      );
    } catch (error) {
      if (generation != _meetingGeneration || !_liveEnabledForMeeting) return;
      final retryable = _isRetryableLiveError(error);
      // Managed realtime controllers keep retrying in the background. Keep
      // accepting their typed connection events so a later success can move
      // the UI from degraded back to streaming.
      _acceptLiveEvents = retryable;
      _setState(
        _state.copyWith(
          liveTranscriptPhase: retryable
              ? LiveTranscriptPhase.degraded
              : LiveTranscriptPhase.failed,
          liveAudioSendingEnabled: false,
          liveTranscriptError: error,
        ),
      );
    }
  }

  Future<void> _closeLiveTranscript(
    int generation,
    MeetingLiveTranscriptPort live,
  ) async {
    try {
      await live.close();
      if (generation != _meetingGeneration) return;
      _setState(
        _state.copyWith(liveTranscriptPhase: LiveTranscriptPhase.completed),
      );
    } catch (error) {
      if (generation != _meetingGeneration) return;
      _setState(
        _state.copyWith(
          liveTranscriptPhase: LiveTranscriptPhase.failed,
          liveTranscriptError: error,
        ),
      );
    }
  }

  Future<void> retryProcessing() {
    if (_postProcessingCommandInFlight) {
      throw StateError('上一项会后处理操作尚未完成，请稍候。');
    }
    final job = processing.currentJob;
    if (job == null) throw StateError('没有可重试的处理任务。');
    _beginPostProcessingCommand(_postPhaseForStage(job.stage));
    return _retryProcessing(job.id);
  }

  Future<void> _retryProcessing(String jobId) async {
    try {
      await processing.retry(jobId);
      _syncPostProcessing();
    } catch (error) {
      _setState(
        _state.copyWith(
          postProcessingPhase: PostProcessingPhase.failed,
          postProcessingError: error,
        ),
      );
      rethrow;
    } finally {
      _endPostProcessingCommand();
    }
  }

  /// Resets only capture. Old post-processing remains owned by its queue.
  Future<void> prepareNextMeeting() {
    _beginCaptureCommand(
      const {CapturePhase.idle, CapturePhase.recorded, CapturePhase.failed},
      CapturePhase.idle,
      liveAudioSendingEnabled: false,
    );
    try {
      _capture.reset();
      _lastRecording = null;
      _setState(
        _state.copyWith(
          capturePhase: CapturePhase.idle,
          liveTranscriptPhase: LiveTranscriptPhase.disabled,
          liveAudioSendingEnabled: false,
          captureError: null,
          liveTranscriptError: null,
        ),
      );
      return Future<void>.value();
    } catch (error) {
      _setState(
        _state.copyWith(capturePhase: CapturePhase.failed, captureError: error),
      );
      return Future<void>.error(error);
    } finally {
      _endCaptureCommand();
    }
  }

  void markHighlight() {
    _requireCapturePhase(const {CapturePhase.recording, CapturePhase.paused});
    _capture.addHighlight();
  }

  void addHighlight() => markHighlight();

  void selectTemplate(NoteTemplate template) {
    _requireCapturePhase(const {
      CapturePhase.idle,
      CapturePhase.recording,
      CapturePhase.paused,
      CapturePhase.recorded,
    });
    _capture.selectTemplate(template);
  }

  void _beginCaptureCommand(
    Set<CapturePhase> allowed,
    CapturePhase transition, {
    bool? liveAudioSendingEnabled,
  }) {
    if (_captureCommandInFlight) {
      throw StateError('上一项录音操作尚未完成，请稍候。');
    }
    _requireCapturePhase(allowed);
    _captureCommandInFlight = true;
    _setState(
      _state.copyWith(
        capturePhase: transition,
        liveAudioSendingEnabled: liveAudioSendingEnabled,
        captureError: null,
      ),
    );
  }

  void _endCaptureCommand() {
    _captureCommandInFlight = false;
    notifyListeners();
  }

  void _beginPostProcessingCommand(PostProcessingPhase transition) {
    if (_postProcessingCommandInFlight) {
      throw StateError('上一项会后处理操作尚未完成，请稍候。');
    }
    _postProcessingCommandInFlight = true;
    _setState(
      _state.copyWith(
        postProcessingPhase: transition,
        postProcessingError: null,
      ),
    );
  }

  void _endPostProcessingCommand() {
    _postProcessingCommandInFlight = false;
    notifyListeners();
  }

  void _syncPostProcessing() {
    if (_postProcessingQueue != null) return;
    final job = processing.currentJob;
    _setState(
      _state.copyWith(
        postProcessingPhase: job == null
            ? PostProcessingPhase.idle
            : _postPhaseForStage(job.stage),
        postProcessingError: job?.failureMessage,
      ),
    );
  }

  void _syncTypedPostProcessing() {
    final queue = _postProcessingQueue;
    final job = queue?.currentJob;
    if (job == null) return;
    final stage = job.postProcessingStage;
    final phase = switch (stage) {
      PostProcessingStage.queued ||
      PostProcessingStage.preparing => PostProcessingPhase.queued,
      PostProcessingStage.uploading || PostProcessingStage.processing =>
        job.jobType == JobType.noteSummary
            ? PostProcessingPhase.summarizing
            : PostProcessingPhase.transcribing,
      PostProcessingStage.persisting => PostProcessingPhase.persisting,
      PostProcessingStage.done => PostProcessingPhase.completed,
      PostProcessingStage.failed => PostProcessingPhase.failed,
      PostProcessingStage.cancelled || null => PostProcessingPhase.idle,
    };
    _setState(
      _state.copyWith(
        postProcessingPhase: phase,
        postProcessingError: job.failureMessage,
      ),
    );
  }

  static PostProcessingPhase _postPhaseForStage(ProcessingStage stage) =>
      switch (stage) {
        ProcessingStage.saving => PostProcessingPhase.queued,
        ProcessingStage.transcribing => PostProcessingPhase.transcribing,
        ProcessingStage.summarizing => PostProcessingPhase.summarizing,
        ProcessingStage.persisting => PostProcessingPhase.persisting,
        ProcessingStage.done => PostProcessingPhase.completed,
        ProcessingStage.failed => PostProcessingPhase.failed,
      };

  bool get _canOpenLiveAudioGate =>
      _liveEnabledForMeeting &&
      _state.liveTranscriptPhase == LiveTranscriptPhase.streaming;

  static bool _isRetryableLiveError(Object error) =>
      error is RealtimeClientException && error.isRetryable;

  static MeetingLiveAudioGatePort? _asLiveAudioGate(
    MeetingLiveTranscriptPort? live,
  ) => live is MeetingLiveAudioGatePort
      ? live as MeetingLiveAudioGatePort
      : null;

  void _handleLiveEvent(RealtimeTranscriptEvent event) {
    if (!_acceptLiveEvents || !_liveEnabledForMeeting) return;
    if (event is TranscriptServiceError) {
      _setState(
        _state.copyWith(
          liveTranscriptPhase: event.isRetryable && _state.hasActiveCapture
              ? LiveTranscriptPhase.degraded
              : LiveTranscriptPhase.failed,
          liveAudioSendingEnabled: false,
          liveTranscriptError: event,
        ),
      );
      return;
    }
    if (event is! TranscriptConnectionChanged) return;
    final phase = switch (event.state) {
      RealtimeConnectionState.connecting =>
        _state.liveTranscriptPhase == LiveTranscriptPhase.connecting
            ? LiveTranscriptPhase.connecting
            : LiveTranscriptPhase.reconnecting,
      RealtimeConnectionState.connected => LiveTranscriptPhase.streaming,
      RealtimeConnectionState.closing => LiveTranscriptPhase.closing,
      RealtimeConnectionState.closed =>
        _state.hasActiveCapture
            ? LiveTranscriptPhase.degraded
            : LiveTranscriptPhase.completed,
      RealtimeConnectionState.disconnected =>
        _state.hasActiveCapture
            ? LiveTranscriptPhase.reconnecting
            : LiveTranscriptPhase.disabled,
      RealtimeConnectionState.failed =>
        _state.hasActiveCapture
            ? LiveTranscriptPhase.degraded
            : LiveTranscriptPhase.failed,
    };
    _setState(
      _state.copyWith(
        liveTranscriptPhase: phase,
        liveAudioSendingEnabled:
            phase == LiveTranscriptPhase.streaming &&
            _state.capturePhase == CapturePhase.recording,
      ),
    );
  }

  void _requireCapturePhase(Set<CapturePhase> allowed) {
    if (!allowed.contains(_state.capturePhase)) {
      throw StateError('当前录音状态“${_state.capturePhase.name}”不允许执行此操作。');
    }
  }

  void _setState(MeetingSessionState value) {
    _state = value;
    notifyListeners();
  }

  void _forwardRecordingChange() => notifyListeners();

  void _forwardLegacyProcessingChange() {
    _syncPostProcessing();
  }

  @override
  void dispose() {
    recording.removeListener(_forwardRecordingChange);
    processing.removeListener(_forwardLegacyProcessingChange);
    _postProcessingQueue?.removeListener(_syncTypedPostProcessing);
    final liveEvents = _liveEvents;
    _liveEvents = null;
    if (liveEvents != null) unawaited(liveEvents.cancel());
    final live = _liveTranscript;
    if (live != null) unawaited(live.abort());
    super.dispose();
  }
}
