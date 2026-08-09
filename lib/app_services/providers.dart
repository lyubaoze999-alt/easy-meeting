import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/asset_status.dart';
import '../domain/models/configuration.dart';
import '../domain/models/meeting_note.dart';
import '../domain/models/meeting_record.dart';
import '../domain/models/platform_profile.dart';
import '../domain/models/processing_job.dart';
import '../domain/models/recording_asset.dart';
import '../domain/models/transcript_document.dart';
import 'app_services.dart';
import 'meeting_asset_lifecycle.dart';
import 'recording_recovery_service.dart';

final appServicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices 尚未初始化。'),
);

final platformProfileProvider = Provider<PlatformProfile>(
  (ref) => PlatformProfile.current(),
);

/// A one-shot deep-link request to open the library and preselect a specific
/// meeting. Written by the recording-prep "recent meetings" section; the shell
/// listens, switches to the library tab, and clears it after the frame so the
/// same meeting can be re-navigated to later. `null` means no pending request.
final selectedMeetingIdProvider = StateProvider<String?>((ref) => null);

final meetingSessionProvider = ChangeNotifierProvider(
  (ref) => ref.watch(appServicesProvider).session,
);

final liveTranscriptionProvider = ChangeNotifierProvider(
  (ref) => ref.watch(appServicesProvider).liveTranscription,
);

final postProcessingProvider = Provider(
  (ref) => ref.watch(appServicesProvider).postProcessing,
);

final recordingRecoveryProvider =
    ChangeNotifierProvider<RecordingRecoveryService>(
      (ref) => ref.watch(appServicesProvider).recordingRecovery,
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
    this.recordingStatus,
    this.noteStatus,
  });

  final MeetingRecord meeting;
  final RecordingAsset? recording;
  final TranscriptDocument? transcript;
  final MeetingNote? note;
  final String? transcriptText;

  /// Real asset status, projected from the file on disk and the Job queue
  /// (R-04). `null` means "not yet projected" and the UI falls back to its
  /// default.
  final RecordingDisplayStatus? recordingStatus;
  final MeetingNoteDisplayStatus? noteStatus;
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
      // Search (R-10) must also match the formal transcript body text, which
      // lives on disk rather than in the repository, so we load every meeting
      // and filter in Dart. The 250ms debounce in the UI keeps this cheap.
      final meetings = await services.meetings.list();
      final notes = await services.notes.list();
      final notesByMeeting = <String, MeetingNote>{
        for (final note in notes)
          if (note.meetingId != null) note.meetingId!: note,
      };
      final jobs = await services.jobs.recoverable();
      final trimmed = query.trim().toLowerCase();
      final bundles = <MeetingAssetBundle>[];
      for (final meeting in meetings) {
        final recording = await services.recordings.loadForMeeting(meeting.id);
        final transcript = await services.transcripts.finalForMeeting(
          meeting.id,
        );
        String? transcriptText;
        final bodyPath = transcript?.bodyPath;
        if (bodyPath != null) {
          final body = File(bodyPath);
          if (await body.exists()) transcriptText = await body.readAsString();
        }
        final note = notesByMeeting[meeting.id];
        final bundle = MeetingAssetBundle(
          meeting: meeting,
          recording: recording,
          transcript: transcript,
          note: note,
          transcriptText: transcriptText,
          recordingStatus: _projectRecordingStatus(recording),
          noteStatus: _projectNoteStatus(note, meeting.id, jobs),
        );
        if (trimmed.isEmpty || _matchesQuery(bundle, trimmed)) {
          bundles.add(bundle);
        }
      }
      return bundles;
    });
  }

  /// R-04 — recording state comes from the real file, never an optimistic default.
  static RecordingDisplayStatus _projectRecordingStatus(
    RecordingAsset? recording,
  ) {
    if (recording == null) return RecordingDisplayStatus.missing;
    final path = recording.path;
    if (path.isEmpty) return RecordingDisplayStatus.damaged;
    final file = File(path);
    if (!file.existsSync()) return RecordingDisplayStatus.damaged;
    if (file.lengthSync() <= 0) return RecordingDisplayStatus.damaged;
    return RecordingDisplayStatus.playable;
  }

  /// R-04 — summary state comes from the noteSummary Job queue. A failed job
  /// wins over a residual note; an active job means processing.
  static MeetingNoteDisplayStatus _projectNoteStatus(
    MeetingNote? note,
    String meetingId,
    List<ProcessingJob> jobs,
  ) {
    var hasFailed = false;
    var hasActive = false;
    for (final job in jobs) {
      if (job.meetingId != meetingId || job.jobType != JobType.noteSummary) {
        continue;
      }
      if (job.stage == ProcessingStage.failed) {
        hasFailed = true;
      } else if (job.stage != ProcessingStage.done) {
        hasActive = true;
      }
    }
    if (hasFailed) return MeetingNoteDisplayStatus.failed;
    if (hasActive) return MeetingNoteDisplayStatus.processing;
    if (note == null) return MeetingNoteDisplayStatus.notGenerated;
    return MeetingNoteDisplayStatus.ready;
  }

  /// R-10 — a query matches the meeting template, the note (title + sections),
  /// or the formal transcript body text.
  static bool _matchesQuery(MeetingAssetBundle bundle, String query) {
    final note = bundle.note;
    final buffer = StringBuffer()
      ..write(bundle.meeting.id)
      ..write(' ')
      ..write(bundle.meeting.templateSnapshot.name)
      ..write(' ')
      ..write(bundle.meeting.templateSnapshot.instruction)
      ..write(' ')
      ..write(note?.title ?? '');
    if (note != null) {
      for (final section in note.sections) {
        buffer
          ..write(' ')
          ..write(section.heading)
          ..write(' ')
          ..write(section.content);
      }
    }
    buffer
      ..write(' ')
      ..write(bundle.transcriptText ?? '');
    return buffer.toString().toLowerCase().contains(query);
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
