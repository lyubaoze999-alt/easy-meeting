import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app_services/app_services.dart';
import '../app_services/recording_coordinator.dart';
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
    services.recording.addListener(_refresh);
    services.processing.addListener(_refresh);
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
    final recording = services.recording;
    final processing = services.processing;
    final state = switch (recording.state) {
      RecordingState.recording => '正在录音 ${_duration(recording.elapsed)}',
      RecordingState.paused => '录音已暂停 ${_duration(recording.elapsed)}',
      RecordingState.finished when processing.stage == ProcessingStage.failed =>
        '处理失败，可重试',
      RecordingState.finished when processing.stage == ProcessingStage.done =>
        '纪要已生成',
      RecordingState.finished => _stageName(processing.stage),
      RecordingState.idle when processing.isRunning => _stageName(
        processing.stage,
      ),
      RecordingState.idle => '准备记录',
    };
    final isRecording =
        recording.state == RecordingState.recording ||
        recording.state == RecordingState.paused;
    final exitBlocked = isRecording || processing.isRunning;
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
          if (isRecording)
            MenuItem(
              key: 'pause_resume',
              label: recording.state == RecordingState.paused ? '继续录音' : '暂停录音',
            ),
          if (isRecording) MenuItem(key: 'stop', label: '结束并生成纪要'),
          if (processing.stage == ProcessingStage.failed &&
              processing.currentJob != null)
            MenuItem(key: 'retry', label: '从上次成功阶段重试'),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: isRecording
                ? '录音中不可退出'
                : (processing.isRunning ? '处理中不可退出' : '退出'),
            disabled: exitBlocked,
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
        if (services.recording.state == RecordingState.paused) {
          services.recording.resume();
        } else {
          services.recording.pause();
        }
      case 'stop':
        _stopAndProcess();
      case 'retry':
        final job = services.processing.currentJob;
        if (job != null) services.processing.retry(job.id);
      case 'exit':
        _exit();
    }
  }

  Future<void> _stopAndProcess() async {
    try {
      final result = await services.recording.stop();
      await _showWindow();
      await services.processing.start(result);
    } catch (_) {
      await _showWindow();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exit() async {
    if (_exiting ||
        services.recording.state == RecordingState.recording ||
        services.recording.state == RecordingState.paused ||
        services.processing.isRunning) {
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

  static String _stageName(ProcessingStage stage) => switch (stage) {
    ProcessingStage.saving => '正在保存音频',
    ProcessingStage.transcribing => '正在语音转写',
    ProcessingStage.summarizing => '正在生成纪要',
    ProcessingStage.persisting => '正在保存纪要',
    ProcessingStage.done => '处理完成',
    ProcessingStage.failed => '处理失败',
  };
}
