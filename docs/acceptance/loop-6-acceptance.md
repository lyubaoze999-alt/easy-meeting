# Loop 6 acceptance and internal review

Loop: 6 — Library, search, asset state projection

## Baseline

- Base SHA: `d7ea9c5` (Loop 5 branch top; feature commits `975d9fd` + `d7ea9c5` +
  docs `1097f20`,`de7c94f`; gate `OVERALL_LOOP5 = APPROVED`).
- Branch: `agent/macos-deliverable`.

## Scope

Completed the meeting-library search and asset-state projection so the list
always reflects real data, never optimistic defaults:

1. **R-10 transcript-body search**: the library `load` now reads each formal
   transcript body file and a query matches the meeting template, the note
   (title + sections), and the transcript body text. A term that appears only
   in the transcript body surfaces its meeting.
2. **R-10 250ms debounce**: `ConnectedMeetingLibraryScreen` is now a
   `ConsumerStatefulWidget`; a keystroke waits 250ms after the last change
   before recomputing every bundle and `dispose` cancels the pending timer.
3. **R-04 asset-state projection** (domain enums moved to
   `lib/domain/models/asset_status.dart`):
   - Recording: real file on disk → `missing` / `damaged` / `playable`.
   - Summary note: noteSummary Job queue → `notGenerated` / `processing` /
     `failed` / `ready` (failed wins over a residual note; active means
     processing; scoped per `meetingId` + `jobType`).
   The list passes these through to `MeetingLibraryItem`, so the list and the
   detail screen always agree.

### Changed / added files

| Path | Change |
|---|---|
| `lib/app_services/providers.dart` | `MeetingLibraryController.load`: full-load + Dart filter, `_projectRecordingStatus`/`_projectNoteStatus`/`_matchesQuery`; `MeetingAssetBundle` adds `recordingStatus`/`noteStatus`. |
| `lib/ui/library/connected_meeting_library_screen.dart` | `ConsumerStatefulWidget` + 250ms debounce; passes projected status into `MeetingLibraryItem`. |
| `lib/ui/library/meeting_detail_screen.dart` | Re-exports `RecordingDisplayStatus`/`MeetingNoteDisplayStatus` from the domain layer (existing importers keep compiling). |
| `lib/domain/models/asset_status.dart` (new) | `RecordingDisplayStatus` / `MeetingNoteDisplayStatus` enums. |
| `lib/ui/library/meeting_library_screen.dart` | `MeetingLibraryItem` accepts projected status; `effective*Status` fallbacks. |
| `test/library_loop6_test.dart` (new) | Transcript-body search, recording 3-state, note 4-state, 250ms debounce. |
| `test/loop6_visual_test.dart` (new) | Library extended/narrow × light/dark smoke. |
| `test/goldens/library/*.png` | 4 generated pixel goldens (repo-external, untracked, SHA-256 below). |
| `.gitignore` | Ignore `test/goldens/`, `test/screenshot/`, `ci_monitor.js` (generated evidence). |
| `docs/architecture/loop-6-contract.md`, `loop-6-review.md` | This slice's contract + review. |

## Commands and results

| Command | Result |
|---|---|
| `dart format` on touched lib/test files | formatted — PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 177 tests PASS |
| `EM_GEN_GOLDENS=1 flutter test --update-goldens test/loop6_visual_test.dart` | 4/4 PASS; goldens written |
| `flutter test test/loop6_visual_test.dart` (smoke path, no env) | 4/4 PASS |

## Visual evidence (repo-external goldens)

Goldens are local evidence, not byte-compared on CI (Ubuntu CJK font differs;
same decision as prior loops). Kept untracked, verified by recorded SHA-256:

| Golden | SHA-256 |
|---|---|
| `test/goldens/library/extended-light.png` | `3b86bf02f81f2304e3dbff530cf61733e0723c1482597ef2833391f29592eda3` |
| `test/goldens/library/extended-dark.png` | `74defd386afbdebf843bd20507cb8d15551f6a917b53beec5d15de8aba9fb7fd` |
| `test/goldens/library/narrow-light.png` | `d5aee88a54c95e72e806b07417672b2c76cc39d427ecf65238e107d316087f1b` |
| `test/goldens/library/narrow-dark.png` | `878516feb5b540fc4ae2c9a9821fec7cc7ef6c1b375c75a039dcdace21bdcefc` |

The library screen is exercised end-to-end: `library_loop6_test.dart` drives the
real `MeetingLibraryController` through the `TestAppServices` harness (real file +
Drift DB + Job queue) for search and projection; `loop6_visual_test.dart` renders
the presentational screen with Calm Focus theme at 1080×720 and 880×600.

## Internal review

- P0/P1/P2: none.
- P3 (accepted): `load` now always reads every meeting's transcript body
  (full-load + Dart filter); acceptable for a local library and offset by the
  debounce. `_matchesQuery` is a plain case-insensitive `contains` (no
  tokenization); fine for fuzzy local search. Both noted for later loops.
- Verdict: `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED.
- `PLATFORM_GATE`: PENDING — exact-commit CI on Loop 6 branch top (fill after
  Shared quality + Platform builds).
- `OVERALL_LOOP6`: APPROVED (pending exact-commit platform confirmation).