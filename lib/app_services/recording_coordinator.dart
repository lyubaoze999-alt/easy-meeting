import 'dart:async';

import 'package:audio_capture/audio_capture.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/note_template.dart';

enum RecordingState { idle, recording, paused, finished }

class RecordingResult {
  const RecordingResult({
    required this.audioPath,
    required this.startedAt,
    required this.duration,
    required this.highlights,
    required this.template,
  });
  final String audioPath;
  final DateTime startedAt;
  final Duration duration;
  final List<Duration> highlights;
  final NoteTemplate template;
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
  DateTime? _startedAt;
  DateTime? _segmentStartedAt;
  Duration _accumulated = Duration.zero;
  Timer? _ticker;

  Duration get elapsed {
    if (_segmentStartedAt == null) return _accumulated;
    return _accumulated + DateTime.now().difference(_segmentStartedAt!);
  }

  Future<void> start() async {
    if (state != RecordingState.idle) return;
    errorMessage = null;
    try {
      final result = await _capture.start();
      systemAudioAvailable = result.systemAudioAvailable;
      microphoneAvailable = result.microphoneAvailable;
      degradationReason = result.degradationReason;
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
    }
  }

  Future<void> pause() async {
    if (state != RecordingState.recording) return;
    await _capture.pause();
    _freezeSegment();
    state = RecordingState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (state != RecordingState.paused) return;
    await _capture.resume();
    _segmentStartedAt = DateTime.now();
    state = RecordingState.recording;
    notifyListeners();
  }

  Future<RecordingResult> stop() async {
    if (state != RecordingState.recording && state != RecordingState.paused) {
      throw StateError('当前没有正在进行的录音。');
    }
    errorMessage = null;
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
      );
    } catch (error) {
      errorMessage = '无法结束录音：$error';
      notifyListeners();
      rethrow;
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
    _ticker?.cancel();
    state = RecordingState.idle;
    highlights = [];
    _startedAt = null;
    _segmentStartedAt = null;
    _accumulated = Duration.zero;
    systemLevel = 0;
    microphoneLevel = 0;
    errorMessage = null;
    notifyListeners();
  }

  void _freezeSegment() {
    if (_segmentStartedAt != null) {
      _accumulated += DateTime.now().difference(_segmentStartedAt!);
      _segmentStartedAt = null;
    }
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
