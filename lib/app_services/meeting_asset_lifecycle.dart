import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/models/meeting_note.dart';
import '../domain/models/meeting_record.dart';
import '../infrastructure/repositories/meeting_repository.dart';
import '../infrastructure/repositories/note_repository.dart';

class TrashedMeetingBundle {
  const TrashedMeetingBundle({required this.meeting, this.note});

  final MeetingRecord meeting;
  final MeetingNote? note;
}

/// Coordinates meeting-level trash operations across database rows and the
/// meeting-owned asset directory.
final class MeetingAssetLifecycle {
  const MeetingAssetLifecycle({
    required this.meetings,
    required this.notes,
    required this.meetingsDirectory,
  });

  final MeetingRepository meetings;
  final NoteRepository notes;
  final Directory meetingsDirectory;

  Future<List<TrashedMeetingBundle>> listTrash() async {
    final trashedMeetings = await meetings.listTrash();
    final trashedNotes = await notes.listTrash();
    final notesByMeeting = <String, MeetingNote>{
      for (final note in trashedNotes)
        if (note.meetingId != null) note.meetingId!: note,
    };
    return trashedMeetings
        .map(
          (meeting) => TrashedMeetingBundle(
            meeting: meeting,
            note: notesByMeeting[meeting.id],
          ),
        )
        .toList(growable: false);
  }

  Future<void> restore(String meetingId) => meetings.restore(meetingId);

  Future<void> permanentlyDelete(String meetingId) async {
    _validateMeetingId(meetingId);
    final trashed = await meetings.listTrash();
    if (!trashed.any((meeting) => meeting.id == meetingId)) {
      throw StateError('只有回收站中的会议可以永久删除。');
    }
    // A provider call may have completed just before the meeting entered the
    // trash. Delete every indexed note for this meeting, regardless of its
    // individual deletedAt value, before removing the database rows.
    final allNotes = <MeetingNote>[
      ...await notes.list(),
      ...await notes.listTrash(),
    ];
    for (final note in allNotes.where((note) => note.meetingId == meetingId)) {
      await notes.permanentlyDelete(note.id);
    }
    await meetings.permanentlyDelete(meetingId);
    final directory = Directory(p.join(meetingsDirectory.path, meetingId));
    if (p.basename(directory.path) != meetingId) {
      throw StateError('会议资产目录校验失败。');
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<int> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(days: 30));
    final expired = (await meetings.listTrash())
        .where(
          (meeting) =>
              meeting.deletedAt != null && meeting.deletedAt!.isBefore(cutoff),
        )
        .toList(growable: false);
    for (final meeting in expired) {
      await permanentlyDelete(meeting.id);
    }
    return expired.length;
  }

  static void _validateMeetingId(String meetingId) {
    if (meetingId.isEmpty ||
        meetingId == '.' ||
        meetingId == '..' ||
        p.basename(meetingId) != meetingId ||
        meetingId.contains('/') ||
        meetingId.contains(r'\')) {
      throw ArgumentError.value(meetingId, 'meetingId', 'invalid id');
    }
  }
}
