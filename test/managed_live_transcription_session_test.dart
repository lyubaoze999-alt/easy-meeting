import 'dart:async';
import 'dart:typed_data';

import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:easy_meeting/app_services/managed_live_transcription_session.dart';
import 'package:easy_meeting/app_services/meeting_session_state.dart';
import 'package:easy_meeting/app_services/persistent_meeting_capture.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/domain/models/configuration.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/domain/models/transcript_segment.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_client.dart';
import 'package:easy_meeting/domain/realtime/realtime_transcription_events.dart';
import 'package:easy_meeting/infrastructure/repositories/meeting_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/recording_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/transcript_repository.dart';
import 'package:easy_meeting/infrastructure/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManagedLiveTranscriptionSession meeting ownership', () {
    test(
      'close cancels a pending connect before a new meeting starts',
      () async {
        final settings = _ControlledSettingsStore(delayFirstLoad: true);
        final fixture = _Fixture(settings: settings);
        addTearDown(fixture.dispose);

        fixture.capture.activeMeetingId = 'meeting-a';
        final firstConnect = fixture.managed.connect();
        await settings.firstLoadStarted.future;

        await fixture.managed.close();
        fixture.capture.activeMeetingId = 'meeting-b';
        await fixture.managed.connect();
        settings.releaseFirstLoad();
        await firstConnect;

        expect(fixture.clients, hasLength(1));
        expect(fixture.repository.createdForMeetings, <String>['meeting-b']);

        fixture.audio.add(_frame());
        await _waitUntil(() => fixture.clients.single.appended.length == 1);
        expect(fixture.clients.single.appended, hasLength(1));
      },
    );

    test(
      'events from a finishing meeting cannot affect the new meeting',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.repository.delayRepairFor('meeting-a');

        fixture.capture.activeMeetingId = 'meeting-a';
        await fixture.managed.connect();
        await fixture.managed.close();
        await fixture.repository.repairStartedFor('meeting-a');

        fixture.capture.activeMeetingId = 'meeting-b';
        await fixture.managed.connect();
        final current = fixture.managed.current;
        final events = <RealtimeTranscriptEvent>[];
        final subscription = fixture.managed.events.listen(events.add);
        addTearDown(subscription.cancel);

        fixture.repository.releaseRepairFor('meeting-a');
        await _waitUntil(
          () => fixture.managed.stopResultForMeeting('meeting-a') != null,
        );

        expect(events, isEmpty);
        expect(fixture.managed.current, same(current));
        expect(fixture.managed.phase, LiveTranscriptPhase.streaming);
      },
    );

    test(
      'drain waits for every meeting and results remain meeting-scoped',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.repository.delayRepairFor('meeting-a');

        fixture.capture.activeMeetingId = 'meeting-a';
        await fixture.managed.connect();
        await fixture.managed.close();
        await fixture.repository.repairStartedFor('meeting-a');

        fixture.capture.activeMeetingId = 'meeting-b';
        await fixture.managed.connect();
        await fixture.managed.close();
        await _waitUntil(
          () => fixture.managed.stopResultForMeeting('meeting-b') != null,
        );
        fixture.capture.lastMeetingId = 'meeting-b';

        expect(fixture.managed.hasPendingFinalization, isTrue);
        var drained = false;
        final drain = fixture.managed.drain().then((_) => drained = true);
        await pumpEventQueue();
        expect(drained, isFalse);

        fixture.repository.releaseRepairFor('meeting-a');
        await drain;

        expect(fixture.managed.hasPendingFinalization, isFalse);
        expect(
          fixture.managed.stopResultForMeeting('meeting-a')?.draft.meetingId,
          'meeting-a',
        );
        expect(
          fixture.managed.stopResultForMeeting('meeting-b')?.draft.meetingId,
          'meeting-b',
        );
        expect(fixture.managed.lastStopResult?.draft.meetingId, 'meeting-b');
      },
    );

    test(
      'coalesces streaming UI notifications but emits events immediately',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);
        fixture.capture.activeMeetingId = 'meeting-a';
        await fixture.managed.connect();

        var notifications = 0;
        var events = 0;
        fixture.managed.addListener(() => notifications += 1);
        final subscription = fixture.managed.events.listen((_) => events += 1);
        addTearDown(subscription.cancel);

        for (var index = 0; index < 10; index += 1) {
          fixture.clients.single.emit(
            TranscriptDelta(
              itemId: 'item-a',
              contentIndex: 0,
              delta: '$index',
              draftTranscript: 'draft-$index',
            ),
          );
        }

        expect(events, 10);
        expect(notifications, 0);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(notifications, 1);
      },
    );
  });
}

const _settings = AppSettings(
  realtimeTranscription: RealtimeServiceConfig(
    websocketUrl: 'wss://example.test/realtime',
    model: 'test-model',
    enabled: true,
    uploadConsentGranted: true,
    hasApiKey: true,
  ),
);

AudioFrame _frame() => AudioFrame(
  sessionId: 'native-session',
  sequence: 0,
  startSample: 0,
  sampleRate: AudioFrame.canonicalSampleRate,
  channels: AudioFrame.canonicalChannels,
  bytes: Uint8List(2),
);

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    if (predicate()) return;
    await pumpEventQueue(times: 1);
  }
  fail('condition was not reached');
}

final class _Fixture {
  _Fixture({_ControlledSettingsStore? settings})
    : audio = StreamController<AudioFrame>.broadcast(sync: true),
      repository = _MeetingScopedTranscriptRepository(),
      settings = settings ?? _ControlledSettingsStore() {
    recording = RecordingCoordinator(
      capture: AudioCapture(platform: _AudioPlatform(audio.stream)),
    );
    capture = PersistentMeetingCapture(
      coordinator: recording,
      meetings: _UnusedMeetingRepository(),
      recordings: _UnusedRecordingRepository(),
    );
    managed = ManagedLiveTranscriptionSession(
      recording: recording,
      persistentCapture: capture,
      transcripts: repository,
      settings: this.settings,
      clientFactory: () {
        final client = _FakeRealtimeClient();
        clients.add(client);
        return client;
      },
    );
  }

  final StreamController<AudioFrame> audio;
  final _MeetingScopedTranscriptRepository repository;
  final _ControlledSettingsStore settings;
  final List<_FakeRealtimeClient> clients = <_FakeRealtimeClient>[];
  late final RecordingCoordinator recording;
  late final PersistentMeetingCapture capture;
  late final ManagedLiveTranscriptionSession managed;

  Future<void> dispose() async {
    settings.releaseFirstLoad();
    repository.releaseAllRepairs();
    await managed.shutdown();
    managed.dispose();
    recording.dispose();
    await audio.close();
    for (final client in clients) {
      await client.closeEvents();
    }
  }
}

final class _ControlledSettingsStore extends SettingsStore {
  _ControlledSettingsStore({this.delayFirstLoad = false});

  final bool delayFirstLoad;
  final Completer<void> firstLoadStarted = Completer<void>();
  final Completer<void> _firstLoadGate = Completer<void>();
  int _loadCalls = 0;

  @override
  Future<AppSettings> load() async {
    _loadCalls += 1;
    if (delayFirstLoad && _loadCalls == 1) {
      firstLoadStarted.complete();
      await _firstLoadGate.future;
    }
    return _settings;
  }

  void releaseFirstLoad() {
    if (!_firstLoadGate.isCompleted) _firstLoadGate.complete();
  }
}

final class _FakeRealtimeClient implements RealtimeTranscriptionClient {
  final StreamController<RealtimeTranscriptEvent> _events =
      StreamController<RealtimeTranscriptEvent>.broadcast(sync: true);
  final List<RealtimeAudioFrame> appended = <RealtimeAudioFrame>[];
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;

  @override
  Stream<RealtimeTranscriptEvent> get events => _events.stream;

  @override
  RealtimeConnectionState get connectionState => _state;

  @override
  Future<void> connect(RealtimeTranscriptionConfig config) async {
    _state = RealtimeConnectionState.connected;
  }

  @override
  Future<void> append(RealtimeAudioFrame frame) async {
    appended.add(frame);
  }

  @override
  Future<void> commitTurn() async {}

  @override
  Future<void> flushAndClose() async {
    _state = RealtimeConnectionState.closed;
  }

  @override
  Future<void> abort() async {
    _state = RealtimeConnectionState.closed;
  }

  void emit(RealtimeTranscriptEvent event) => _events.add(event);

  Future<void> closeEvents() => _events.close();
}

final class _MeetingScopedTranscriptRepository implements TranscriptRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<String> createdForMeetings = <String>[];
  final Map<String, TranscriptDocument> _draftsByMeeting =
      <String, TranscriptDocument>{};
  final Map<String, Completer<void>> _repairGates = <String, Completer<void>>{};
  final Map<String, Completer<void>> _repairStarted =
      <String, Completer<void>>{};

  void delayRepairFor(String meetingId) {
    _repairGates[meetingId] = Completer<void>();
    _repairStarted[meetingId] = Completer<void>();
  }

  Future<void> repairStartedFor(String meetingId) =>
      _repairStarted[meetingId]!.future;

  void releaseRepairFor(String meetingId) {
    final gate = _repairGates[meetingId];
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void releaseAllRepairs() {
    for (final gate in _repairGates.values) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<TranscriptDocument> createRealtimeDraft(String meetingId) async {
    createdForMeetings.add(meetingId);
    return _draftsByMeeting.putIfAbsent(
      meetingId,
      () => _document('draft-$meetingId', meetingId),
    );
  }

  @override
  Future<void> upsertDeltaSnapshot(TranscriptDeltaSnapshot snapshot) async {}

  @override
  Future<void> saveCompletedSegment(TranscriptSegment segment) async {}

  @override
  Future<TranscriptDocument> freeze(
    String draftId, {
    required int revision,
  }) async {
    final draft = _draftForId(draftId);
    return TranscriptDocument(
      id: 'final-${draft.meetingId}',
      meetingId: draft.meetingId,
      kind: TranscriptKind.finalTranscript,
      status: TranscriptStatus.ready,
      coveredDuration: Duration.zero,
      revision: revision,
      createdAt: draft.createdAt,
      updatedAt: draft.updatedAt,
    );
  }

  @override
  Future<void> markNeedsRepair(String id, List<TranscriptGap> gaps) async {
    final meetingId = _draftForId(id).meetingId;
    final started = _repairStarted[meetingId];
    if (started != null && !started.isCompleted) started.complete();
    await _repairGates[meetingId]?.future;
  }

  @override
  Future<TranscriptDocument?> finalForMeeting(String meetingId) async => null;

  @override
  Future<TranscriptDocument?> load(String id) async {
    for (final draft in _draftsByMeeting.values) {
      if (draft.id == id) return draft;
    }
    return null;
  }

  @override
  Future<List<TranscriptSegment>> segments(String transcriptId) async =>
      const <TranscriptSegment>[];

  TranscriptDocument _draftForId(String id) =>
      _draftsByMeeting.values.singleWhere((draft) => draft.id == id);
}

TranscriptDocument _document(String id, String meetingId) => TranscriptDocument(
  id: id,
  meetingId: meetingId,
  kind: TranscriptKind.realtimeDraft,
  status: TranscriptStatus.collecting,
  coveredDuration: Duration.zero,
  revision: 0,
  createdAt: DateTime.utc(2026, 8, 3),
  updatedAt: DateTime.utc(2026, 8, 3),
);

final class _AudioPlatform extends AudioCapturePlatform {
  _AudioPlatform(this.frames);

  final Stream<AudioFrame> frames;

  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Stream<AudioFrame> get pcmFrames => frames;

  @override
  Future<Map<String, Object?>> start() async => const <String, Object?>{};

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async => '/tmp/unused.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async =>
      const <String, Object?>{};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

final class _UnusedMeetingRepository implements MeetingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedRecordingRepository implements RecordingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
