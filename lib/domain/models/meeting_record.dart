import 'note_template.dart';

enum MeetingStatus { recording, recorded, archived, trashed }

typedef MeetingRecordStatus = MeetingStatus;

class MeetingDraft {
  const MeetingDraft({
    required this.id,
    required this.startedAt,
    required this.templateSnapshot,
    this.highlights = const [],
  });

  final String id;
  final DateTime startedAt;
  final NoteTemplate templateSnapshot;
  final List<Duration> highlights;

  NoteTemplate get template => templateSnapshot;
}

class MeetingRecord {
  const MeetingRecord({
    required this.id,
    required this.startedAt,
    required this.duration,
    required this.templateSnapshot,
    required this.highlights,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.endedAt,
    this.deletedAt,
  });

  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration duration;
  final NoteTemplate templateSnapshot;
  final List<Duration> highlights;
  final MeetingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  NoteTemplate get template => templateSnapshot;
}
