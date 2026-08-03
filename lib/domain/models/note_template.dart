class NoteTemplate {
  const NoteTemplate({
    required this.id,
    required this.name,
    required this.instruction,
    this.isBuiltin = false,
  });

  final String id;
  final String name;
  final String instruction;
  final bool isBuiltin;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'instruction': instruction,
    'isBuiltin': isBuiltin,
  };

  factory NoteTemplate.fromJson(Map<String, Object?> json) => NoteTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    instruction: json['instruction'] as String,
    isBuiltin: json['isBuiltin'] as bool? ?? false,
  );

  static const builtins = [
    NoteTemplate(
      id: 'builtin.default',
      name: '默认',
      isBuiltin: true,
      instruction: '按会议摘要、关键决策、待办事项、讨论要点四个分区输出。',
    ),
    NoteTemplate(
      id: 'builtin.standup',
      name: '站会',
      isBuiltin: true,
      instruction: '按昨日进展、今日计划、阻塞问题、待办事项输出。',
    ),
    NoteTemplate(
      id: 'builtin.review',
      name: '评审',
      isBuiltin: true,
      instruction: '按评审目标、关键结论、风险与争议、后续动作输出。',
    ),
    NoteTemplate(
      id: 'builtin.interview',
      name: '面试',
      isBuiltin: true,
      instruction: '按候选人概览、能力证据、风险点、综合评价输出。',
    ),
  ];
}
