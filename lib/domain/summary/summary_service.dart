import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../infrastructure/network/openai_compatible_client.dart';
import '../models/configuration.dart';
import '../models/meeting_note.dart';
import '../models/note_template.dart';

class SummaryContext {
  const SummaryContext({
    required this.startedAt,
    required this.duration,
    required this.audioPath,
    required this.transcriptPath,
    this.noteId,
  });
  final DateTime startedAt;
  final Duration duration;
  final String audioPath;
  final String transcriptPath;
  final String? noteId;
}

class SummaryService {
  const SummaryService(this.client);
  final OpenAICompatibleClient client;

  Future<MeetingNote> summarize({
    required String transcript,
    required NoteTemplate template,
    required List<Duration> highlights,
    required bool imageMode,
    required ServiceConfig config,
    required SummaryContext context,
  }) async {
    final response = await client.postJson('chat/completions', {
      'model': config.model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': _systemPrompt(imageMode)},
        {
          'role': 'user',
          'content':
              '纪要模板：${template.instruction}\n'
              '重点时间点（秒）：${highlights.map((item) => item.inMilliseconds / 1000).join('、')}\n\n'
              '会议转写：\n$transcript',
        },
      ],
    }, config);
    final choices = response['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const OpenAIClientException('invalid_summary', '总结服务没有返回纪要。');
    }
    final message = (choices.first as Map)['message'];
    final content = message is Map ? message['content'] as String? : null;
    if (content == null || content.trim().isEmpty) {
      throw const OpenAIClientException('empty_summary', '总结服务没有返回纪要内容。');
    }
    final decoded = jsonDecode(_stripFence(content));
    if (decoded is! Map) {
      throw const OpenAIClientException(
        'invalid_summary_json',
        '总结服务返回的纪要格式不正确。',
      );
    }
    final json = Map<String, Object?>.from(decoded);
    return MeetingNote(
      id: context.noteId ?? const Uuid().v4(),
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : '未命名会议',
      startedAt: context.startedAt,
      duration: context.duration,
      audioPath: context.audioPath,
      transcriptPath: context.transcriptPath,
      templateId: template.id,
      sections: (json['sections'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => NoteSection.fromJson(Map<String, Object?>.from(item)))
          .toList(),
      todos: (json['todos'] as List<Object?>? ?? const [])
          .whereType<Map>()
          .map((item) => TodoItem.fromJson(Map<String, Object?>.from(item)))
          .toList(),
      highlights: highlights,
      visuals: imageMode && json['visuals'] is Map
          ? NoteVisuals.fromJson(
              Map<String, Object?>.from(json['visuals'] as Map),
            )
          : null,
    );
  }

  static String _systemPrompt(bool imageMode) =>
      '''
你是中文会议纪要助手。只输出一个 JSON 对象，不要输出 Markdown。
字段：title、sections、todos${imageMode ? '、visuals' : ''}。
sections 每项包含 heading、content、isHighlighted；todos 每项包含 text、done、owner、dueDate。
重点时间点附近的相关分区将 isHighlighted 设为 true。无法识别的负责人或日期使用 null。
${imageMode ? 'visuals 可包含 timeline、mindmap、keyNumbers，且不得删减文字内容。' : ''}
''';

  static String _stripFence(String source) {
    var text = source.trim();
    if (!text.startsWith('```')) return text;
    final newline = text.indexOf('\n');
    if (newline >= 0) text = text.substring(newline + 1);
    if (text.endsWith('```')) text = text.substring(0, text.length - 3);
    return text.trim();
  }
}
