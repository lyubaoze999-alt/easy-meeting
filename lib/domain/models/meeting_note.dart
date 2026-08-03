import 'dart:convert';

class NoteSection {
  const NoteSection({
    required this.heading,
    required this.content,
    this.isHighlighted = false,
  });

  final String heading;
  final String content;
  final bool isHighlighted;

  Map<String, Object?> toJson() => {
    'heading': heading,
    'content': content,
    'isHighlighted': isHighlighted,
  };

  factory NoteSection.fromJson(Map<String, Object?> json) => NoteSection(
    heading: json['heading'] as String? ?? '',
    content: json['content'] as String? ?? '',
    isHighlighted: json['isHighlighted'] as bool? ?? false,
  );
}

class TodoItem {
  const TodoItem({
    required this.text,
    this.done = false,
    this.owner,
    this.dueDate,
  });

  final String text;
  final bool done;
  final String? owner;
  final String? dueDate;

  Map<String, Object?> toJson() => {
    'text': text,
    'done': done,
    'owner': owner,
    'dueDate': dueDate,
  };

  factory TodoItem.fromJson(Map<String, Object?> json) => TodoItem(
    text: json['text'] as String? ?? '',
    done: json['done'] as bool? ?? false,
    owner: json['owner'] as String?,
    dueDate: json['dueDate'] as String?,
  );
}

class TimelineNode {
  const TimelineNode({required this.time, required this.title, this.detail});
  final String time;
  final String title;
  final String? detail;

  Map<String, Object?> toJson() => {
    'time': time,
    'title': title,
    'detail': detail,
  };
  factory TimelineNode.fromJson(Map<String, Object?> json) => TimelineNode(
    time: json['time'] as String? ?? '',
    title: json['title'] as String? ?? '',
    detail: json['detail'] as String?,
  );
}

class MindmapNode {
  const MindmapNode({required this.title, this.children = const []});
  final String title;
  final List<MindmapNode> children;

  Map<String, Object?> toJson() => {
    'title': title,
    'children': children.map((node) => node.toJson()).toList(),
  };
  factory MindmapNode.fromJson(Map<String, Object?> json) => MindmapNode(
    title: json['title'] as String? ?? '',
    children: (json['children'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(MindmapNode.fromJson)
        .toList(),
  );
}

class KeyNumber {
  const KeyNumber({required this.label, required this.value, this.note});
  final String label;
  final String value;
  final String? note;

  Map<String, Object?> toJson() => {
    'label': label,
    'value': value,
    'note': note,
  };
  factory KeyNumber.fromJson(Map<String, Object?> json) => KeyNumber(
    label: json['label'] as String? ?? '',
    value: json['value'] as String? ?? '',
    note: json['note'] as String?,
  );
}

class NoteVisuals {
  const NoteVisuals({this.timeline, this.mindmap, this.keyNumbers});
  final List<TimelineNode>? timeline;
  final MindmapNode? mindmap;
  final List<KeyNumber>? keyNumbers;

  bool get isEmpty =>
      (timeline == null || timeline!.isEmpty) &&
      mindmap == null &&
      (keyNumbers == null || keyNumbers!.isEmpty);

  Map<String, Object?> toJson() => {
    'timeline': timeline?.map((node) => node.toJson()).toList(),
    'mindmap': mindmap?.toJson(),
    'keyNumbers': keyNumbers?.map((number) => number.toJson()).toList(),
  };

  factory NoteVisuals.fromJson(Map<String, Object?> json) => NoteVisuals(
    timeline: (json['timeline'] as List<Object?>?)
        ?.whereType<Map<String, Object?>>()
        .map(TimelineNode.fromJson)
        .toList(),
    mindmap: json['mindmap'] is Map<String, Object?>
        ? MindmapNode.fromJson(json['mindmap']! as Map<String, Object?>)
        : null,
    keyNumbers: (json['keyNumbers'] as List<Object?>?)
        ?.whereType<Map<String, Object?>>()
        .map(KeyNumber.fromJson)
        .toList(),
  );
}

class MeetingNote {
  const MeetingNote({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.duration,
    required this.audioPath,
    required this.transcriptPath,
    required this.templateId,
    required this.sections,
    required this.todos,
    required this.highlights,
    this.visuals,
    this.deletedAt,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final Duration duration;
  final String audioPath;
  final String transcriptPath;
  final String templateId;
  final List<NoteSection> sections;
  final List<TodoItem> todos;
  final List<Duration> highlights;
  final NoteVisuals? visuals;
  final DateTime? deletedAt;

  MeetingNote copyWith({
    String? audioPath,
    String? transcriptPath,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => MeetingNote(
    id: id,
    title: title,
    startedAt: startedAt,
    duration: duration,
    audioPath: audioPath ?? this.audioPath,
    transcriptPath: transcriptPath ?? this.transcriptPath,
    templateId: templateId,
    sections: sections,
    todos: todos,
    highlights: highlights,
    visuals: visuals,
    deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'audioPath': audioPath,
    'transcriptPath': transcriptPath,
    'templateId': templateId,
    'sections': sections.map((section) => section.toJson()).toList(),
    'todos': todos.map((todo) => todo.toJson()).toList(),
    'highlightsMs': highlights
        .map((duration) => duration.inMilliseconds)
        .toList(),
    'visuals': visuals?.toJson(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };

  String encode() => jsonEncode(toJson());

  factory MeetingNote.fromJson(Map<String, Object?> json) => MeetingNote(
    id: json['id'] as String,
    title: json['title'] as String? ?? '未命名会议',
    startedAt: DateTime.parse(json['startedAt'] as String).toLocal(),
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    audioPath: json['audioPath'] as String? ?? '',
    transcriptPath: json['transcriptPath'] as String? ?? '',
    templateId: json['templateId'] as String? ?? 'builtin.default',
    sections: (json['sections'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(NoteSection.fromJson)
        .toList(),
    todos: (json['todos'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(TodoItem.fromJson)
        .toList(),
    highlights: (json['highlightsMs'] as List<Object?>? ?? const [])
        .whereType<int>()
        .map((milliseconds) => Duration(milliseconds: milliseconds))
        .toList(),
    visuals: json['visuals'] is Map<String, Object?>
        ? NoteVisuals.fromJson(json['visuals']! as Map<String, Object?>)
        : null,
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.parse(json['deletedAt'] as String).toLocal(),
  );

  factory MeetingNote.decode(String source) =>
      MeetingNote.fromJson(jsonDecode(source) as Map<String, Object?>);
}
