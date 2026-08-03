import 'dart:async';

import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:easy_meeting/app_services/meeting_session_controller.dart';
import 'package:easy_meeting/app_services/meeting_session_state.dart';
import 'package:easy_meeting/app_services/processing_pipeline.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/processing_job.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_client.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('double start takes the capture lock before the first await', () async {
    final capture = _FakeMeetingCapturePort();
    final startGate = capture.delayNextStart();
    final harness = _Harness(capture: capture);
    addTearDown(harness.dispose);
    await harness.session.initialize();

    final firstStart = harness.session.startRecording();
    expect(harness.session.state.capturePhase, CapturePhase.starting);
    expect(harness.session.captureCommandInFlight, isTrue);
    expect(() => harness.session.startRecording(), throwsStateError);
    expect(capture.startCalls, 1);

    startGate.complete();
    await firstStart;
    expect(harness.session.state.capturePhase, CapturePhase.recording);
    expect(harness.session.captureCommandInFlight, isFalse);
  });

  test(
    'old post-processing and a new recording occupy independent axes',
    () async {
      final processing = _FakeProcessingPipeline.withPendingRecovery();
      final capture = _FakeMeetingCapturePort();
      final harness = _Harness(capture: capture, processing: processing);
      addTearDown(harness.dispose);

      final initialization = harness.session.initialize();
      await processing.recoveryStarted.future;
      expect(
        harness.session.state.postProcessingPhase,
        PostProcessingPhase.transcribing,
      );
      expect(harness.session.state.capturePhase, CapturePhase.idle);

      await harness.session.startRecording();
      expect(capture.startCalls, 1);
      expect(harness.session.state.capturePhase, CapturePhase.recording);
      expect(
        harness.session.state.postProcessingPhase,
        PostProcessingPhase.transcribing,
      );

      processing.finishRecoveryAsFailed();
      await initialization;
      expect(harness.session.state.capturePhase, CapturePhase.recording);
      expect(
        harness.session.state.postProcessingPhase,
        PostProcessingPhase.failed,
      );
    },
  );

  test('realtime connect failure degrades only the live axis', () async {
    final capture = _FakeMeetingCapturePort();
    final live = _FakeLiveTranscriptPort()..delayConnect();
    final harness = _Harness(capture: capture, live: live);
    addTearDown(harness.dispose);
    await harness.session.initialize();

    await harness.session.startMeeting(
      const MeetingStartOptions(enableLiveTranscription: true),
    );
    expect(harness.session.state.capturePhase, CapturePhase.recording);
    expect(
      harness.session.state.liveTranscriptPhase,
      LiveTranscriptPhase.connecting,
    );

    live.connectGate!.completeError(
      const RealtimeClientException(
        code: 'network_unavailable',
        message: 'network unavailable',
        isRetryable: true,
      ),
    );
    await _flushAsyncWork();

    expect(harness.session.state.capturePhase, CapturePhase.recording);
    expect(
      harness.session.state.liveTranscriptPhase,
      LiveTranscriptPhase.degraded,
    );
    expect(harness.session.state.liveAudioSendingEnabled, isFalse);
    expect(capture.stopCalls, 0);
  });

  test(
    'pause and resume synchronously close and reopen the PCM send gate',
    () async {
      final capture = _FakeMeetingCapturePort();
      final live = _FakeLiveTranscriptPort();
      final harness = _Harness(capture: capture, live: live);
      addTearDown(harness.dispose);
      await harness.session.initialize();
      await harness.session.startMeeting(
        const MeetingStartOptions(enableLiveTranscription: true),
      );
      await _flushAsyncWork();

      expect(
        harness.session.state.liveTranscriptPhase,
        LiveTranscriptPhase.streaming,
      );
      expect(await harness.session.sendRealtimeAudio(_frame(0)), isTrue);
      expect(live.sendCalls, 1);

      final pauseGate = capture.delayNextPause();
      final pause = harness.session.pauseRecording();
      expect(harness.session.state.capturePhase, CapturePhase.pausing);
      expect(harness.session.state.liveAudioSendingEnabled, isFalse);
      expect(await harness.session.sendRealtimeAudio(_frame(1)), isFalse);
      expect(live.sendCalls, 1);
      pauseGate.complete();
      await pause;
      expect(harness.session.state.capturePhase, CapturePhase.paused);

      final resumeGate = capture.delayNextResume();
      final resume = harness.session.resumeRecording();
      expect(harness.session.state.capturePhase, CapturePhase.resuming);
      expect(harness.session.state.liveAudioSendingEnabled, isFalse);
      resumeGate.complete();
      await resume;
      expect(harness.session.state.capturePhase, CapturePhase.recording);
      expect(harness.session.state.liveAudioSendingEnabled, isTrue);
      expect(await harness.session.sendRealtimeAudio(_frame(2)), isTrue);
      expect(live.sendCalls, 2);
    },
  );

  test(
    'stop saves recording without starting transcription or summary',
    () async {
      final capture = _FakeMeetingCapturePort();
      final processing = _FakeProcessingPipeline();
      final harness = _Harness(capture: capture, processing: processing);
      addTearDown(harness.dispose);
      await harness.session.initialize();
      await harness.session.startRecording();
      final transitions = <CapturePhase>[];
      harness.session.addListener(
        () => transitions.add(harness.session.state.capturePhase),
      );
      final stopGate = capture.delayNextStop();

      final stop = harness.session.stopRecording();
      expect(harness.session.state.capturePhase, CapturePhase.stopping);
      expect(harness.session.state.liveAudioSendingEnabled, isFalse);
      expect(processing.startCalls, 0);
      stopGate.complete(_recording());
      final saved = await stop;

      expect(saved.audioPath, '/tmp/session-recording.wav');
      expect(
        transitions,
        containsAllInOrder(<CapturePhase>[
          CapturePhase.stopping,
          CapturePhase.finalizingFile,
          CapturePhase.recorded,
        ]),
      );
      expect(harness.session.state.capturePhase, CapturePhase.recorded);
      expect(processing.startCalls, 0);
      expect(processing.currentJob, isNull);
    },
  );

  test(
    'saved recording permits the next meeting while live close is pending',
    () async {
      final capture = _FakeMeetingCapturePort();
      final live = _FakeLiveTranscriptPort()..delayClose();
      final processing = _FakeProcessingPipeline();
      final harness = _Harness(
        capture: capture,
        processing: processing,
        live: live,
      );
      addTearDown(harness.dispose);
      await harness.session.initialize();
      await harness.session.startMeeting(
        const MeetingStartOptions(enableLiveTranscription: true),
      );
      await _flushAsyncWork();

      final first = await harness.session.stopRecording();
      expect(first.audioPath, '/tmp/session-recording.wav');
      expect(live.closeCalls, 1);
      expect(live.closeGate!.isCompleted, isFalse);
      expect(harness.session.state.capturePhase, CapturePhase.recorded);

      await harness.session.startRecording();
      expect(capture.resetCalls, 1);
      expect(capture.startCalls, 2);
      expect(harness.session.state.capturePhase, CapturePhase.recording);
      expect(processing.startCalls, 0);

      live.closeGate!.complete();
      await _flushAsyncWork();
      expect(harness.session.state.capturePhase, CapturePhase.recording);
    },
  );

  test('legacy stopAndProcess is a stop-only compatibility alias', () async {
    final capture = _FakeMeetingCapturePort();
    final processing = _FakeProcessingPipeline();
    final harness = _Harness(capture: capture, processing: processing);
    addTearDown(harness.dispose);
    await harness.session.initialize();
    await harness.session.startRecording();

    await harness.session.stopAndProcess();

    expect(harness.session.state.capturePhase, CapturePhase.recorded);
    expect(processing.startCalls, 0);
  });
}

class _Harness {
  _Harness({
    required MeetingCapturePort capture,
    _FakeProcessingPipeline? processing,
    MeetingLiveTranscriptPort? live,
  }) : recording = RecordingCoordinator(
         capture: AudioCapture(platform: _PassiveCapturePlatform()),
       ),
       processing = processing ?? _FakeProcessingPipeline() {
    session = MeetingSessionController(
      recording: recording,
      processing: this.processing,
      capturePort: capture,
      liveTranscript: live,
    );
  }

  final RecordingCoordinator recording;
  final _FakeProcessingPipeline processing;
  late final MeetingSessionController session;

  void dispose() {
    session.dispose();
    recording.dispose();
    processing.dispose();
  }
}

class _FakeMeetingCapturePort implements MeetingCapturePort {
  Completer<void>? _startGate;
  Completer<void>? _pauseGate;
  Completer<void>? _resumeGate;
  Completer<RecordingResult>? _stopGate;
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int resetCalls = 0;

  Completer<void> delayNextStart() => _startGate = Completer<void>();

  Completer<void> delayNextPause() => _pauseGate = Completer<void>();

  Completer<void> delayNextResume() => _resumeGate = Completer<void>();

  Completer<RecordingResult> delayNextStop() =>
      _stopGate = Completer<RecordingResult>();

  @override
  Future<void> start() async {
    startCalls += 1;
    final gate = _startGate;
    _startGate = null;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    final gate = _pauseGate;
    _pauseGate = null;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    final gate = _resumeGate;
    _resumeGate = null;
    if (gate != null) await gate.future;
  }

  @override
  Future<RecordingResult> stopAndSave() async {
    stopCalls += 1;
    final gate = _stopGate;
    _stopGate = null;
    return gate == null ? _recording() : gate.future;
  }

  @override
  void reset() {
    resetCalls += 1;
  }

  @override
  void addHighlight() {}

  @override
  void selectTemplate(NoteTemplate template) {}
}

class _FakeLiveTranscriptPort implements MeetingLiveTranscriptPort {
  final StreamController<RealtimeTranscriptEvent> _events =
      StreamController<RealtimeTranscriptEvent>.broadcast(sync: true);
  Completer<void>? connectGate;
  Completer<void>? closeGate;
  Object? sendError;
  int connectCalls = 0;
  int sendCalls = 0;
  int closeCalls = 0;
  int abortCalls = 0;

  void delayConnect() {
    connectGate = Completer<void>();
  }

  void delayClose() {
    closeGate = Completer<void>();
  }

  @override
  Stream<RealtimeTranscriptEvent> get events => _events.stream;

  @override
  Future<void> connect() async {
    connectCalls += 1;
    final gate = connectGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> send(RealtimeAudioFrame frame) async {
    sendCalls += 1;
    final error = sendError;
    if (error != null) throw error;
  }

  @override
  Future<void> commitTurn() async {}

  @override
  Future<void> close() async {
    closeCalls += 1;
    final gate = closeGate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> abort() async {
    abortCalls += 1;
    await _events.close();
  }
}

class _PassiveCapturePlatform extends AudioCapturePlatform {
  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Stream<AudioFrame> get pcmFrames => const Stream.empty();

  @override
  Future<Map<String, Object?>> start() async => const <String, Object?>{};

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async => '/tmp/passive.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async =>
      const <String, Object?>{};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

class _FakeProcessingPipeline extends ChangeNotifier
    implements ProcessingPipelinePort {
  _FakeProcessingPipeline() : _recoveryGate = null;

  _FakeProcessingPipeline.withPendingRecovery()
    : _recoveryGate = Completer<void>(),
      currentJob = _job(ProcessingStage.transcribing);

  final Completer<void> recoveryStarted = Completer<void>();
  final Completer<void>? _recoveryGate;
  int startCalls = 0;

  @override
  ProcessingJob? currentJob;

  @override
  MeetingNote? generatedNote;

  @override
  int currentSlice = 0;

  @override
  int totalSlices = 0;

  @override
  bool isRunning = false;

  @override
  ProcessingStage get stage => currentJob?.stage ?? ProcessingStage.done;

  @override
  String? get errorMessage => currentJob?.failureMessage;

  @override
  Future<MeetingNote?> resumeLatest() async {
    final gate = _recoveryGate;
    if (gate == null) return null;
    isRunning = true;
    notifyListeners();
    if (!recoveryStarted.isCompleted) recoveryStarted.complete();
    await gate.future;
    isRunning = false;
    notifyListeners();
    return null;
  }

  @override
  Future<MeetingNote?> start(RecordingResult recording) async {
    startCalls += 1;
    return null;
  }

  void finishRecoveryAsFailed() {
    currentJob = _job(
      ProcessingStage.failed,
      failureMessage: 'mock recovery failure',
    );
    _recoveryGate!.complete();
  }

  @override
  Future<MeetingNote?> retry(String jobId) async => null;

  @override
  Future<void> abandonCurrent() async {
    currentJob = null;
    generatedNote = null;
    notifyListeners();
  }
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

RealtimeAudioFrame _frame(int sequence) => RealtimeAudioFrame(
  sessionId: 'native-session',
  sequence: sequence,
  startSample: sequence * 4800,
  sampleRate: 24000,
  channels: 1,
  bytes: Uint8List(9600),
);

RecordingResult _recording() => RecordingResult(
  audioPath: '/tmp/session-recording.wav',
  startedAt: DateTime.utc(2026, 8, 3),
  duration: const Duration(minutes: 1),
  highlights: const <Duration>[],
  template: NoteTemplate.builtins.first,
);

ProcessingJob _job(ProcessingStage stage, {String? failureMessage}) =>
    ProcessingJob(
      id: 'job-1',
      audioPath: '/tmp/session-recording.wav',
      template: NoteTemplate.builtins.first,
      startedAt: DateTime.utc(2026, 8, 3),
      duration: const Duration(minutes: 1),
      highlights: const <Duration>[],
      stage: stage,
      updatedAt: DateTime.utc(2026, 8, 3),
      failureMessage: failureMessage,
    );
