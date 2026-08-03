import 'package:flutter/foundation.dart';

import '../domain/models/note_template.dart';
import '../domain/models/processing_job.dart';
import 'processing_pipeline.dart';
import 'recording_coordinator.dart';

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
  }) {
    recording.addListener(_forwardChildChange);
    processing.addListener(_forwardChildChange);
  }

  final RecordingCoordinator recording;
  final ProcessingPipelinePort processing;

  MeetingSessionPhase _phase = MeetingSessionPhase.initializing;
  Object? _lastError;
  bool _commandInFlight = false;
  bool _initialized = false;

  MeetingSessionPhase get phase => _phase;
  Object? get lastError => _lastError;
  ProcessingStage get processingStage => processing.stage;
  bool get commandInFlight => _commandInFlight;

  bool get blocksExit => switch (_phase) {
    MeetingSessionPhase.initializing ||
    MeetingSessionPhase.starting ||
    MeetingSessionPhase.recording ||
    MeetingSessionPhase.pausing ||
    MeetingSessionPhase.paused ||
    MeetingSessionPhase.resuming ||
    MeetingSessionPhase.stopping ||
    MeetingSessionPhase.processing => true,
    MeetingSessionPhase.ready ||
    MeetingSessionPhase.completed ||
    MeetingSessionPhase.failed => false,
  };

  Future<void> initialize() async {
    if (_initialized || _commandInFlight) return;
    _initialized = true;
    await _runCommand(
      allowed: const {MeetingSessionPhase.initializing},
      transition: MeetingSessionPhase.initializing,
      action: () async {
        await processing.resumeLatest();
        _syncAfterProcessing();
      },
      recover: () => MeetingSessionPhase.failed,
    );
  }

  Future<void> startRecording() async {
    await _runCommand(
      allowed: const {MeetingSessionPhase.ready},
      transition: MeetingSessionPhase.starting,
      action: () async {
        await recording.start();
        _setPhase(MeetingSessionPhase.recording);
      },
      recover: () => MeetingSessionPhase.ready,
    );
  }

  Future<void> pauseRecording() async {
    await _runCommand(
      allowed: const {MeetingSessionPhase.recording},
      transition: MeetingSessionPhase.pausing,
      action: () async {
        await recording.pause();
        _setPhase(MeetingSessionPhase.paused);
      },
      recover: () => MeetingSessionPhase.recording,
    );
  }

  Future<void> resumeRecording() async {
    await _runCommand(
      allowed: const {MeetingSessionPhase.paused},
      transition: MeetingSessionPhase.resuming,
      action: () async {
        await recording.resume();
        _setPhase(MeetingSessionPhase.recording);
      },
      recover: () => MeetingSessionPhase.paused,
    );
  }

  Future<void> stopAndProcess() async {
    final previous = _phase;
    await _runCommand(
      allowed: const {
        MeetingSessionPhase.recording,
        MeetingSessionPhase.paused,
      },
      transition: MeetingSessionPhase.stopping,
      action: () async {
        final result = await recording.stop();
        _setPhase(MeetingSessionPhase.processing);
        await processing.start(result);
        _syncAfterProcessing();
      },
      recover: () => recording.state == RecordingState.finished
          ? MeetingSessionPhase.failed
          : previous,
    );
  }

  Future<void> retryProcessing() async {
    await _runCommand(
      allowed: const {MeetingSessionPhase.failed},
      transition: MeetingSessionPhase.processing,
      action: () async {
        final job = processing.currentJob;
        if (job == null) throw StateError('没有可重试的处理任务。');
        await processing.retry(job.id);
        _syncAfterProcessing();
      },
      recover: () => MeetingSessionPhase.failed,
    );
  }

  Future<void> prepareNextMeeting() async {
    final previous = _phase;
    await _runCommand(
      allowed: const {
        MeetingSessionPhase.completed,
        MeetingSessionPhase.failed,
      },
      transition: previous,
      action: () async {
        await processing.abandonCurrent();
        recording.reset();
        _setPhase(MeetingSessionPhase.ready);
      },
      recover: () => previous,
    );
  }

  void addHighlight() {
    _requirePhase(const {
      MeetingSessionPhase.recording,
      MeetingSessionPhase.paused,
    });
    recording.addHighlight();
  }

  void selectTemplate(NoteTemplate template) {
    _requirePhase(const {
      MeetingSessionPhase.ready,
      MeetingSessionPhase.recording,
      MeetingSessionPhase.paused,
    });
    recording.selectTemplate(template);
  }

  Future<void> _runCommand({
    required Set<MeetingSessionPhase> allowed,
    required MeetingSessionPhase transition,
    required Future<void> Function() action,
    required MeetingSessionPhase Function() recover,
  }) async {
    if (_commandInFlight) throw StateError('上一项操作尚未完成，请稍候。');
    _requirePhase(allowed);
    _commandInFlight = true;
    _lastError = null;
    _setPhase(transition);
    try {
      await action();
    } catch (error) {
      _lastError = error;
      _setPhase(recover());
      rethrow;
    } finally {
      _commandInFlight = false;
      notifyListeners();
    }
  }

  void _syncAfterProcessing() {
    final job = processing.currentJob;
    if (job == null) {
      _setPhase(MeetingSessionPhase.ready);
    } else if (job.stage == ProcessingStage.done) {
      _setPhase(MeetingSessionPhase.completed);
    } else if (job.stage == ProcessingStage.failed) {
      _setPhase(MeetingSessionPhase.failed);
    } else {
      _setPhase(MeetingSessionPhase.processing);
    }
  }

  void _requirePhase(Set<MeetingSessionPhase> allowed) {
    if (!allowed.contains(_phase)) {
      throw StateError('当前状态“${_phase.name}”不允许执行此操作。');
    }
  }

  void _setPhase(MeetingSessionPhase value) {
    if (_phase == value) {
      notifyListeners();
      return;
    }
    _phase = value;
    notifyListeners();
  }

  void _forwardChildChange() {
    if (_phase == MeetingSessionPhase.initializing &&
        (processing.isRunning || processing.currentJob != null)) {
      _phase = MeetingSessionPhase.processing;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    recording.removeListener(_forwardChildChange);
    processing.removeListener(_forwardChildChange);
    super.dispose();
  }
}
