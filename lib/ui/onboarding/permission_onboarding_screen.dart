import 'package:audio_capture/audio_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_services/providers.dart';
import '../../domain/models/platform_profile.dart';

class PermissionOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends ConsumerState<PermissionOnboardingScreen> {
  final capture = AudioCapture();
  AudioPermissionStatus? status;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      status = await capture.permissionStatus();
    } catch (_) {
      final microphone = await Permission.microphone.status;
      status = AudioPermissionStatus(
        systemAudioGranted: false,
        microphoneGranted: microphone.isGranted,
      );
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(platformProfileProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.graphic_eq, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        '开始使用会议纪要',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '录音和纪要只保存在本机。应用需要音频权限才能记录会议。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (profile.supportsSystemAudio)
                        _PermissionTile(
                          icon: Icons.volume_up_outlined,
                          title: '系统声音',
                          description: '用于记录线上会议中对方的声音。',
                          granted: status?.systemAudioGranted ?? false,
                          onTap: capture.openPermissionSettings,
                        )
                      else
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('当前平台仅支持麦克风录音'),
                            subtitle: Text(
                              profile.platform == PlatformKind.macos
                                  ? 'macOS 13.0–14.3 可正常使用；升级到 14.4+ 后可记录系统声音。'
                                  : 'iOS 无法采集其他应用播放的系统声音。',
                            ),
                          ),
                        ),
                      _PermissionTile(
                        icon: Icons.mic_none,
                        title: '麦克风',
                        description: '用于记录你自己的声音。',
                        granted: status?.microphoneGranted ?? false,
                        onTap: () async {
                          await Permission.microphone.request();
                          await _refresh();
                        },
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _complete,
                        child: const Text('进入应用'),
                      ),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('刷新权限状态'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _complete() async {
    final current = ref.read(settingsProvider).valueOrNull;
    if (current == null) return;
    await ref
        .read(settingsProvider.notifier)
        .save(current.copyWith(onboardingCompleted: true));
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(description),
      trailing: granted
          ? const Chip(label: Text('已授权'))
          : OutlinedButton(onPressed: onTap, child: const Text('去授权')),
    ),
  );
}
