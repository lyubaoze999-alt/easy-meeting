/// Semantic asset states projected by the meeting library (R-04).
///
/// These are domain states, not presentation: the library and detail screens
/// derive them from the real file on disk and the post-processing Job queue,
/// so the list and the detail always agree (no optimistic defaults).
library;

/// Whether a recording file is usable.
enum RecordingDisplayStatus { playable, missing, damaged }

/// Whether a meeting summary note has been produced.
enum MeetingNoteDisplayStatus { notGenerated, processing, ready, failed }
