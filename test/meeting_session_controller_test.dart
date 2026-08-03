import 'dart:async';

import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:easy_meeting/app_services/meeting_session_controller.dart';
import 'package:easy_meeting/app_services/processing_pipeline.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/processing_job.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'double-clicking start is serialized by the session state machine',
    () async {
      final capture = _ControllableCapturePlatform();
      final recording = RecordingCoordinator(
        capture: AudioCapture(platform: capture),
      );
      final processing = _FakeProcessingPipeline();
      final session = MeetingSessionController(
        recording: recording,
        processing: processing,
      );
      addTearDown(() {
        session.dispose();
        recording.dispose();
        processing.dispose();
      });
      await session.initialize();

      final firstStart = session.startRecording();
      expect(session.phase, MeetingSessionPhase.starting);
      await expectLater(session.startRecording(), throwsStateError);
      expect(capture.startCalls, 1);

      capture.startGate.complete({
        'systemAudioAvailable': true,
        'microphoneAvailable': true,
      });
      await firstStart;
      expect(session.phase, MeetingSessionPhase.recording);
    },
  );

  test('recovery owns the session and blocks a new meeting', () async {
    final capture = _ControllableCapturePlatform();
    final recording = RecordingCoordinator(
      capture: AudioCapture(platform: capture),
    );
    final processing = _FakeProcessingPipeline.withPendingRecovery();
    final session = MeetingSessionController(
      recording: recording,
      processing: processing,
    );
    addTearDown(() {
      session.dispose();
      recording.dispose();
      processing.dispose();
    });

    final initialization = session.initialize();
    await processing.recoveryStarted.future;
    expect(session.phase, MeetingSessionPhase.processing);
    await expectLater(session.startRecording(), throwsStateError);
    expect(capture.startCalls, 0);

    processing.finishRecoveryAsFailed();
    await initialization;
    expect(session.phase, MeetingSessionPhase.failed);
    expect(session.blocksExit, isFalse);
  });

  test('processing a stopped meeting blocks another recording', () async {
    final capture = _ControllableCapturePlatform()..startGate.complete({});
    final recording = RecordingCoordinator(
      capture: AudioCapture(platform: capture),
    );
    final processing = _FakeProcessingPipeline.withDelayedStart();
    final session = MeetingSessionController(
      recording: recording,
      processing: processing,
    );
    addTearDown(() {
      session.dispose();
      recording.dispose();
      processing.dispose();
    });
    await session.initialize();
    await session.startRecording();

    final stop = session.stopAndProcess();
    await processing.processingStarted.future;
    expect(session.phase, MeetingSessionPhase.processing);
    await expectLater(session.startRecording(), throwsStateError);
    expect(capture.startCalls, 1);

    processing.finishProcessingAsDone();
    await stop;
    expect(session.phase, MeetingSessionPhase.completed);
  });
}

class _ControllableCapturePlatform extends AudioCapturePlatform {
  final Completer<Map<String, Object?>> startGate = Completer();
  int startCalls = 0;

  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Future<Map<String, Object?>> start() {
    startCalls += 1;
    return startGate.future;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async => '/tmp/session-recording.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async => {};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

class _FakeProcessingPipeline extends ChangeNotifier
    implements ProcessingPipelinePort {
  _FakeProcessingPipeline() : _recoveryGate = null, _processingGate = null;

  _FakeProcessingPipeline.withPendingRecovery()
    : _recoveryGate = Completer<void>(),
      _processingGate = null,
      currentJob = _job(ProcessingStage.transcribing);

  _FakeProcessingPipeline.withDelayedStart()
    : _recoveryGate = null,
      _processingGate = Completer<void>();

  final Completer<void> recoveryStarted = Completer<void>();
  final Completer<void> processingStarted = Completer<void>();
  final Completer<void>? _recoveryGate;
  final Completer<void>? _processingGate;

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
    if (_recoveryGate == null) return null;
    isRunning = true;
    notifyListeners();
    recoveryStarted.complete();
    await _recoveryGate.future;
    isRunning = false;
    notifyListeners();
    return null;
  }

  @override
  Future<MeetingNote?> start(RecordingResult recording) async {
    if (_processingGate == null) return null;
    currentJob = _job(ProcessingStage.transcribing);
    isRunning = true;
    notifyListeners();
    processingStarted.complete();
    await _processingGate.future;
    isRunning = false;
    notifyListeners();
    return generatedNote;
  }

  void finishRecoveryAsFailed() {
    currentJob = _job(
      ProcessingStage.failed,
      failureMessage: 'mock recovery failure',
    );
    _recoveryGate!.complete();
  }

  void finishProcessingAsDone() {
    currentJob = _job(ProcessingStage.done);
    generatedNote = _note();
    _processingGate!.complete();
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

ProcessingJob _job(ProcessingStage stage, {String? failureMessage}) =>
    ProcessingJob(
      id: 'job-1',
      audioPath: '/tmp/session-recording.wav',
      template: NoteTemplate.builtins.first,
      startedAt: DateTime.utc(2026, 8, 3),
      duration: const Duration(minutes: 1),
      highlights: const [],
      stage: stage,
      updatedAt: DateTime.utc(2026, 8, 3),
      failureMessage: failureMessage,
    );

MeetingNote _note() => MeetingNote(
  id: 'note-1',
  title: '状态机测试',
  startedAt: DateTime.utc(2026, 8, 3),
  duration: const Duration(minutes: 1),
  audioPath: '/tmp/note.wav',
  transcriptPath: '/tmp/note.txt',
  templateId: NoteTemplate.builtins.first.id,
  sections: const [],
  todos: const [],
  highlights: const [],
);
