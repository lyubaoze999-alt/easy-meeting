import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:audio_capture/audio_frame.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/transcript_document.dart';
import '../domain/models/transcript_segment.dart';
import '../domain/realtime/realtime_transcription_client.dart';
import '../domain/realtime/realtime_transcription_events.dart';
import '../infrastructure/repositories/transcript_repository.dart';
import 'meeting_session_state.dart';

typedef LiveTranscriptionSleep = Future<void> Function(Duration duration);

/// The deliberately small realtime-transcription surface used by the meeting
/// session state machine. It has no access to audio-capture controls, so a
/// network failure cannot pause or stop the local recording.
abstract interface class LiveTranscriptionPort implements Listenable {
  LiveTranscriptPhase get phase;
  bool get audioSendingEnabled;
  List<LiveTranscriptItem> get items;
  List<TranscriptGap> get gaps;
  Object? get lastError;

  Future<void> start({
    required String meetingId,
    required RealtimeTranscriptionConfig config,
  });

  void onCapturePaused();
  void onCaptureResumed();
  Future<void> retryNow();

  Future<LiveTranscriptionStopResult> finish({
    required Duration recordingDuration,
  });
}

final class LiveTranscriptItem {
  const LiveTranscriptItem({
    required this.itemId,
    required this.text,
    required this.isFinal,
    this.ordinal,
    this.start,
    this.end,
  });

  final String itemId;
  final String text;
  final bool isFinal;
  final int? ordinal;
  final Duration? start;
  final Duration? end;
}

enum LiveTranscriptionStopOutcome { frozen, needsRepair }

final class LiveTranscriptionStopResult {
  const LiveTranscriptionStopResult({
    required this.outcome,
    required this.draft,
    required this.gaps,
    this.finalTranscript,
  });

  final LiveTranscriptionStopOutcome outcome;
  final TranscriptDocument draft;
  final TranscriptDocument? finalTranscript;
  final List<TranscriptGap> gaps;
}

final class LiveTranscriptionRetryPolicy {
  const LiveTranscriptionRetryPolicy({
    this.backoff = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 30),
    ],
    this.jitterFraction = 0.2,
    this.degradeAfter = const Duration(minutes: 5),
  }) : assert(jitterFraction >= 0);

  final List<Duration> backoff;
  final double jitterFraction;
  final Duration degradeAfter;

  Duration delayFor(int retryIndex, double randomValue) {
    if (backoff.isEmpty) {
      throw StateError('Realtime retry backoff must not be empty.');
    }
    final base = backoff[math.min(retryIndex, backoff.length - 1)];
    final boundedRandom = randomValue.clamp(0.0, 1.0);
    final multiplier = 1 + jitterFraction * boundedRandom;
    return Duration(microseconds: (base.inMicroseconds * multiplier).round());
  }
}

final class LiveTranscriptionController extends ChangeNotifier
    implements LiveTranscriptionPort {
  factory LiveTranscriptionController({
    required Stream<AudioFrame> audioFrames,
    required RealtimeTranscriptionClient client,
    required TranscriptRepository repository,
    LiveTranscriptionRetryPolicy retryPolicy =
        const LiveTranscriptionRetryPolicy(),
    Duration stopWaitTimeout = const Duration(seconds: 8),
    DateTime Function()? now,
    LiveTranscriptionSleep? sleep,
    double Function()? random,
  }) => LiveTranscriptionController._(
    audioFrames: audioFrames,
    client: client,
    repository: repository,
    retryPolicy: retryPolicy,
    stopWaitTimeout: stopWaitTimeout,
    now: now ?? DateTime.now,
    sleep: sleep ?? _defaultSleep,
    random: random ?? _defaultRandom,
  );

  LiveTranscriptionController._({
    required this._audioFrames,
    required this._client,
    required this._repository,
    required this._retryPolicy,
    required Duration stopWaitTimeout,
    required this._now,
    required this._sleep,
    required this._random,
  }) : _stopWaitTimeout = stopWaitTimeout,
       super() {
    if (stopWaitTimeout.isNegative) {
      throw ArgumentError.value(stopWaitTimeout, 'stopWaitTimeout');
    }
    if (_retryPolicy.degradeAfter <= Duration.zero) {
      throw ArgumentError.value(
        _retryPolicy.degradeAfter,
        'retryPolicy.degradeAfter',
      );
    }
  }

  final Stream<AudioFrame> _audioFrames;
  final RealtimeTranscriptionClient _client;
  final TranscriptRepository _repository;
  final LiveTranscriptionRetryPolicy _retryPolicy;
  final Duration _stopWaitTimeout;
  final DateTime Function() _now;
  final LiveTranscriptionSleep _sleep;
  final double Function() _random;

  final Map<String, _LiveItemState> _itemStates = <String, _LiveItemState>{};
  final List<TranscriptGap> _gaps = <TranscriptGap>[];

  StreamSubscription<AudioFrame>? _audioSubscription;
  StreamSubscription<RealtimeTranscriptEvent>? _eventSubscription;
  RealtimeTranscriptionConfig? _config;
  TranscriptDocument? _draft;
  AudioFrame? _lastObservedFrame;
  Future<void> _frameTail = Future<void>.value();
  final Queue<({RealtimeAudioFrame frame, int epoch})> _frameQueue =
      Queue<({RealtimeAudioFrame frame, int epoch})>();
  Future<void> _persistenceTail = Future<void>.value();
  Completer<void>? _stopCompletionSignal;

  LiveTranscriptPhase _phase = LiveTranscriptPhase.disabled;
  Object? _lastError;
  DateTime? _failureStartedAt;
  int _retryIndex = 0;
  int _connectionEpoch = 0;
  int _audioEpoch = 0;
  int _lastSentEndSample = 0;
  int _lastCommittedEndSample = 0;
  int _largestObservedEndSample = 0;
  bool _capturePaused = false;
  bool _audioSendingEnabled = false;
  bool _started = false;
  bool _stopping = false;
  bool _automaticRetryAllowed = true;
  bool _connectInProgress = false;
  bool _reconnectLoopRunning = false;
  bool _persistenceFailed = false;
  bool _frameDrainRunning = false;
  bool _disposed = false;

  @override
  LiveTranscriptPhase get phase => _phase;

  @override
  bool get audioSendingEnabled => _audioSendingEnabled;

  @override
  Object? get lastError => _lastError;

  TranscriptDocument? get draft => _draft;

  @override
  List<TranscriptGap> get gaps => List<TranscriptGap>.unmodifiable(_gaps);

  @override
  List<LiveTranscriptItem> get items {
    final values = _itemStates.values.map((item) {
      final sampleRate = _config?.sampleRate ?? AudioFrame.canonicalSampleRate;
      return LiveTranscriptItem(
        itemId: item.itemId,
        text: item.displayText,
        isFinal: item.isFinal,
        ordinal: item.ordinal,
        start: item.startSample == null
            ? null
            : _durationForSamples(item.startSample!, sampleRate),
        end: item.endSample == null
            ? null
            : _durationForSamples(item.endSample!, sampleRate),
      );
    }).toList();
    values.sort((left, right) {
      final leftOrdinal = left.ordinal;
      final rightOrdinal = right.ordinal;
      if (leftOrdinal != null && rightOrdinal != null) {
        return leftOrdinal.compareTo(rightOrdinal);
      }
      if (leftOrdinal != null) return -1;
      if (rightOrdinal != null) return 1;
      final leftEnd = left.end;
      final rightEnd = right.end;
      if (leftEnd != null && rightEnd != null) {
        return leftEnd.compareTo(rightEnd);
      }
      return left.itemId.compareTo(right.itemId);
    });
    return List<LiveTranscriptItem>.unmodifiable(values);
  }

  @override
  Future<void> start({
    required String meetingId,
    required RealtimeTranscriptionConfig config,
  }) async {
    if (_started) throw StateError('Realtime transcription already started.');
    if (meetingId.trim().isEmpty) {
      throw ArgumentError.value(meetingId, 'meetingId');
    }

    _started = true;
    _config = config;
    _phase = LiveTranscriptPhase.connecting;
    _eventSubscription = _client.events.listen(
      _handleRealtimeEvent,
      onError: _handleEventStreamError,
    );
    _audioSubscription = _audioFrames.listen(
      _handleAudioFrame,
      onError: _handleAudioStreamError,
    );
    _emitChange();

    try {
      _draft = await _repository.createRealtimeDraft(meetingId);
    } on Object catch (error) {
      _lastError = error;
      _phase = LiveTranscriptPhase.failed;
      _automaticRetryAllowed = false;
      _setAudioSendingEnabled(false);
      _emitChange();
      rethrow;
    }

    final epoch = ++_connectionEpoch;
    final connected = await _connect(epoch);
    if (!connected && epoch == _connectionEpoch) {
      _ensureReconnectLoop(epoch);
    }
  }

  @override
  void onCapturePaused() {
    if (!_started || _stopping) return;
    // This gate changes synchronously, before the recording controller awaits
    // its native pause command.
    _capturePaused = true;
    _audioEpoch += 1;
    _setAudioSendingEnabled(false);
    _emitChange();
  }

  @override
  void onCaptureResumed() {
    if (!_started || _stopping) return;
    _capturePaused = false;
    _setAudioSendingEnabled(
      _phase == LiveTranscriptPhase.streaming &&
          _client.connectionState == RealtimeConnectionState.connected,
    );
    _emitChange();
  }

  @override
  Future<void> retryNow() async {
    if (!_started || _stopping) {
      throw StateError('Realtime transcription is not active.');
    }
    _automaticRetryAllowed = true;
    _failureStartedAt = null;
    _retryIndex = 0;
    final epoch = ++_connectionEpoch;
    _reconnectLoopRunning = false;
    _phase = LiveTranscriptPhase.reconnecting;
    _setAudioSendingEnabled(false);
    _emitChange();
    await _abortSafely();
    final connected = await _connect(epoch);
    if (!connected && epoch == _connectionEpoch) {
      _ensureReconnectLoop(epoch);
    }
  }

  @override
  Future<LiveTranscriptionStopResult> finish({
    required Duration recordingDuration,
  }) async {
    if (!_started || _draft == null) {
      throw StateError('Realtime transcription is not active.');
    }
    if (_stopping) {
      throw StateError('Realtime transcription is already closing.');
    }
    if (recordingDuration.isNegative) {
      throw ArgumentError.value(recordingDuration, 'recordingDuration');
    }

    _stopping = true;
    _audioEpoch += 1;
    ++_connectionEpoch;
    _setAudioSendingEnabled(false);
    _phase = LiveTranscriptPhase.closing;
    _emitChange();
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    await _frameTail;
    if (_client.connectionState == RealtimeConnectionState.connected &&
        _lastSentEndSample > _lastCommittedEndSample) {
      try {
        await _client.commitTurn();
      } on Object catch (error) {
        _lastError = error;
        _addGapSamples(
          _lastCommittedEndSample,
          _lastSentEndSample,
          'commit_failed',
        );
      }
    }

    await _waitForSubmittedItems();
    await _persistenceTail;

    if (_client.connectionState == RealtimeConnectionState.connected ||
        _client.connectionState == RealtimeConnectionState.closing) {
      try {
        await _client.flushAndClose();
      } on Object catch (error) {
        _lastError = error;
        await _abortSafely();
      }
    } else {
      await _abortSafely();
    }
    await _persistenceTail;

    _finalizeKnownGaps(recordingDuration);
    final draft = _draft!;
    try {
      if (_gaps.isEmpty && !_persistenceFailed) {
        final frozen = _repository is RevisionAllocatingTranscriptRepository
            ? await (_repository as RevisionAllocatingTranscriptRepository)
                  .freezeNext(draft.id)
            : await _repository.freeze(draft.id, revision: 1);
        _phase = LiveTranscriptPhase.completed;
        _emitChange();
        return LiveTranscriptionStopResult(
          outcome: LiveTranscriptionStopOutcome.frozen,
          draft: draft,
          finalTranscript: frozen,
          gaps: const <TranscriptGap>[],
        );
      }

      if (_gaps.isEmpty) {
        _addGapSamples(0, 0, 'completed_segment_persistence_failed');
      }
      await _repository.markNeedsRepair(draft.id, List.of(_gaps));
      _phase = LiveTranscriptPhase.completed;
      _emitChange();
      return LiveTranscriptionStopResult(
        outcome: LiveTranscriptionStopOutcome.needsRepair,
        draft: draft,
        gaps: List<TranscriptGap>.unmodifiable(_gaps),
      );
    } on Object catch (error) {
      _lastError = error;
      _phase = LiveTranscriptPhase.failed;
      _emitChange();
      rethrow;
    }
  }

  Future<bool> _connect(int epoch) async {
    if (_stopping || epoch != _connectionEpoch || _connectInProgress) {
      return false;
    }
    _connectInProgress = true;
    _phase = _failureStartedAt == null
        ? LiveTranscriptPhase.connecting
        : LiveTranscriptPhase.reconnecting;
    _setAudioSendingEnabled(false);
    _emitChange();
    try {
      await _client.connect(_config!);
      if (_stopping || epoch != _connectionEpoch) {
        await _abortSafely();
        return false;
      }
      _failureStartedAt = null;
      _retryIndex = 0;
      _lastError = null;
      _phase = LiveTranscriptPhase.streaming;
      _setAudioSendingEnabled(!_capturePaused);
      _emitChange();
      return true;
    } on Object catch (error) {
      if (_stopping || epoch != _connectionEpoch) return false;
      _lastError = error;
      final retryable = error is! RealtimeClientException || error.isRetryable;
      _automaticRetryAllowed = retryable;
      _failureStartedAt ??= _now();
      _phase = retryable
          ? LiveTranscriptPhase.reconnecting
          : LiveTranscriptPhase.failed;
      _setAudioSendingEnabled(false);
      _emitChange();
      return false;
    } finally {
      _connectInProgress = false;
    }
  }

  void _ensureReconnectLoop(int epoch) {
    if (_reconnectLoopRunning ||
        _stopping ||
        !_automaticRetryAllowed ||
        epoch != _connectionEpoch) {
      return;
    }
    _reconnectLoopRunning = true;
    unawaited(_runReconnectLoop(epoch));
  }

  Future<void> _runReconnectLoop(int epoch) async {
    try {
      while (!_stopping &&
          _automaticRetryAllowed &&
          epoch == _connectionEpoch &&
          _phase != LiveTranscriptPhase.streaming) {
        final failedAt = _failureStartedAt ??= _now();
        final elapsed = _now().difference(failedAt);
        if (elapsed >= _retryPolicy.degradeAfter) {
          _enterDegraded();
          return;
        }

        var delay = _retryPolicy.delayFor(_retryIndex, _random());
        final remaining = _retryPolicy.degradeAfter - elapsed;
        if (delay > remaining) delay = remaining;
        await _sleep(delay);
        if (_stopping || epoch != _connectionEpoch) return;
        if (_now().difference(failedAt) >= _retryPolicy.degradeAfter) {
          _enterDegraded();
          return;
        }

        _retryIndex += 1;
        await _abortSafely();
        if (await _connect(epoch)) return;
      }
    } finally {
      if (epoch == _connectionEpoch) _reconnectLoopRunning = false;
    }
  }

  void _enterDegraded() {
    _automaticRetryAllowed = false;
    _setAudioSendingEnabled(false);
    _phase = LiveTranscriptPhase.degraded;
    _emitChange();
  }

  void _handleAudioFrame(AudioFrame frame) {
    if (!_started || _stopping) return;
    _detectLocalFrameGap(frame);
    _lastObservedFrame = frame;
    _largestObservedEndSample = math.max(
      _largestObservedEndSample,
      frame.endSample,
    );

    if (!_audioSendingEnabled) {
      if (!_capturePaused) {
        _addGapSamples(
          frame.startSample,
          frame.endSample,
          'transport_unavailable',
        );
      }
      return;
    }

    final realtimeFrame = RealtimeAudioFrame(
      sessionId: frame.sessionId,
      sequence: frame.sequence,
      startSample: frame.startSample,
      sampleRate: frame.sampleRate,
      channels: frame.channels,
      bytes: frame.bytes,
    );
    final audioEpoch = _audioEpoch;
    if (_frameQueue.length >= 25) {
      final dropped = _frameQueue.removeFirst().frame;
      _addGapSamples(
        dropped.startSample,
        dropped.startSample + dropped.sampleCount,
        'dart_send_queue_overflow',
      );
    }
    _frameQueue.add((frame: realtimeFrame, epoch: audioEpoch));
    if (!_frameDrainRunning) {
      _frameDrainRunning = true;
      _frameTail = _drainFrameQueue();
    }
  }

  Future<void> _drainFrameQueue() async {
    try {
      while (_frameQueue.isNotEmpty) {
        final queued = _frameQueue.removeFirst();
        await _appendFrame(queued.frame, queued.epoch);
      }
    } finally {
      _frameDrainRunning = false;
      if (_frameQueue.isNotEmpty) {
        _frameDrainRunning = true;
        _frameTail = _drainFrameQueue();
      }
    }
  }

  Future<void> _appendFrame(RealtimeAudioFrame frame, int audioEpoch) async {
    if (audioEpoch != _audioEpoch || !_audioSendingEnabled || _stopping) {
      _addGapSamples(
        frame.startSample,
        frame.startSample + frame.sampleCount,
        'audio_gate_closed_before_send',
      );
      return;
    }
    try {
      await _client.append(frame);
      _lastSentEndSample = math.max(
        _lastSentEndSample,
        frame.startSample + frame.sampleCount,
      );
    } on Object catch (error) {
      _lastError = error;
      _addGapSamples(
        frame.startSample,
        frame.startSample + frame.sampleCount,
        'transport_unavailable',
      );
      if (!_stopping) _transportLost(error);
    }
  }

  void _detectLocalFrameGap(AudioFrame frame) {
    final previous = _lastObservedFrame;
    final expectedSequence = previous == null ? 0 : previous.sequence + 1;
    final expectedStart = previous == null ? 0 : previous.endSample;
    if (frame.sequence > expectedSequence ||
        frame.startSample > expectedStart) {
      _addGapSamples(
        expectedStart,
        math.max(expectedStart, frame.startSample),
        frame.sequence > expectedSequence
            ? 'sequence_discontinuity'
            : 'sample_discontinuity',
      );
    }
  }

  void _handleRealtimeEvent(RealtimeTranscriptEvent event) {
    switch (event) {
      case TranscriptDelta():
        final item = _itemFor(event.itemId);
        if (!item.completedContent.containsKey(event.contentIndex)) {
          item.draftContent[event.contentIndex] = event.draftTranscript;
        }
      case TranscriptCompleted():
        final item = _itemFor(event.itemId);
        item.draftContent.remove(event.contentIndex);
        item.completedContent[event.contentIndex] = event.transcript;
        _resolveTimelineAndPersist();
      case TranscriptTurnCommitted():
        final item = _itemFor(event.itemId);
        if (item.endSample != null &&
            (item.endSample != event.endSample ||
                item.previousItemId != event.previousItemId)) {
          _addGapSamples(
            math.min(item.endSample!, event.endSample),
            math.max(item.endSample!, event.endSample),
            'conflicting_turn_commit',
          );
        } else {
          item.previousItemId = event.previousItemId;
          item.endSample = event.endSample;
          _lastCommittedEndSample = math.max(
            _lastCommittedEndSample,
            event.endSample,
          );
          _resolveTimelineAndPersist();
        }
      case TranscriptGapDetected():
        _recordAdapterGap(event);
      case TranscriptConnectionChanged():
        _handleConnectionChanged(event);
      case TranscriptServiceError():
        _lastError = event;
        if (!event.isRetryable) {
          _automaticRetryAllowed = false;
          _setAudioSendingEnabled(false);
          _phase = LiveTranscriptPhase.failed;
          unawaited(_abortSafely());
        } else if (!_stopping) {
          _transportLost(event);
        }
    }
    _notifyStopWaiterIfReady();
    _emitChange();
  }

  void _handleConnectionChanged(TranscriptConnectionChanged event) {
    if (_stopping) return;
    switch (event.state) {
      case RealtimeConnectionState.connected:
        _failureStartedAt = null;
        _retryIndex = 0;
        _phase = LiveTranscriptPhase.streaming;
        _setAudioSendingEnabled(!_capturePaused);
      case RealtimeConnectionState.connecting:
        _phase = _failureStartedAt == null
            ? LiveTranscriptPhase.connecting
            : LiveTranscriptPhase.reconnecting;
        _setAudioSendingEnabled(false);
      case RealtimeConnectionState.disconnected ||
          RealtimeConnectionState.failed:
        if (_automaticRetryAllowed) {
          _transportLost(event.reasonCode ?? 'connection_lost');
        }
      case RealtimeConnectionState.closing:
        _phase = LiveTranscriptPhase.closing;
        _setAudioSendingEnabled(false);
      case RealtimeConnectionState.closed:
        _setAudioSendingEnabled(false);
    }
  }

  void _transportLost(Object error) {
    if (_stopping || !_automaticRetryAllowed) return;
    _lastError = error;
    _failureStartedAt ??= _now();
    _phase = LiveTranscriptPhase.reconnecting;
    _setAudioSendingEnabled(false);
    _ensureReconnectLoop(_connectionEpoch);
  }

  void _recordAdapterGap(TranscriptGapDetected event) {
    final item = event.itemId == null ? null : _itemStates[event.itemId!];
    final startSample = event.startSample ?? item?.startSample ?? 0;
    final endSample = event.endSample ?? item?.endSample ?? startSample;
    _addGapSamples(startSample, endSample, event.reason.name);
  }

  _LiveItemState _itemFor(String itemId) =>
      _itemStates.putIfAbsent(itemId, () => _LiveItemState(itemId));

  void _resolveTimelineAndPersist() {
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in _itemStates.values) {
        if (item.endSample == null || item.ordinal != null) continue;
        final previousId = item.previousItemId;
        if (previousId == null) {
          final preceding = _itemStates.values
              .where(
                (candidate) =>
                    !identical(candidate, item) &&
                    candidate.ordinal != null &&
                    candidate.endSample != null &&
                    candidate.endSample! <= item.endSample!,
              )
              .fold<_LiveItemState?>(
                null,
                (latest, candidate) =>
                    latest == null || candidate.endSample! > latest.endSample!
                    ? candidate
                    : latest,
              );
          item.startSample = preceding?.endSample ?? 0;
          item.ordinal = preceding == null ? 0 : preceding.ordinal! + 1;
          changed = true;
          continue;
        }
        final previous = _itemStates[previousId];
        if (previous?.ordinal == null || previous?.endSample == null) continue;
        item.startSample = previous!.endSample;
        item.ordinal = previous.ordinal! + 1;
        if (item.endSample! < item.startSample!) {
          _addGapSamples(
            item.endSample!,
            item.startSample!,
            'invalid_turn_timeline',
          );
        }
        changed = true;
      }
    }
    _persistenceTail = _persistenceTail.then((_) => _persistResolvedItems());
  }

  Future<void> _persistResolvedItems() async {
    final draft = _draft;
    final config = _config;
    if (draft == null || config == null) return;
    final resolved =
        _itemStates.values
            .where(
              (item) =>
                  item.isFinal &&
                  item.ordinal != null &&
                  item.startSample != null &&
                  item.endSample != null,
            )
            .toList()
          ..sort((left, right) => left.ordinal!.compareTo(right.ordinal!));
    for (final item in resolved) {
      final fingerprint =
          '${item.ordinal}\u0000${item.startSample}\u0000'
          '${item.endSample}\u0000${item.completedText}';
      if (item.persistedFingerprint == fingerprint) continue;
      try {
        await _repository.saveCompletedSegment(
          TranscriptSegment(
            id: '${draft.id}:${item.itemId}',
            transcriptId: draft.id,
            providerItemId: item.itemId,
            ordinal: item.ordinal!,
            start: _durationForSamples(item.startSample!, config.sampleRate),
            end: _durationForSamples(item.endSample!, config.sampleRate),
            text: item.completedText,
            isFinal: true,
            source: TranscriptSegmentSource.realtime,
            updatedAt: _now(),
          ),
        );
        item.persistedFingerprint = fingerprint;
      } on Object catch (error) {
        _persistenceFailed = true;
        _lastError = error;
      }
    }
    _notifyStopWaiterIfReady();
    _emitChange();
  }

  Future<void> _waitForSubmittedItems() async {
    if (_submittedItemsAreComplete) return;
    final signal = Completer<void>();
    _stopCompletionSignal = signal;
    await Future.any<void>(<Future<void>>[
      signal.future,
      _sleep(_stopWaitTimeout),
    ]);
    if (identical(_stopCompletionSignal, signal)) {
      _stopCompletionSignal = null;
    }
  }

  bool get _submittedItemsAreComplete {
    if (_lastCommittedEndSample < _lastSentEndSample) return false;
    return _itemStates.values
        .where((item) => item.endSample != null)
        .every((item) => item.isFinal);
  }

  void _notifyStopWaiterIfReady() {
    final signal = _stopCompletionSignal;
    if (signal != null && !signal.isCompleted && _submittedItemsAreComplete) {
      signal.complete();
    }
  }

  void _finalizeKnownGaps(Duration recordingDuration) {
    for (final item in _itemStates.values) {
      if (item.endSample != null && !item.isFinal) {
        _addGapSamples(
          item.startSample ?? 0,
          item.endSample!,
          'unfinished_item',
        );
      } else if (item.isFinal &&
          (item.ordinal == null ||
              item.startSample == null ||
              item.endSample == null)) {
        _addGapSamples(0, 0, 'missing_turn_timeline');
      }
    }

    if (_lastCommittedEndSample < _lastSentEndSample) {
      _addGapSamples(
        _lastCommittedEndSample,
        _lastSentEndSample,
        'uncommitted_audio',
      );
    }

    final sampleRate = _config!.sampleRate;
    final durationSamples =
        recordingDuration.inMicroseconds * sampleRate ~/ 1000000;
    final requiredEndSample = math.max(
      durationSamples,
      _largestObservedEndSample,
    );
    final intervals =
        _itemStates.values
            .where(
              (item) =>
                  item.isFinal &&
                  item.startSample != null &&
                  item.endSample != null,
            )
            .toList()
          ..sort(
            (left, right) => left.startSample!.compareTo(right.startSample!),
          );
    var coveredUntil = 0;
    for (final item in intervals) {
      if (item.startSample! > coveredUntil) {
        _addGapSamples(
          coveredUntil,
          item.startSample!,
          'incomplete_audio_coverage',
        );
      }
      coveredUntil = math.max(coveredUntil, item.endSample!);
    }
    if (coveredUntil < requiredEndSample) {
      _addGapSamples(
        coveredUntil,
        requiredEndSample,
        'incomplete_audio_coverage',
      );
    }
    if (intervals.isEmpty && requiredEndSample == 0) {
      _addGapSamples(0, 0, 'no_completed_transcript');
    }
  }

  void _addGapSamples(int startSample, int endSample, String reason) {
    final sampleRate = _config?.sampleRate ?? AudioFrame.canonicalSampleRate;
    final safeStart = math.max(0, math.min(startSample, endSample));
    final safeEnd = math.max(safeStart, math.max(startSample, endSample));
    final start = _durationForSamples(safeStart, sampleRate);
    final end = _durationForSamples(safeEnd, sampleRate);
    final last = _gaps.isEmpty ? null : _gaps.last;
    if (last != null && last.reason == reason && start <= last.end) {
      _gaps[_gaps.length - 1] = TranscriptGap(
        start: last.start,
        end: end > last.end ? end : last.end,
        reason: reason,
      );
    } else if (!_gaps.any(
      (gap) => gap.start == start && gap.end == end && gap.reason == reason,
    )) {
      _gaps.add(TranscriptGap(start: start, end: end, reason: reason));
    }
    _emitChange();
  }

  void _handleAudioStreamError(Object error, StackTrace stackTrace) {
    _lastError = error;
    _addGapSamples(
      _lastObservedFrame?.endSample ?? 0,
      _lastObservedFrame?.endSample ?? 0,
      'audio_frame_stream_error',
    );
  }

  void _handleEventStreamError(Object error, StackTrace stackTrace) {
    _transportLost(error);
    _emitChange();
  }

  Future<void> _abortSafely() async {
    try {
      await _client.abort();
    } on Object catch (error) {
      _lastError = error;
    }
  }

  void _setAudioSendingEnabled(bool value) {
    _audioSendingEnabled = value && !_capturePaused && !_stopping;
  }

  void _emitChange() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopping = true;
    ++_connectionEpoch;
    _audioSendingEnabled = false;
    unawaited(_audioSubscription?.cancel());
    unawaited(_eventSubscription?.cancel());
    unawaited(_abortSafely());
    super.dispose();
  }

  static Future<void> _defaultSleep(Duration duration) =>
      Future<void>.delayed(duration);

  static double _defaultRandom() => math.Random().nextDouble();

  static Duration _durationForSamples(int samples, int sampleRate) => Duration(
    microseconds: samples * Duration.microsecondsPerSecond ~/ sampleRate,
  );
}

final class _LiveItemState {
  _LiveItemState(this.itemId);

  final String itemId;
  final Map<int, String> draftContent = <int, String>{};
  final Map<int, String> completedContent = <int, String>{};
  String? previousItemId;
  int? startSample;
  int? endSample;
  int? ordinal;
  String? persistedFingerprint;

  bool get isFinal => completedContent.isNotEmpty && draftContent.isEmpty;

  String get completedText => _joinContent(completedContent);

  String get displayText {
    final combined = <int, String>{...draftContent, ...completedContent};
    return _joinContent(combined);
  }

  static String _joinContent(Map<int, String> content) {
    final indexes = content.keys.toList()..sort();
    return indexes.map((index) => content[index]!).join();
  }
}
