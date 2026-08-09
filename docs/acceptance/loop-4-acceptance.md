# Loop 4 acceptance and internal review

Loop: 4 — Recording prep, recovery, recent meetings

## Baseline

- Base SHA: `fc8daeb` (Loop 3 platform gate approval on exact SHA `2a05d04`).
- Branch: `agent/macos-deliverable`.

## Scope

Added a "recent meetings" section to the recording-prep page, driven entirely by
real `meetingLibraryProvider` data. Each recent meeting shows its real asset
state (note > transcript > recording > none as "纪要就绪 / 转写就绪 / 录音已保存 /
新会议") and tapping it deep-links the shell to the library destination and
preselects that meeting (`selectedMeetingIdProvider` → `HomeShell` listener →
`MeetingLibraryScreen.initialMeetingId`), with the one-shot request cleared
post-frame so re-navigation works. The double-start guard is an existing
session-level invariant re-confirmed by regression, not re-implemented.

### Changed / added files

| Path | Change |
|---|---|
| `lib/app_services/providers.dart` | New `selectedMeetingIdProvider` one-shot deep-link request. |
| `lib/ui/home_shell.dart` | Listens to the request, switches to library tab, clears it post-frame. |
| `lib/ui/library/meeting_library_screen.dart` | New `initialMeetingId` preselect param. |
| `lib/ui/library/connected_meeting_library_screen.dart` | Passes the watched deep-link id through. |
| `lib/ui/recording/recording_screen.dart` | "最近会议" section + `recentMeetingAssetStatus` + `_RecentMeetingTile`. |
| `test/recording_prep_test.dart` (new) | 5 tests: status unit, real-data prep, recent-meetings render, deep-link set, shell switch + preselect. |
| `test/loop4_visual_test.dart` (new) | Prep screen light/dark × extended/compact visual evidence. |
| `test/goldens/recording-prep/*.png` | 4 generated pixel goldens (repo-external evidence, SHA-256 below). |
| `docs/architecture/loop-4-contract.md`, `loop-4-review.md` | This slice's contract + review. |

## Commands and results

| Command | Result |
|---|---|
| `dart format` on 7 touched files | 3 formatted — PASS |
| `flutter analyze --no-pub` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 154 tests PASS |
| `EM_GEN_GOLDENS=1 flutter test test/loop4_visual_test.dart --update-goldens` | 4/4 PASS; goldens written |
| `flutter test test/loop4_visual_test.dart test/recording_prep_test.dart` | 9/9 PASS (smoke path, no env) |

## Visual evidence (repo-external goldens)

The 4 generated goldens are local evidence and are not byte-compared on CI
(Ubuntu CJK font differs from this Windows host; same decision as Loop 2/3). Per
contract §11 ("PNG 不进入 git diff") they are kept untracked (not in the diff)
and verified by recorded SHA-256:

| Golden | SHA-256 |
|---|---|
| `test/goldens/recording-prep/extended-light.png` | `8491aeef98684edad178e935c753d9b93f80a1e6e2f064a7c00f1e45b9e2ab89` |
| `test/goldens/recording-prep/extended-dark.png` | `4b2f4dd9b5ab3c6f272bc3005c0512a7f41c586e15c119a111514dae35f83e3e` |
| `test/goldens/recording-prep/compact-light.png` | `3c75f90bf6f475dfca3462769268448d2695e8e614194a3628e6f49492e89ba9` |
| `test/goldens/recording-prep/compact-dark.png` | `8e04096f77fd1d0f4d03667bd4cd47f50b6f50eea0a33e9168b312bb60a53739` |

The visual test builds services in `setUp` (real async zone) and uses
fixed-duration pumps (not `pumpAndSettle`) because the full `TestAppServices`
RecordingCoordinator drives a continuous animation that would never settle.

## Internal review

- P0/P1/P2: none. P3 (recent-meetings projection cost on the prep screen) bounded
  by `kRecentMeetingsLimit = 5`; noted for the Loop 6 asset-state projection work.
- Verdict: `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED.
- `PLATFORM_GATE`: PENDING — exact-commit CI on this Loop 4 SHA (Shared quality +
  macOS + Windows Release/MSIX) to be recorded once green.
- `OVERALL_LOOP4`: PENDING PLATFORM.