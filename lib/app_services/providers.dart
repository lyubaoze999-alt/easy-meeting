import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/configuration.dart';
import '../domain/models/meeting_note.dart';
import '../domain/models/meeting_record.dart';
import '../domain/models/platform_profile.dart';
import '../domain/models/recording_asset.dart';
import '../domain/models/transcript_document.dart';
import 'app_services.dart';
import 'meeting_asset_lifecycle.dart';

final appServicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices 尚未初始化。'),
);

final platformProfileProvider = Provider<PlatformProfile>(
  (ref) => PlatformProfile.current(),
);

final meetingSessionProvider = ChangeNotifierProvider(
  (ref) => ref.watch(appServicesProvider).session,
);

final liveTranscriptionProvider = ChangeNotifierProvider(
  (ref) => ref.watch(appServicesProvider).liveTranscription,
);

final postProcessingProvider = Provider(
  (ref) => ref.watch(appServicesProvider).postProcessing,
);

final settingsProvider =
    StateNotifierProvider<SettingsController, AsyncValue<AppSettings>>(
      (ref) => SettingsController(ref.watch(appServicesProvider)),
    );

class SettingsController extends StateNotifier<AsyncValue<AppSettings>> {
  SettingsController(this.services) : super(const AsyncValue.loading()) {
    reload();
  }

  final AppServices services;

  Future<void> reload() async {
    state = await AsyncValue.guard(services.settings.load);
  }

  Future<void> save(
    AppSettings settings, {
    String? realtimeApiKey,
    String? transcriptionApiKey,
    String? summaryApiKey,
  }) async {
    state = AsyncValue.data(settings);
    try {
      await services.settings.save(
        settings,
        realtimeApiKey: realtimeApiKey,
        transcriptionApiKey: transcriptionApiKey,
        summaryApiKey: summaryApiKey,
      );
      await reload();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final notesProvider =
    StateNotifierProvider<NotesController, AsyncValue<List<MeetingNote>>>(
      (ref) => NotesController(ref.watch(appServicesProvider))..load(),
    );

class NotesController extends StateNotifier<AsyncValue<List<MeetingNote>>> {
  NotesController(this.services) : super(const AsyncValue.loading());
  final AppServices services;

  Future<void> load({String query = ''}) async {
    state = await AsyncValue.guard(() => services.notes.list(query: query));
  }

  Future<void> moveToTrash(String id) async {
    await services.notes.moveToTrash(id);
    await load();
  }
}

class MeetingAssetBundle {
  const MeetingAssetBundle({
    required this.meeting,
    this.recording,
    this.transcript,
    this.note,
    this.transcriptText,
  });

  final MeetingRecord meeting;
  final RecordingAsset? recording;
  final TranscriptDocument? transcript;
  final MeetingNote? note;
  final String? transcriptText;
}

final meetingLibraryProvider =
    StateNotifierProvider<
      MeetingLibraryController,
      AsyncValue<List<MeetingAssetBundle>>
    >(
      (ref) => MeetingLibraryController(ref.watch(appServicesProvider))..load(),
    );

class MeetingLibraryController
    extends StateNotifier<AsyncValue<List<MeetingAssetBundle>>> {
  MeetingLibraryController(this.services) : super(const AsyncValue.loading());

  final AppServices services;

  Future<void> load({String query = ''}) async {
    state = await AsyncValue.guard(() async {
      final meetings = await services.meetings.list(query: query);
      final notes = await services.notes.list(query: query);
      final notesByMeeting = <String, MeetingNote>{
        for (final note in notes)
          if (note.meetingId != null) note.meetingId!: note,
      };
      return Future.wait(
        meetings.map((meeting) async {
          final recording = await services.recordings.loadForMeeting(
            meeting.id,
          );
          final transcript = await services.transcripts.finalForMeeting(
            meeting.id,
          );
          String? transcriptText;
          final bodyPath = transcript?.bodyPath;
          if (bodyPath != null) {
            final body = File(bodyPath);
            if (await body.exists()) transcriptText = await body.readAsString();
          }
          return MeetingAssetBundle(
            meeting: meeting,
            recording: recording,
            transcript: transcript,
            note: notesByMeeting[meeting.id],
            transcriptText: transcriptText,
          );
        }),
      );
    });
  }

  Future<void> moveMeetingToTrash(String meetingId) async {
    await services.meetings.moveToTrash(meetingId);
    await load();
  }

  Future<void> moveRecordingToTrash(String recordingId) async {
    await services.recordings.moveToTrash(recordingId);
    await load();
  }
}

final trashProvider =
    StateNotifierProvider<TrashController, AsyncValue<List<MeetingNote>>>(
      (ref) => TrashController(ref.watch(appServicesProvider))..load(),
    );

class TrashController extends StateNotifier<AsyncValue<List<MeetingNote>>> {
  TrashController(this.services) : super(const AsyncValue.loading());
  final AppServices services;

  Future<void> load() async {
    state = await AsyncValue.guard(services.notes.listTrash);
  }

  Future<void> restore(String id) async {
    await services.notes.restore(id);
    await load();
  }

  Future<void> permanentlyDelete(String id) async {
    await services.notes.permanentlyDelete(id);
    await load();
  }
}

final meetingTrashProvider =
    StateNotifierProvider<
      MeetingTrashController,
      AsyncValue<List<TrashedMeetingBundle>>
    >((ref) => MeetingTrashController(ref.watch(appServicesProvider))..load());

class MeetingTrashController
    extends StateNotifier<AsyncValue<List<TrashedMeetingBundle>>> {
  MeetingTrashController(this.services) : super(const AsyncValue.loading());

  final AppServices services;

  Future<void> load() async {
    state = await AsyncValue.guard(services.meetingAssets.listTrash);
  }

  Future<void> restore(String meetingId) async {
    await services.meetingAssets.restore(meetingId);
    await load();
  }

  Future<void> permanentlyDelete(String meetingId) async {
    await services.meetingAssets.permanentlyDelete(meetingId);
    await load();
  }
}

class IndependentAssetTrash {
  const IndependentAssetTrash({
    required this.recordings,
    required this.transcripts,
  });

  final List<RecordingAsset> recordings;
  final List<TranscriptDocument> transcripts;
}

final independentAssetTrashProvider =
    StateNotifierProvider<
      IndependentAssetTrashController,
      AsyncValue<IndependentAssetTrash>
    >(
      (ref) =>
          IndependentAssetTrashController(ref.watch(appServicesProvider))
            ..load(),
    );

class IndependentAssetTrashController
    extends StateNotifier<AsyncValue<IndependentAssetTrash>> {
  IndependentAssetTrashController(this.services)
    : super(const AsyncValue.loading());

  final AppServices services;

  Future<void> load() async {
    state = await AsyncValue.guard(
      () async => IndependentAssetTrash(
        recordings: await services.recordings.listTrash(),
        transcripts: await services.transcripts.listTrash(),
      ),
    );
  }

  Future<void> restoreRecording(String id) async {
    await services.recordings.restore(id);
    await load();
  }

  Future<void> deleteRecording(String id) async {
    await services.recordings.permanentlyDelete(id);
    await load();
  }

  Future<void> restoreTranscript(String id) async {
    await services.transcripts.restore(id);
    await load();
  }

  Future<void> deleteTranscript(String id) async {
    await services.transcripts.permanentlyDelete(id);
    await load();
  }
}
