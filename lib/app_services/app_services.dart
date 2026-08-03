import '../domain/summary/summary_service.dart';
import '../domain/transcription/transcription_service.dart';
import '../domain/transcription/wav_slicer.dart';
import '../infrastructure/database/app_database.dart';
import '../infrastructure/diagnostics/diagnostic_reporter.dart';
import '../infrastructure/network/openai_compatible_client.dart';
import '../infrastructure/notifications/completion_notifier.dart';
import '../infrastructure/repositories/note_repository.dart';
import '../infrastructure/repositories/processing_job_repository.dart';
import '../infrastructure/settings/settings_store.dart';
import 'meeting_session_controller.dart';
import 'processing_pipeline.dart';
import 'recording_coordinator.dart';

class AppServices {
  AppServices({
    required this.database,
    required this.notes,
    required this.jobs,
    required this.settings,
    required this.diagnostics,
    required this.notifications,
    required this.recording,
    required this.processing,
    required this.session,
  });

  final AppDatabase database;
  final NoteRepository notes;
  final ProcessingJobRepository jobs;
  final SettingsStore settings;
  final DiagnosticReporter diagnostics;
  final CompletionNotifier notifications;
  final RecordingCoordinator recording;
  final ProcessingPipeline processing;
  final MeetingSessionController session;

  static Future<AppServices> create() async {
    final database = await AppDatabase.open();
    final notes = await LocalNoteRepository.open(database);
    final jobs = LocalProcessingJobRepository(database);
    final settings = SettingsStore();
    final diagnostics = await LocalDiagnosticReporter.open();
    final notifications = await LocalCompletionNotifier.open();
    final client = OpenAICompatibleClient();
    final recording = RecordingCoordinator();
    final processing = ProcessingPipeline(
      transcriptionService: TranscriptionService(
        client: client,
        slicer: const WavSlicer(),
      ),
      summaryService: SummaryService(client),
      noteRepository: notes,
      jobRepository: jobs,
      diagnostics: diagnostics,
      notifier: notifications,
      settingsProvider: settings.load,
    );
    final session = MeetingSessionController(
      recording: recording,
      processing: processing,
    );
    await notes.purgeExpired();
    return AppServices(
      database: database,
      notes: notes,
      jobs: jobs,
      settings: settings,
      diagnostics: diagnostics,
      notifications: notifications,
      recording: recording,
      processing: processing,
      session: session,
    );
  }

  Future<void> close() async {
    session.dispose();
    recording.dispose();
    processing.dispose();
    await database.close();
  }
}
