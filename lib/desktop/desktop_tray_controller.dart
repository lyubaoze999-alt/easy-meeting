import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_services/app_services.dart';
import '../app_services/meeting_session_controller.dart';
import '../domain/models/processing_job.dart';

class DesktopTrayController with TrayListener, WindowListener {
  DesktopTrayController(this.services);

  final AppServices services;
  bool _exiting = false;
  String? _lastState;
  String? _lastTitle;

  Future<void> init() async {
    trayManager.addListener(this);
    windowManager.addListener(this);
    services.session.addListener(_refresh);
    await windowManager.setPreventClose(true);
    await trayManager.setIcon(
      Platform.isWindows
          ? 'windows/runner/resources/app_icon.ico'
          : 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png',
      isTemplate: Platform.isMacOS,
    );
    await trayManager.setToolTip('会议纪要');
    await _refresh();
  }

  Future<void> _refresh() async {
    final session = services.session;
    final recording = session.recording;
    final state = _sessionState(session);
    final isRecording =
        session.phase == MeetingSessionPhase.recording ||
        session.phase == MeetingSessionPhase.paused;
    final title = Platform.isMacOS && isRecording
        ? ' ● ${_duration(recording.elapsed)}'
        : '';
    if (state == _lastState && title == _lastTitle) return;
    _lastState = state;
    _lastTitle = title;
    await trayManager.setTitle(title);
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'status', label: state, disabled: true),
          MenuItem.separator(),
          MenuItem(key: 'show', label: '打开会议纪要'),
          if (session.phase == MeetingSessionPhase.recording ||
              session.phase == MeetingSessionPhase.paused)
            MenuItem(
              key: 'pause_resume',
              label: session.phase == MeetingSessionPhase.paused
                  ? '继续录音'
                  : '暂停录音',
            ),
          if (isRecording) MenuItem(key: 'stop', label: '结束并生成纪要'),
          if (session.phase == MeetingSessionPhase.failed &&
              session.processing.currentJob != null)
            MenuItem(key: 'retry', label: '从上次成功阶段重试'),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: session.blocksExit ? '当前任务进行中，不可退出' : '退出',
            disabled: session.blocksExit,
          ),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
      case 'pause_resume':
        if (services.session.phase == MeetingSessionPhase.paused) {
          unawaited(_runSessionCommand(services.session.resumeRecording));
        } else {
          unawaited(_runSessionCommand(services.session.pauseRecording));
        }
      case 'stop':
        unawaited(_runSessionCommand(services.session.stopAndProcess));
      case 'retry':
        unawaited(_runSessionCommand(services.session.retryProcessing));
      case 'exit':
        unawaited(_exit());
    }
  }

  Future<void> _runSessionCommand(Future<void> Function() command) async {
    try {
      await _showWindow();
      await command();
    } catch (_) {
      await _showWindow();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exit() async {
    if (_exiting || services.session.blocksExit) {
      return;
    }
    _exiting = true;
    await trayManager.destroy();
    await services.close();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onWindowClose() {
    if (!_exiting) windowManager.hide();
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String _sessionState(MeetingSessionController session) =>
      switch (session.phase) {
        MeetingSessionPhase.initializing => '正在恢复未完成任务',
        MeetingSessionPhase.ready => '准备记录',
        MeetingSessionPhase.starting => '正在启动录音',
        MeetingSessionPhase.recording =>
          '正在录音 ${_duration(session.recording.elapsed)}',
        MeetingSessionPhase.pausing => '正在暂停录音',
        MeetingSessionPhase.paused =>
          '录音已暂停 ${_duration(session.recording.elapsed)}',
        MeetingSessionPhase.resuming => '正在继续录音',
        MeetingSessionPhase.stopping => '正在结束录音',
        MeetingSessionPhase.processing => _stageName(session.processingStage),
        MeetingSessionPhase.completed => '纪要已生成',
        MeetingSessionPhase.failed => '处理失败，可重试',
      };

  static String _stageName(ProcessingStage stage) => switch (stage) {
    ProcessingStage.saving => '正在保存音频',
    ProcessingStage.transcribing => '正在语音转写',
    ProcessingStage.summarizing => '正在生成纪要',
    ProcessingStage.persisting => '正在保存纪要',
    ProcessingStage.done => '处理完成',
    ProcessingStage.failed => '处理失败',
  };
}
