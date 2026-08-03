import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_services/providers.dart';
import '../../domain/models/configuration.dart';
import '../../domain/realtime/realtime_transcription_client.dart';
import '../../infrastructure/network/openai_compatible_client.dart';
import '../../infrastructure/network/openai_realtime_transcription_client.dart';
import '../../infrastructure/settings/settings_store.dart';

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
  late final TextEditingController realtimeUrl;
  late final TextEditingController realtimeKey;
  late final TextEditingController realtimeModel;
  late final TextEditingController realtimeLanguage;
  late final TextEditingController realtimeKeywords;
  late final TextEditingController realtimeContext;
  late final TextEditingController transcriptionUrl;
  late final TextEditingController transcriptionKey;
  late final TextEditingController transcriptionModel;
  late final TextEditingController summaryUrl;
  late final TextEditingController summaryKey;
  late final TextEditingController summaryModel;
  late AppThemeMode theme;
  late bool imageMode;
  late bool realtimeEnabled;
  late bool realtimeConsent;

  @override
  void initState() {
    super.initState();
    final value = widget.settings;
    realtimeUrl = TextEditingController(
      text: value.realtimeTranscription.websocketUrl,
    );
    realtimeKey = TextEditingController();
    realtimeModel = TextEditingController(
      text: value.realtimeTranscription.model,
    );
    realtimeLanguage = TextEditingController(
      text: value.realtimeTranscription.language,
    );
    realtimeKeywords = TextEditingController(
      text: value.realtimeTranscription.keywords.join('，'),
    );
    realtimeContext = TextEditingController(
      text: value.realtimeTranscription.contextPrompt,
    );
    transcriptionUrl = TextEditingController(text: value.transcription.baseUrl);
    transcriptionKey = TextEditingController();
    transcriptionModel = TextEditingController(text: value.transcription.model);
    summaryUrl = TextEditingController(text: value.summary.baseUrl);
    summaryKey = TextEditingController();
    summaryModel = TextEditingController(text: value.summary.model);
    theme = value.themeMode;
    imageMode = value.imageMode;
    realtimeEnabled = value.realtimeTranscription.enabled;
    realtimeConsent = value.realtimeTranscription.uploadConsentGranted;
  }

  @override
  void dispose() {
    realtimeUrl.dispose();
    realtimeKey.dispose();
    realtimeModel.dispose();
    realtimeLanguage.dispose();
    realtimeKeywords.dispose();
    realtimeContext.dispose();
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
      _RealtimeServiceEditor(
        enabled: realtimeEnabled,
        consentGranted: realtimeConsent,
        hasStoredKey: widget.settings.realtimeTranscription.hasApiKey,
        url: realtimeUrl,
        keyController: realtimeKey,
        model: realtimeModel,
        language: realtimeLanguage,
        keywords: realtimeKeywords,
        contextPrompt: realtimeContext,
        onEnabledChanged: (value) => setState(() => realtimeEnabled = value),
        onConsentChanged: (value) => setState(() => realtimeConsent = value),
        onUseOfficial: () => setState(() {
          realtimeUrl.text = 'wss://api.openai.com/v1/realtime';
          if (realtimeModel.text.trim().isEmpty) {
            realtimeModel.text = 'gpt-4o-transcribe';
          }
        }),
        onTest: _testRealtime,
        onDeleteKey: () => _deleteKey(ServiceKind.realtimeTranscription),
      ),
      const SizedBox(height: 16),
      _ServiceEditor(
        title: '文件转写服务',
        url: transcriptionUrl,
        keyController: transcriptionKey,
        model: transcriptionModel,
        hasStoredKey: widget.settings.transcription.hasApiKey,
        onDeleteKey: () => _deleteKey(ServiceKind.fileTranscription),
        onTest: () => _test(
          ServiceConfig(
            baseUrl: transcriptionUrl.text,
            apiKey: transcriptionKey.text,
            model: transcriptionModel.text,
            secretReference: SettingsStore.transcriptionSecretReference,
            hasApiKey: widget.settings.transcription.hasApiKey,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _ServiceEditor(
        title: '会议纪要总结服务',
        url: summaryUrl,
        keyController: summaryKey,
        model: summaryModel,
        hasStoredKey: widget.settings.summary.hasApiKey,
        onDeleteKey: () => _deleteKey(ServiceKind.summary),
        onTest: () => _test(
          ServiceConfig(
            baseUrl: summaryUrl.text,
            apiKey: summaryKey.text,
            model: summaryModel.text,
            secretReference: SettingsStore.summarySecretReference,
            hasApiKey: widget.settings.summary.hasApiKey,
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
    if (realtimeEnabled && !realtimeConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开启实时转写前，请先确认会议音频会持续发送到云端。')),
      );
      return;
    }
    final keywords = _parseKeywords(realtimeKeywords.text);
    final newRealtimeKey = realtimeKey.text.trim();
    final newTranscriptionKey = transcriptionKey.text.trim();
    final newSummaryKey = summaryKey.text.trim();
    final value = widget.settings.copyWith(
      realtimeTranscription: RealtimeServiceConfig(
        websocketUrl: realtimeUrl.text.trim(),
        model: realtimeModel.text.trim(),
        enabled: realtimeEnabled,
        uploadConsentGranted: realtimeConsent,
        hasApiKey:
            newRealtimeKey.isNotEmpty ||
            widget.settings.realtimeTranscription.hasApiKey,
        language: realtimeLanguage.text.trim().isEmpty
            ? 'auto'
            : realtimeLanguage.text.trim(),
        keywords: keywords,
        contextPrompt: realtimeContext.text.trim(),
      ),
      transcription: ServiceConfig(
        baseUrl: transcriptionUrl.text.trim(),
        model: transcriptionModel.text.trim(),
        secretReference: SettingsStore.transcriptionSecretReference,
        hasApiKey:
            newTranscriptionKey.isNotEmpty ||
            widget.settings.transcription.hasApiKey,
      ),
      summary: ServiceConfig(
        baseUrl: summaryUrl.text.trim(),
        model: summaryModel.text.trim(),
        secretReference: SettingsStore.summarySecretReference,
        hasApiKey:
            newSummaryKey.isNotEmpty || widget.settings.summary.hasApiKey,
      ),
      themeMode: theme,
      imageMode: imageMode,
    );
    await ref
        .read(settingsProvider.notifier)
        .save(
          value,
          realtimeApiKey: newRealtimeKey.isEmpty ? null : newRealtimeKey,
          transcriptionApiKey: newTranscriptionKey.isEmpty
              ? null
              : newTranscriptionKey,
          summaryApiKey: newSummaryKey.isEmpty ? null : newSummaryKey,
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  Future<void> _testRealtime() async {
    final key = realtimeKey.text.trim();
    if (key.isEmpty && !widget.settings.realtimeTranscription.hasApiKey) {
      _showMessage('请先填写实时转写 API 密钥。');
      return;
    }
    final secretProvider = key.isEmpty
        ? ref.read(appServicesProvider).settings
        : _InlineRealtimeSecretProvider(key);
    final client = OpenAIRealtimeTranscriptionClient(
      secretProvider: secretProvider,
    );
    try {
      await client.connect(_realtimeProtocolConfig());
      await client.flushAndClose();
      _showMessage('实时转写连接成功');
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _deleteKey(ServiceKind kind) async {
    await ref.read(appServicesProvider).settings.deleteServiceSecret(kind);
    await ref.read(settingsProvider.notifier).reload();
    _showMessage('已从系统安全区删除密钥');
  }

  RealtimeTranscriptionConfig _realtimeProtocolConfig() {
    final language = realtimeLanguage.text.trim();
    return RealtimeTranscriptionConfig(
      websocketUrl: Uri.parse(realtimeUrl.text.trim()),
      model: realtimeModel.text.trim(),
      secret: const SecretReference(RealtimeServiceConfig.secretReference),
      languages: language.isEmpty || language == 'auto'
          ? const <String>[]
          : <String>[language],
      keywords: _parseKeywords(realtimeKeywords.text),
      contextPrompt: realtimeContext.text.trim(),
    );
  }

  static List<String> _parseKeywords(String value) => value
      .split(RegExp(r'[,，\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _test(ServiceConfig config) async {
    try {
      await OpenAICompatibleClient(
        apiKeyProvider: ref
            .read(appServicesProvider)
            .settings
            .readServiceSecret,
      ).test(config);
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

class _RealtimeServiceEditor extends StatelessWidget {
  const _RealtimeServiceEditor({
    required this.enabled,
    required this.consentGranted,
    required this.hasStoredKey,
    required this.url,
    required this.keyController,
    required this.model,
    required this.language,
    required this.keywords,
    required this.contextPrompt,
    required this.onEnabledChanged,
    required this.onConsentChanged,
    required this.onUseOfficial,
    required this.onTest,
    required this.onDeleteKey,
  });

  final bool enabled;
  final bool consentGranted;
  final bool hasStoredKey;
  final TextEditingController url;
  final TextEditingController keyController;
  final TextEditingController model;
  final TextEditingController language;
  final TextEditingController keywords;
  final TextEditingController contextPrompt;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onUseOfficial;
  final VoidCallback onTest;
  final VoidCallback onDeleteKey;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '云端实时转写',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Switch(value: enabled, onChanged: onEnabledChanged),
            ],
          ),
          const Text('开启后，会议中显示实时文字；本地录音不依赖网络，断线时仍会继续保存。'),
          const SizedBox(height: 14),
          TextField(
            controller: url,
            decoration: const InputDecoration(
              labelText: 'WebSocket 地址',
              hintText: 'wss://api.openai.com/v1/realtime',
            ),
          ),
          if (hasStoredKey)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDeleteKey,
                child: const Text('删除已保存密钥'),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onUseOfficial,
              child: const Text('填入 OpenAI 官方地址'),
            ),
          ),
          TextField(
            controller: keyController,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'API 密钥',
              hintText: hasStoredKey ? '已安全保存；留空则不修改' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: model,
            decoration: const InputDecoration(labelText: '实时转写模型'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: language,
            decoration: const InputDecoration(
              labelText: '语言',
              hintText: 'auto 或 zh-CN',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: keywords,
            decoration: const InputDecoration(
              labelText: '关键词',
              hintText: '项目名、人名，用逗号分隔',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contextPrompt,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '会议上下文提示（可选）'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: consentGranted,
            onChanged: (value) => onConsentChanged(value ?? false),
            title: const Text('我了解实时转写会持续上传会议音频片段'),
            subtitle: const Text('授权仅用于确认上传行为；录音权限仍由系统单独管理。'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onTest,
              icon: const Icon(Icons.cloud_done_outlined),
              label: const Text('测试实时转写'),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _InlineRealtimeSecretProvider implements RealtimeSecretProvider {
  const _InlineRealtimeSecretProvider(this.secret);

  final String secret;

  @override
  Future<String> read(SecretReference reference) async => secret;
}

class _ServiceEditor extends StatelessWidget {
  const _ServiceEditor({
    required this.title,
    required this.url,
    required this.keyController,
    required this.model,
    required this.onTest,
    required this.hasStoredKey,
    required this.onDeleteKey,
  });
  final String title;
  final TextEditingController url;
  final TextEditingController keyController;
  final TextEditingController model;
  final VoidCallback onTest;
  final bool hasStoredKey;
  final VoidCallback onDeleteKey;

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
            decoration: InputDecoration(
              labelText: 'API 密钥',
              hintText: hasStoredKey ? '已安全保存；留空则不修改' : null,
            ),
          ),
          if (hasStoredKey)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onDeleteKey,
                child: const Text('删除已保存密钥'),
              ),
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
