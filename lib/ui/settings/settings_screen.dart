import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/providers.dart';
import '../../domain/models/configuration.dart';
import '../../infrastructure/network/openai_compatible_client.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('无法读取设置：$error')),
        data: (value) => _SettingsForm(settings: value),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final TextEditingController transcriptionUrl;
  late final TextEditingController transcriptionKey;
  late final TextEditingController transcriptionModel;
  late final TextEditingController summaryUrl;
  late final TextEditingController summaryKey;
  late final TextEditingController summaryModel;
  late AppThemeMode theme;
  late bool imageMode;

  @override
  void initState() {
    super.initState();
    final value = widget.settings;
    transcriptionUrl = TextEditingController(text: value.transcription.baseUrl);
    transcriptionKey = TextEditingController(text: value.transcription.apiKey);
    transcriptionModel = TextEditingController(text: value.transcription.model);
    summaryUrl = TextEditingController(text: value.summary.baseUrl);
    summaryKey = TextEditingController(text: value.summary.apiKey);
    summaryModel = TextEditingController(text: value.summary.model);
    theme = value.themeMode;
    imageMode = value.imageMode;
  }

  @override
  void dispose() {
    transcriptionUrl.dispose();
    transcriptionKey.dispose();
    transcriptionModel.dispose();
    summaryUrl.dispose();
    summaryKey.dispose();
    summaryModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Card(
        child: ListTile(
          leading: Icon(Icons.security),
          title: Text('本地优先与自带 API'),
          subtitle: Text('密钥只保存在系统安全区，不会写入纪要、数据库、日志或诊断包。'),
        ),
      ),
      const SizedBox(height: 16),
      _ServiceEditor(
        title: '转写服务',
        url: transcriptionUrl,
        keyController: transcriptionKey,
        model: transcriptionModel,
        onTest: () => _test(
          ServiceConfig(
            baseUrl: transcriptionUrl.text,
            apiKey: transcriptionKey.text,
            model: transcriptionModel.text,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _ServiceEditor(
        title: '总结服务',
        url: summaryUrl,
        keyController: summaryKey,
        model: summaryModel,
        onTest: () => _test(
          ServiceConfig(
            baseUrl: summaryUrl.text,
            apiKey: summaryKey.text,
            model: summaryModel.text,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('纪要与外观', style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('生成图文纪要'),
                subtitle: const Text('额外生成时间线、思维导图和关键数字。'),
                value: imageMode,
                onChanged: (value) => setState(() => imageMode = value),
              ),
              DropdownButtonFormField<AppThemeMode>(
                initialValue: theme,
                decoration: const InputDecoration(labelText: '外观主题'),
                items: const [
                  DropdownMenuItem(
                    value: AppThemeMode.system,
                    child: Text('跟随系统'),
                  ),
                  DropdownMenuItem(
                    value: AppThemeMode.light,
                    child: Text('浅色'),
                  ),
                  DropdownMenuItem(value: AppThemeMode.dark, child: Text('深色')),
                ],
                onChanged: (value) => setState(() => theme = value ?? theme),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.save),
        label: const Text('保存设置'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _exportDiagnostics,
        icon: const Icon(Icons.bug_report_outlined),
        label: const Text('导出隐私安全诊断包'),
      ),
    ],
  );

  Future<void> _save() async {
    final value = widget.settings.copyWith(
      transcription: ServiceConfig(
        baseUrl: transcriptionUrl.text.trim(),
        apiKey: transcriptionKey.text.trim(),
        model: transcriptionModel.text.trim(),
      ),
      summary: ServiceConfig(
        baseUrl: summaryUrl.text.trim(),
        apiKey: summaryKey.text.trim(),
        model: summaryModel.text.trim(),
      ),
      themeMode: theme,
      imageMode: imageMode,
    );
    await ref.read(settingsProvider.notifier).save(value);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  Future<void> _test(ServiceConfig config) async {
    try {
      await OpenAICompatibleClient().test(config);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('连接成功')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _exportDiagnostics() async {
    final source = await ref
        .read(appServicesProvider)
        .diagnostics
        .exportBundle();
    final destination = await getSaveLocation(
      suggestedName: source.uri.pathSegments.last,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'ZIP', extensions: ['zip']),
      ],
    );
    if (destination == null) return;
    await File(source.path).copy(destination.path);
  }
}

class _ServiceEditor extends StatelessWidget {
  const _ServiceEditor({
    required this.title,
    required this.url,
    required this.keyController,
    required this.model,
    required this.onTest,
  });
  final String title;
  final TextEditingController url;
  final TextEditingController keyController;
  final TextEditingController model;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          TextField(
            controller: url,
            decoration: const InputDecoration(labelText: '接口地址'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: keyController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'API 密钥'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: model,
            decoration: const InputDecoration(labelText: '模型名'),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(onPressed: onTest, child: const Text('测试连接')),
          ),
        ],
      ),
    ),
  );
}
