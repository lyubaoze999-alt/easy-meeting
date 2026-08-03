import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/configuration.dart';
import '../domain/models/meeting_note.dart';
import '../domain/models/platform_profile.dart';
import 'app_services.dart';

final appServicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices 尚未初始化。'),
);

final platformProfileProvider = Provider<PlatformProfile>(
  (ref) => PlatformProfile.current(),
);

final meetingSessionProvider = ChangeNotifierProvider(
  (ref) => ref.watch(appServicesProvider).session,
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

  Future<void> save(AppSettings settings) async {
    state = AsyncValue.data(settings);
    try {
      await services.settings.save(settings);
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
