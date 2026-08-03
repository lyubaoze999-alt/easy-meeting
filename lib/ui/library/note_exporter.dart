import '../../domain/models/meeting_note.dart';

class NoteExporter {
  const NoteExporter._();

  static String markdown(MeetingNote note) {
    final buffer = StringBuffer('# ${note.title}\n\n');
    buffer.writeln('> 会议时间：${note.startedAt.toLocal()}');
    buffer.writeln('> 会议时长：${_duration(note.duration)}\n');
    for (final section in note.sections) {
      buffer.writeln('## ${section.heading}\n');
      buffer.writeln('${section.content}\n');
    }
    if (note.todos.isNotEmpty) {
      buffer.writeln('## 待办事项\n');
      for (final todo in note.todos) {
        final metadata = [
          if (todo.owner?.isNotEmpty == true) '负责人：${todo.owner}',
          if (todo.dueDate?.isNotEmpty == true) '截止：${todo.dueDate}',
        ].join('；');
        buffer.writeln(
          '- [${todo.done ? 'x' : ' '}] ${todo.text}'
          '${metadata.isEmpty ? '' : '（$metadata）'}',
        );
      }
    }
    return buffer.toString();
  }

  static String _duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }
}
