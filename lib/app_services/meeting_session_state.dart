import '../domain/models/note_template.dart';

/// The local audio-capture lifecycle.
enum CapturePhase {
  idle,
  starting,
  recording,
  pausing,
  paused,
  resuming,
  stopping,
  finalizingFile,
  recorded,
  failed,
}

/// The optional, best-effort realtime transcript lifecycle.
enum LiveTranscriptPhase {
  disabled,
  connecting,
  streaming,
  reconnecting,
  degraded,
  closing,
  completed,
  failed,
}

/// Work which may continue independently after a recording has been saved.
enum PostProcessingPhase {
  idle,
  queued,
  transcribing,
  freezingTranscript,
  readyToSummarize,
  summarizing,
  persisting,
  completed,
  failed,
}

/// Options frozen when a new local recording starts.
class MeetingStartOptions {
  const MeetingStartOptions({
    this.enableLiveTranscription = false,
    this.template,
  });

  final bool enableLiveTranscription;
  final NoteTemplate? template;
}

/// A snapshot of the three independent meeting lifecycles.
class MeetingSessionState {
  const MeetingSessionState({
    this.capturePhase = CapturePhase.idle,
    this.liveTranscriptPhase = LiveTranscriptPhase.disabled,
    this.postProcessingPhase = PostProcessingPhase.idle,
    this.liveAudioSendingEnabled = false,
    this.captureError,
    this.liveTranscriptError,
    this.postProcessingError,
  });

  final CapturePhase capturePhase;
  final LiveTranscriptPhase liveTranscriptPhase;
  final PostProcessingPhase postProcessingPhase;

  /// The synchronous gate checked before any PCM frame is sent to the network.
  final bool liveAudioSendingEnabled;

  final Object? captureError;
  final Object? liveTranscriptError;
  final Object? postProcessingError;

  bool get hasActiveCapture => switch (capturePhase) {
    CapturePhase.starting ||
    CapturePhase.recording ||
    CapturePhase.pausing ||
    CapturePhase.paused ||
    CapturePhase.resuming ||
    CapturePhase.stopping ||
    CapturePhase.finalizingFile => true,
    CapturePhase.idle || CapturePhase.recorded || CapturePhase.failed => false,
  };

  bool get canStartMeeting => switch (capturePhase) {
    CapturePhase.idle || CapturePhase.recorded || CapturePhase.failed => true,
    _ => false,
  };

  bool get postProcessingInProgress => switch (postProcessingPhase) {
    PostProcessingPhase.queued ||
    PostProcessingPhase.transcribing ||
    PostProcessingPhase.freezingTranscript ||
    PostProcessingPhase.summarizing ||
    PostProcessingPhase.persisting => true,
    _ => false,
  };

  MeetingSessionState copyWith({
    CapturePhase? capturePhase,
    LiveTranscriptPhase? liveTranscriptPhase,
    PostProcessingPhase? postProcessingPhase,
    bool? liveAudioSendingEnabled,
    Object? captureError = _notSpecified,
    Object? liveTranscriptError = _notSpecified,
    Object? postProcessingError = _notSpecified,
  }) => MeetingSessionState(
    capturePhase: capturePhase ?? this.capturePhase,
    liveTranscriptPhase: liveTranscriptPhase ?? this.liveTranscriptPhase,
    postProcessingPhase: postProcessingPhase ?? this.postProcessingPhase,
    liveAudioSendingEnabled:
        liveAudioSendingEnabled ?? this.liveAudioSendingEnabled,
    captureError: identical(captureError, _notSpecified)
        ? this.captureError
        : captureError,
    liveTranscriptError: identical(liveTranscriptError, _notSpecified)
        ? this.liveTranscriptError
        : liveTranscriptError,
    postProcessingError: identical(postProcessingError, _notSpecified)
        ? this.postProcessingError
        : postProcessingError,
  );
}

const Object _notSpecified = Object();
