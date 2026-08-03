import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/configuration.dart';
import '../domain/realtime/realtime_transcription_client.dart';
import '../domain/realtime/realtime_transcription_events.dart';
import '../infrastructure/network/openai_realtime_transcription_client.dart';
import '../infrastructure/repositories/transcript_repository.dart';
import '../infrastructure/settings/settings_store.dart';
import 'live_transcription_controller.dart';
import 'meeting_session_controller.dart';
import 'meeting_session_state.dart';
import 'persistent_meeting_capture.dart';
import 'recording_coordinator.dart';

typedef LiveClientFactory = RealtimeTranscriptionClient Function();

/// Creates one independent realtime controller per meeting while adapting it
/// to the session state machine. Closing an old realtime session continues in
/// the background and never delays the next local recording.
final class ManagedLiveTranscriptionSession extends ChangeNotifier
    implements
        MeetingLiveTranscriptPort,
        MeetingLiveAudioGatePort,
        PendingLiveFinalizationPort {
  static const _uiNotificationInterval = Duration(milliseconds: 200);

  ManagedLiveTranscriptionSession({
    required this.recording,
    required this.persistentCapture,
    required this.transcripts,
    required this.settings,
    LiveClientFactory? clientFactory,
  }) : _clientFactory =
           clientFactory ??
           (() => OpenAIRealtimeTranscriptionClient(secretProvider: settings));

  final RecordingCoordinator recording;
  final PersistentMeetingCapture persistentCapture;
  final TranscriptRepository transcripts;
  final SettingsStore settings;
  final LiveClientFactory _clientFactory;
  final StreamController<RealtimeTranscriptEvent> _events =
      StreamController<RealtimeTranscriptEvent>.broadcast(sync: true);
  final Set<_ManagedLiveSession> _sessions = <_ManagedLiveSession>{};
  final Set<Future<void>> _finishFutures = <Future<void>>{};
  final Map<String, LiveTranscriptionStopResult> _stopResults =
      <String, LiveTranscriptionStopResult>{};

  _ManagedConnectAttempt? _pendingConnect;
  _ManagedLiveSession? _currentSession;
  Future<void>? _shutdownFuture;
  Timer? _uiNotificationTimer;
  int _generation = 0;
  bool _acceptingConnections = true;
  bool _disposed = false;

  LiveTranscriptionController? get current => _currentSession?.controller;

  LiveTranscriptionStopResult? get lastStopResult {
    final meetingId = persistentCapture.lastMeetingId;
    return meetingId == null ? null : _stopResults[meetingId];
  }

  LiveTranscriptionStopResult? stopResultForMeeting(String meetingId) =>
      _stopResults[meetingId];

  LiveTranscriptPhase get phase =>
      _currentSession?.controller.phase ?? LiveTranscriptPhase.disabled;
  List<LiveTranscriptItem> get items =>
      _currentSession?.controller.items ?? const <LiveTranscriptItem>[];
  Object? get lastError => _currentSession?.controller.lastError;

  @override
  bool get hasPendingFinalization => _finishFutures.isNotEmpty;

  @override
  Stream<RealtimeTranscriptEvent> get events => _events.stream;

  @override
  Future<void> connect() {
    if (_disposed || !_acceptingConnections) {
      throw StateError('实时转写会话已关闭。');
    }
    if (_pendingConnect != null || _currentSession != null) {
      throw StateError('已有实时转写会话正在连接或运行。');
    }
    final meetingId = persistentCapture.activeMeetingId;
    if (meetingId == null) throw StateError('没有活动会议可连接实时转写。');
    final attempt = _ManagedConnectAttempt(++_generation, meetingId);
    _pendingConnect = attempt;
    notifyListeners();
    return _connect(attempt);
  }

  Future<void> _connect(_ManagedConnectAttempt attempt) async {
    try {
      final appSettings = await settings.load();
      if (!_owns(attempt)) return;
      final realtime = appSettings.realtimeTranscription;
      if (!realtime.canStream) {
        throw const RealtimeClientException(
          code: 'missing_realtime_configuration',
          message: '实时转写尚未完成配置或上传确认。',
          isRetryable: false,
        );
      }

      final controller = LiveTranscriptionController(
        audioFrames: recording.pcmFrames,
        client: _clientFactory(),
        repository: transcripts,
      );
      final session = _ManagedLiveSession(
        attempt: attempt,
        controller: controller,
      );
      session.listener = () => _forward(session);
      final startSignal = Completer<void>();
      session.startFuture = startSignal.future;
      _currentSession = session;
      _sessions.add(session);
      controller.addListener(session.listener);
      notifyListeners();

      final start = controller.start(
        meetingId: attempt.meetingId,
        config: _protocolConfig(realtime),
      );
      unawaited(
        start.then<void>(
          (_) => startSignal.complete(),
          onError: (Object error, StackTrace stackTrace) {
            startSignal.completeError(error, stackTrace);
          },
        ),
      );
      await session.startFuture;
      if (!_isCurrent(session)) return;
      if (controller.phase != LiveTranscriptPhase.streaming) {
        final error = controller.lastError;
        if (error is RealtimeClientException) throw error;
        throw const RealtimeClientException(
          code: 'realtime_connecting',
          message: '实时转写正在重新连接，录音会继续保存。',
          isRetryable: true,
        );
      }
    } catch (_) {
      if (!_owns(attempt) && !identical(_currentSession?.attempt, attempt)) {
        return;
      }
      rethrow;
    } finally {
      _clearPending(attempt);
    }
  }

  @override
  Future<void> send(RealtimeAudioFrame frame) async {
    // The managed controller consumes AudioCapture.pcmFrames directly. This
    // method intentionally does not forward a duplicate copy.
  }

  @override
  Future<void> commitTurn() async {
    // Pause is handled synchronously through MeetingLiveAudioGatePort.
  }

  @override
  void onCapturePaused() => _currentSession?.controller.onCapturePaused();

  @override
  void onCaptureResumed() => _currentSession?.controller.onCaptureResumed();

  @override
  Future<void> close() {
    if (_disposed) return Future<void>.value();
    _generation += 1;
    final pending = _pendingConnect;
    if (pending != null) pending.cancelled = true;
    _pendingConnect = null;
    final session = _currentSession;
    _currentSession = null;
    if (session != null) {
      session.attempt.cancelled = true;
      _trackFinish(session, recording.elapsed);
    }
    notifyListeners();
    return Future<void>.value();
  }

  Future<void> _finish(_ManagedLiveSession session, Duration duration) async {
    try {
      await session.startFuture;
      final result = await session.controller.finish(
        recordingDuration: duration,
      );
      _stopResults[session.meetingId] = result;
    } on Object {
      // The controller retains its safe error for presentation. Local capture
      // has already been released and must not be affected.
    } finally {
      _disposeSession(session);
      if (!_disposed) notifyListeners();
    }
  }

  void _trackFinish(_ManagedLiveSession session, Duration duration) {
    if (session.finishFuture != null) return;
    late final Future<void> tracked;
    tracked = _finish(session, duration).whenComplete(() {
      _finishFutures.remove(tracked);
      if (!_disposed) notifyListeners();
    });
    session.finishFuture = tracked;
    _finishFutures.add(tracked);
    unawaited(tracked);
  }

  @override
  Future<void> drain() async {
    while (_finishFutures.isNotEmpty) {
      await Future.wait<void>(List<Future<void>>.of(_finishFutures));
    }
  }

  Future<void> shutdown() => _shutdownFuture ??= _shutdown();

  Future<void> _shutdown() async {
    _acceptingConnections = false;
    await close();
    await drain();
  }

  @override
  Future<void> abort() async {
    _acceptingConnections = false;
    _generation += 1;
    final pending = _pendingConnect;
    if (pending != null) pending.cancelled = true;
    _pendingConnect = null;
    _currentSession = null;
    final sessions = _sessions.toList(growable: false);
    for (final session in sessions) {
      session.attempt.cancelled = true;
      if (session.finishFuture == null) _disposeSession(session);
    }
    await drain();
    if (!_disposed) notifyListeners();
  }

  void _forward(_ManagedLiveSession session) {
    if (_disposed || !_isCurrent(session)) return;
    final controller = session.controller;
    final connectionState = switch (controller.phase) {
      LiveTranscriptPhase.disabled => RealtimeConnectionState.disconnected,
      LiveTranscriptPhase.connecting => RealtimeConnectionState.connecting,
      LiveTranscriptPhase.streaming => RealtimeConnectionState.connected,
      LiveTranscriptPhase.reconnecting => RealtimeConnectionState.connecting,
      LiveTranscriptPhase.degraded ||
      LiveTranscriptPhase.failed => RealtimeConnectionState.failed,
      LiveTranscriptPhase.closing => RealtimeConnectionState.closing,
      LiveTranscriptPhase.completed => RealtimeConnectionState.closed,
    };
    _events.add(
      TranscriptConnectionChanged(
        connectionState,
        reasonCode: controller.lastError == null
            ? null
            : 'managed_realtime_error',
      ),
    );
    final phaseChanged = session.lastObservedPhase != controller.phase;
    session.lastObservedPhase = controller.phase;
    if (phaseChanged) {
      _notifyUiImmediately();
    } else {
      _scheduleUiNotification(session);
    }
  }

  void _notifyUiImmediately() {
    _uiNotificationTimer?.cancel();
    _uiNotificationTimer = null;
    if (!_disposed) notifyListeners();
  }

  void _scheduleUiNotification(_ManagedLiveSession session) {
    if (_uiNotificationTimer != null) return;
    _uiNotificationTimer = Timer(_uiNotificationInterval, () {
      _uiNotificationTimer = null;
      if (!_disposed && _isCurrent(session)) notifyListeners();
    });
  }

  bool _owns(_ManagedConnectAttempt attempt) =>
      _acceptingConnections &&
      !attempt.cancelled &&
      attempt.generation == _generation &&
      identical(_pendingConnect, attempt);

  bool _isCurrent(_ManagedLiveSession session) =>
      _acceptingConnections &&
      !session.attempt.cancelled &&
      session.attempt.generation == _generation &&
      identical(_currentSession, session);

  void _clearPending(_ManagedConnectAttempt attempt) {
    if (identical(_pendingConnect, attempt)) _pendingConnect = null;
    if (!_disposed) notifyListeners();
  }

  void _disposeSession(_ManagedLiveSession session) {
    if (session.disposed) return;
    session.disposed = true;
    _sessions.remove(session);
    session.controller.removeListener(session.listener);
    session.controller.dispose();
  }

  static RealtimeTranscriptionConfig _protocolConfig(
    RealtimeServiceConfig config,
  ) {
    final language = config.language.trim();
    return RealtimeTranscriptionConfig(
      websocketUrl: Uri.parse(config.websocketUrl.trim()),
      model: config.model.trim(),
      secret: const SecretReference(RealtimeServiceConfig.secretReference),
      languages: language.isEmpty || language.toLowerCase() == 'auto'
          ? const <String>[]
          : <String>[language],
      keywords: config.keywords,
      contextPrompt: config.contextPrompt,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _acceptingConnections = false;
    _generation += 1;
    final pending = _pendingConnect;
    if (pending != null) pending.cancelled = true;
    _pendingConnect = null;
    _currentSession = null;
    _uiNotificationTimer?.cancel();
    _uiNotificationTimer = null;
    final sessions = _sessions.toList(growable: false);
    for (final session in sessions) {
      session.attempt.cancelled = true;
      _disposeSession(session);
    }
    unawaited(_events.close());
    super.dispose();
  }
}

final class _ManagedConnectAttempt {
  _ManagedConnectAttempt(this.generation, this.meetingId);

  final int generation;
  final String meetingId;
  bool cancelled = false;
}

final class _ManagedLiveSession {
  _ManagedLiveSession({required this.attempt, required this.controller});

  final _ManagedConnectAttempt attempt;
  final LiveTranscriptionController controller;
  late final VoidCallback listener;
  late final Future<void> startFuture;
  Future<void>? finishFuture;
  LiveTranscriptPhase? lastObservedPhase;
  bool disposed = false;

  String get meetingId => attempt.meetingId;
}
