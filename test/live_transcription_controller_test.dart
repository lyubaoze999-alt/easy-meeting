import 'dart:async';
import 'dart:typed_data';

import 'package:audio_capture/audio_frame.dart';
import 'package:easy_meeting/app_services/live_transcription_controller.dart';
import 'package:easy_meeting/app_services/meeting_session_state.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/domain/models/transcript_segment.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_client.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_events.dart';
import 'package:easy_meeting/infrastructure/repositories/transcript_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveTranscriptionController audio ownership', () {
    test(
      'converts AudioFrame and gates PCM synchronously while paused',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        await fixture.controller.start(meetingId: 'meeting-1', config: _config);

        fixture.audio.add(_frame(sequence: 0, startSample: 0));
        await _waitUntil(() => fixture.client.appended.length == 1);
        final sent = fixture.client.appended.single;
        expect(sent.sessionId, 'native-session');
        expect(sent.sequence, 0);
        expect(sent.startSample, 0);
        expect(sent.sampleRate, 24000);
        expect(sent.channels, 1);
        expect(sent.bytes.lengthInBytes, AudioFrame.canonicalBytesPerFrame);

        fixture.controller.onCapturePaused();
        expect(fixture.controller.audioSendingEnabled, isFalse);
        fixture.audio.add(_frame(sequence: 1, startSample: 4800));
        await pumpEventQueue();
        expect(fixture.client.appended, hasLength(1));

        fixture.controller.onCaptureResumed();
        fixture.audio.add(_frame(sequence: 2, startSample: 9600));
        await _waitUntil(() => fixture.client.appended.length == 2);
        expect(fixture.client.appended.map((frame) => frame.sequence), <int>[
          0,
          2,
        ]);
        expect(fixture.repository.completedSegments, isEmpty);
      },
    );

    test('drops queued PCM when pause advances the audio epoch', () async {
      final appendGate = Completer<void>();
      final client = _FakeRealtimeClient(appendGate: appendGate);
      final fixture = _Fixture(client: client);
      addTearDown(fixture.dispose);
      await fixture.controller.start(meetingId: 'meeting-1', config: _config);

      fixture.audio.add(_frame(sequence: 0, startSample: 0));
      fixture.audio.add(_frame(sequence: 1, startSample: 4800));
      await _waitUntil(() => client.appendCalls == 1);
      fixture.controller.onCapturePaused();
      appendGate.complete();
      await pumpEventQueue(times: 5);

      expect(client.appended.map((frame) => frame.sequence), [0]);
      expect(client.appendCalls, 1);
      expect(
        fixture.controller.gaps.any(
          (gap) => gap.reason == 'audio_gate_closed_before_send',
        ),
        isTrue,
      );
    });
  });

  group('LiveTranscriptionController reconnect policy', () {
    test(
      'backs off exponentially, records gaps, and never replays old PCM',
      () async {
        final sleeper = _ControlledSleeper();
        final client = _FakeRealtimeClient(
          connectResults: <Object?>[_retryableFailure, _retryableFailure, null],
        );
        final fixture = _Fixture(client: client, sleep: sleeper.call);
        addTearDown(fixture.dispose);

        await fixture.controller.start(meetingId: 'meeting-1', config: _config);
        expect(fixture.controller.phase, LiveTranscriptPhase.reconnecting);
        await _waitUntil(() => sleeper.calls.length == 1);
        expect(sleeper.calls, <Duration>[const Duration(seconds: 1)]);

        fixture.audio.add(_frame(sequence: 0, startSample: 0));
        await pumpEventQueue();
        sleeper.releaseNext();
        await _waitUntil(() => sleeper.calls.length == 2);
        expect(sleeper.calls, <Duration>[
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]);

        fixture.audio.add(_frame(sequence: 1, startSample: 4800));
        await pumpEventQueue();
        sleeper.releaseNext();
        await _waitUntil(
          () => fixture.controller.phase == LiveTranscriptPhase.streaming,
        );
        fixture.audio.add(_frame(sequence: 2, startSample: 9600));
        await _waitUntil(() => client.appended.length == 1);

        expect(client.appended.single.sequence, 2);
        expect(
          fixture.controller.gaps.any(
            (gap) => gap.reason == 'transport_unavailable',
          ),
          isTrue,
        );
        expect(client.connectCalls, 3);
      },
    );

    test('degrades after the injected continuous-failure window', () async {
      var clock = DateTime.utc(2026, 8, 3);
      final delays = <Duration>[];
      final client = _FakeRealtimeClient(alwaysFailConnect: true);
      final fixture = _Fixture(
        client: client,
        now: () => clock,
        sleep: (duration) async {
          delays.add(duration);
          clock = clock.add(duration);
        },
        retryPolicy: const LiveTranscriptionRetryPolicy(
          backoff: <Duration>[
            Duration(seconds: 1),
            Duration(seconds: 2),
            Duration(seconds: 4),
          ],
          jitterFraction: 0,
          degradeAfter: Duration(seconds: 3),
        ),
      );
      addTearDown(fixture.dispose);

      await fixture.controller.start(meetingId: 'meeting-1', config: _config);
      await _waitUntil(
        () => fixture.controller.phase == LiveTranscriptPhase.degraded,
      );

      expect(delays, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(fixture.controller.audioSendingEnabled, isFalse);
      expect(client.connectCalls, 2);
    });
  });

  group('LiveTranscriptionController turn assembly', () {
    test(
      'aggregates by item and persists completed turns in stable local order',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        await fixture.controller.start(meetingId: 'meeting-1', config: _config);

        fixture.client.emit(
          const TranscriptDelta(
            itemId: 'item-a',
            contentIndex: 0,
            delta: '草',
            draftTranscript: '草稿',
          ),
        );
        fixture.client.emit(
          const TranscriptCompleted(
            itemId: 'item-b',
            contentIndex: 0,
            transcript: '第二段',
          ),
        );
        fixture.client.emit(
          const TranscriptDelta(
            itemId: 'item-b',
            contentIndex: 1,
            delta: '！',
            draftTranscript: '！',
          ),
        );
        fixture.client.emit(
          const TranscriptTurnCommitted(
            itemId: 'item-b',
            previousItemId: 'item-a',
            endSample: 9600,
          ),
        );
        fixture.client.emit(
          const TranscriptCompleted(
            itemId: 'item-a',
            contentIndex: 0,
            transcript: '第一段',
          ),
        );
        fixture.client.emit(
          const TranscriptCompleted(
            itemId: 'item-b',
            contentIndex: 1,
            transcript: '！',
          ),
        );
        await pumpEventQueue();
        expect(fixture.repository.completedSegments, isEmpty);

        fixture.client.emit(
          const TranscriptTurnCommitted(itemId: 'item-a', endSample: 4800),
        );
        await _waitUntil(
          () => fixture.repository.completedSegments.length == 2,
        );

        final lines = fixture.controller.items;
        expect(lines.map((line) => line.itemId), <String>['item-a', 'item-b']);
        expect(lines.map((line) => line.ordinal), <int?>[0, 1]);
        expect(lines.map((line) => line.text), <String>['第一段', '第二段！']);
        expect(lines.every((line) => line.isFinal), isTrue);
        final segments = fixture.repository.completedSegments
          ..sort((left, right) => left.ordinal.compareTo(right.ordinal));
        expect(segments.map((segment) => segment.providerItemId), <String>[
          'item-a',
          'item-b',
        ]);
        expect(segments.map((segment) => segment.text), <String>[
          '第一段',
          '第二段！',
        ]);
        expect(segments.map((segment) => segment.start), <Duration>[
          Duration.zero,
          const Duration(milliseconds: 200),
        ]);

        final result = await fixture.controller.finish(
          recordingDuration: const Duration(milliseconds: 400),
        );
        expect(result.outcome, LiveTranscriptionStopOutcome.frozen);
        expect(result.finalTranscript, isNotNull);
        expect(fixture.repository.markedGaps, isEmpty);
      },
    );
  });

  group('LiveTranscriptionController stopping', () {
    test(
      'waits for a committed item and freezes when completion arrives',
      () async {
        final sleeper = _ControlledSleeper();
        final fixture = _Fixture(sleep: sleeper.call);
        addTearDown(fixture.dispose);
        await fixture.controller.start(meetingId: 'meeting-1', config: _config);
        fixture.client.emit(
          const TranscriptTurnCommitted(itemId: 'item-a', endSample: 4800),
        );

        final stopping = fixture.controller.finish(
          recordingDuration: const Duration(milliseconds: 200),
        );
        await _waitUntil(() => sleeper.calls.isNotEmpty);
        expect(sleeper.calls.single, const Duration(seconds: 8));
        expect(fixture.repository.freezeCalls, 0);

        fixture.client.emit(
          const TranscriptCompleted(
            itemId: 'item-a',
            contentIndex: 0,
            transcript: '及时完成',
          ),
        );
        final result = await stopping;
        expect(result.outcome, LiveTranscriptionStopOutcome.frozen);
        expect(fixture.repository.freezeCalls, 1);
      },
    );

    test(
      'times out at the injected limit and marks the draft for repair',
      () async {
        final sleeper = _ControlledSleeper();
        final fixture = _Fixture(sleep: sleeper.call);
        addTearDown(fixture.dispose);
        await fixture.controller.start(meetingId: 'meeting-1', config: _config);
        fixture.client.emit(
          const TranscriptTurnCommitted(itemId: 'item-a', endSample: 4800),
        );

        final stopping = fixture.controller.finish(
          recordingDuration: const Duration(milliseconds: 200),
        );
        await _waitUntil(() => sleeper.calls.isNotEmpty);
        expect(sleeper.calls.single, const Duration(seconds: 8));
        sleeper.releaseNext();
        final result = await stopping;

        expect(result.outcome, LiveTranscriptionStopOutcome.needsRepair);
        expect(fixture.repository.freezeCalls, 0);
        expect(
          fixture.repository.markedGaps.any(
            (gap) => gap.reason == 'unfinished_item',
          ),
          isTrue,
        );
      },
    );
  });
}

final RealtimeTranscriptionConfig _config = RealtimeTranscriptionConfig(
  websocketUrl: Uri(scheme: 'wss', host: 'realtime.example'),
  model: 'configured-model',
  secret: SecretReference('secure-storage-reference'),
);

const RealtimeClientException _retryableFailure = RealtimeClientException(
  code: 'network_unavailable',
  message: 'safe network failure',
  isRetryable: true,
);

AudioFrame _frame({required int sequence, required int startSample}) =>
    AudioFrame(
      sessionId: 'native-session',
      sequence: sequence,
      startSample: startSample,
      sampleRate: AudioFrame.canonicalSampleRate,
      channels: AudioFrame.canonicalChannels,
      bytes: Uint8List(AudioFrame.canonicalBytesPerFrame),
    );

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out while waiting for controller state.');
    }
    await pumpEventQueue(times: 1);
  }
}

final class _Fixture {
  _Fixture({
    _FakeRealtimeClient? client,
    LiveTranscriptionSleep? sleep,
    DateTime Function()? now,
    LiveTranscriptionRetryPolicy retryPolicy =
        const LiveTranscriptionRetryPolicy(jitterFraction: 0),
  }) : audio = StreamController<AudioFrame>.broadcast(sync: true),
       client = client ?? _FakeRealtimeClient(),
       repository = _FakeTranscriptRepository() {
    controller = LiveTranscriptionController(
      audioFrames: audio.stream,
      client: this.client,
      repository: repository,
      retryPolicy: retryPolicy,
      now: now,
      sleep: sleep,
      random: () => 0,
    );
  }

  final StreamController<AudioFrame> audio;
  final _FakeRealtimeClient client;
  final _FakeTranscriptRepository repository;
  late final LiveTranscriptionController controller;

  Future<void> dispose() async {
    controller.dispose();
    await audio.close();
    await client.close();
  }
}

final class _ControlledSleeper {
  final List<Duration> calls = <Duration>[];
  final List<Completer<void>> _pending = <Completer<void>>[];

  Future<void> call(Duration duration) {
    calls.add(duration);
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }

  void releaseNext() {
    final completer = _pending.removeAt(0);
    completer.complete();
  }
}

final class _FakeRealtimeClient implements RealtimeTranscriptionClient {
  _FakeRealtimeClient({
    List<Object?> connectResults = const <Object?>[],
    this.alwaysFailConnect = false,
    this.appendGate,
  }) : _connectResults = List<Object?>.of(connectResults);

  final StreamController<RealtimeTranscriptEvent> _events =
      StreamController<RealtimeTranscriptEvent>.broadcast(sync: true);
  final List<Object?> _connectResults;
  final bool alwaysFailConnect;
  final Completer<void>? appendGate;
  final List<RealtimeAudioFrame> appended = <RealtimeAudioFrame>[];
  int connectCalls = 0;
  int commitCalls = 0;
  int flushCalls = 0;
  int abortCalls = 0;
  int appendCalls = 0;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;

  @override
  Stream<RealtimeTranscriptEvent> get events => _events.stream;

  @override
  RealtimeConnectionState get connectionState => _state;

  @override
  Future<void> connect(RealtimeTranscriptionConfig config) async {
    connectCalls += 1;
    _state = RealtimeConnectionState.connecting;
    final result = _connectResults.isEmpty
        ? (alwaysFailConnect ? _retryableFailure : null)
        : _connectResults.removeAt(0);
    if (result is Object) {
      _state = RealtimeConnectionState.failed;
      throw result;
    }
    _state = RealtimeConnectionState.connected;
  }

  @override
  Future<void> append(RealtimeAudioFrame frame) async {
    if (_state != RealtimeConnectionState.connected) throw _retryableFailure;
    appendCalls += 1;
    await appendGate?.future;
    appended.add(frame);
  }

  @override
  Future<void> commitTurn() async {
    commitCalls += 1;
  }

  @override
  Future<void> flushAndClose() async {
    flushCalls += 1;
    _state = RealtimeConnectionState.closed;
  }

  @override
  Future<void> abort() async {
    abortCalls += 1;
    _state = RealtimeConnectionState.closed;
  }

  void emit(RealtimeTranscriptEvent event) => _events.add(event);

  Future<void> close() => _events.close();
}

final class _FakeTranscriptRepository implements TranscriptRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final TranscriptDocument draft = _document(
    id: 'draft-1',
    kind: TranscriptKind.realtimeDraft,
    status: TranscriptStatus.collecting,
    revision: 0,
  );
  final List<TranscriptSegment> completedSegments = <TranscriptSegment>[];
  final List<TranscriptGap> markedGaps = <TranscriptGap>[];
  int freezeCalls = 0;

  @override
  Future<TranscriptDocument> createRealtimeDraft(String meetingId) async =>
      draft;

  @override
  Future<void> upsertDeltaSnapshot(TranscriptDeltaSnapshot snapshot) async {}

  @override
  Future<void> saveCompletedSegment(TranscriptSegment segment) async {
    final index = completedSegments.indexWhere(
      (saved) => saved.providerItemId == segment.providerItemId,
    );
    if (index < 0) {
      completedSegments.add(segment);
    } else {
      completedSegments[index] = segment;
    }
  }

  @override
  Future<TranscriptDocument> freeze(
    String draftId, {
    required int revision,
  }) async {
    freezeCalls += 1;
    return _document(
      id: 'final-$revision',
      kind: TranscriptKind.finalTranscript,
      status: TranscriptStatus.ready,
      revision: revision,
    );
  }

  @override
  Future<void> markNeedsRepair(String id, List<TranscriptGap> gaps) async {
    markedGaps
      ..clear()
      ..addAll(gaps);
  }

  @override
  Future<TranscriptDocument?> finalForMeeting(String meetingId) async => null;

  @override
  Future<TranscriptDocument?> load(String id) async =>
      id == draft.id ? draft : null;

  @override
  Future<List<TranscriptSegment>> segments(String transcriptId) async =>
      List<TranscriptSegment>.of(completedSegments);
}

TranscriptDocument _document({
  required String id,
  required TranscriptKind kind,
  required TranscriptStatus status,
  required int revision,
}) => TranscriptDocument(
  id: id,
  meetingId: 'meeting-1',
  kind: kind,
  status: status,
  coveredDuration: Duration.zero,
  revision: revision,
  createdAt: DateTime.utc(2026, 8, 3),
  updatedAt: DateTime.utc(2026, 8, 3),
);
