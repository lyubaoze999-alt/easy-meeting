import 'dart:async';

import 'package:audio_capture/audio_capture.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/note_template.dart';
import '../domain/models/recording_asset.dart';

enum RecordingState { idle, recording, paused, finished }

class RecordingResult {
  const RecordingResult({
    required this.audioPath,
    required this.startedAt,
    required this.duration,
    required this.highlights,
    required this.template,
    this.nativeSessionId = '',
    this.sourceProfile = AudioCaptureProfile.legacyUnknown,
  });
  final String audioPath;
  final DateTime startedAt;
  final Duration duration;
  final List<Duration> highlights;
  final NoteTemplate template;
  final String nativeSessionId;
  final AudioCaptureProfile sourceProfile;

  NativeRecordingResult toNativeResult({String? sha256}) =>
      NativeRecordingResult(
        path: audioPath,
        duration: duration,
        sourceProfile: sourceProfile,
        sha256: sha256,
      );
}

class RecordingCoordinator extends ChangeNotifier {
  RecordingCoordinator({AudioCapture? capture})
    : _capture = capture ?? AudioCapture() {
    _subscriptions.addAll([
      _capture.systemLevel.listen((value) {
        systemLevel = value;
        notifyListeners();
      }),
      _capture.microphoneLevel.listen((value) {
        microphoneLevel = value;
        notifyListeners();
      }),
      _capture.systemSilent.listen((value) {
        systemSilent = value;
        notifyListeners();
      }),
      _capture.microphoneSilent.listen((value) {
        microphoneSilent = value;
        notifyListeners();
      }),
    ]);
  }

  final AudioCapture _capture;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  RecordingState state = RecordingState.idle;
  NoteTemplate selectedTemplate = NoteTemplate.builtins.first;
  List<Duration> highlights = [];
  double systemLevel = 0;
  double microphoneLevel = 0;
  bool systemSilent = false;
  bool microphoneSilent = false;
  bool systemAudioAvailable = false;
  bool microphoneAvailable = false;
  String? degradationReason;
  String? errorMessage;
  String? nativeSessionId;
  DateTime? _startedAt;
  DateTime? _segmentStartedAt;
  Duration _accumulated = Duration.zero;
  Timer? _ticker;
  bool _operationInFlight = false;

  bool get operationInFlight => _operationInFlight;
  Stream<AudioFrame> get pcmFrames => _capture.pcmFrames;

  Duration get elapsed {
    if (_segmentStartedAt == null) return _accumulated;
    return _accumulated + DateTime.now().difference(_segmentStartedAt!);
  }

  Future<void> start() async {
    _beginOperation(const {RecordingState.idle});
    errorMessage = null;
    try {
      final result = await _capture.start();
      systemAudioAvailable = result.systemAudioAvailable;
      microphoneAvailable = result.microphoneAvailable;
      degradationReason = result.degradationReason;
      nativeSessionId = result.nativeSessionId;
      _startedAt = DateTime.now();
      _segmentStartedAt = _startedAt;
      _accumulated = Duration.zero;
      highlights = [];
      state = RecordingState.recording;
      _ticker = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => notifyListeners(),
      );
      notifyListeners();
    } catch (error) {
      errorMessage = '无法开始录音：$error';
      notifyListeners();
      rethrow;
    } finally {
      _endOperation();
    }
  }

  Future<void> pause() async {
    _beginOperation(const {RecordingState.recording});
    try {
      await _capture.pause();
      _freezeSegment();
      state = RecordingState.paused;
      notifyListeners();
    } finally {
      _endOperation();
    }
  }

  Future<void> resume() async {
    _beginOperation(const {RecordingState.paused});
    try {
      await _capture.resume();
      _segmentStartedAt = DateTime.now();
      state = RecordingState.recording;
      notifyListeners();
    } finally {
      _endOperation();
    }
  }

  Future<RecordingResult> stop() async {
    _beginOperation(const {RecordingState.recording, RecordingState.paused});
    errorMessage = null;
    final wasRecording = state == RecordingState.recording;
    try {
      _freezeSegment();
      final path = await _capture.stop();
      _ticker?.cancel();
      state = RecordingState.finished;
      notifyListeners();
      return RecordingResult(
        audioPath: path,
        startedAt: _startedAt ?? DateTime.now(),
        duration: _accumulated,
        highlights: List.unmodifiable(highlights),
        template: selectedTemplate,
        nativeSessionId: nativeSessionId ?? '',
        sourceProfile: systemAudioAvailable
            ? AudioCaptureProfile.dualSource
            : AudioCaptureProfile.microphoneOnly,
      );
    } catch (error) {
      if (wasRecording && _segmentStartedAt == null) {
        _segmentStartedAt = DateTime.now();
      }
      errorMessage = '无法结束录音：$error';
      notifyListeners();
      rethrow;
    } finally {
      _endOperation();
    }
  }

  void addHighlight() {
    if (state != RecordingState.recording && state != RecordingState.paused) {
      return;
    }
    highlights = [...highlights, elapsed];
    notifyListeners();
  }

  void selectTemplate(NoteTemplate template) {
    if (state == RecordingState.finished) return;
    selectedTemplate = template;
    notifyListeners();
  }

  void reset() {
    if (_operationInFlight ||
        state == RecordingState.recording ||
        state == RecordingState.paused) {
      throw StateError('录音尚未安全结束，不能重置。');
    }
    _ticker?.cancel();
    state = RecordingState.idle;
    highlights = [];
    _startedAt = null;
    _segmentStartedAt = null;
    _accumulated = Duration.zero;
    systemLevel = 0;
    microphoneLevel = 0;
    errorMessage = null;
    nativeSessionId = null;
    notifyListeners();
  }

  void _freezeSegment() {
    if (_segmentStartedAt != null) {
      _accumulated += DateTime.now().difference(_segmentStartedAt!);
      _segmentStartedAt = null;
    }
  }

  void _beginOperation(Set<RecordingState> allowed) {
    if (_operationInFlight) throw StateError('上一项录音操作尚未完成，请稍候。');
    if (!allowed.contains(state)) {
      throw StateError('当前录音状态“${state.name}”不允许执行此操作。');
    }
    _operationInFlight = true;
    notifyListeners();
  }

  void _endOperation() {
    _operationInFlight = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
