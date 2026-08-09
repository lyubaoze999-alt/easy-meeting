# Loop 4 internal review

Loop: 4 — Recording prep, recovery, recent meetings

Reviewer: Ark-routed Claude Code session (execution + internal independent review).

## Baseline

- Base commit: `fc8daeb` (Loop 3 platform gate approval on exact SHA `2a05d04`).
- Branch: `agent/macos-deliverable`.
- Loop 3 gate: `OVERALL_LOOP3 = APPROVED`.

## Scope and files

- `lib/app_services/providers.dart` — new `selectedMeetingIdProvider` (one-shot
  deep-link request for a recent-meeting tap).
- `lib/ui/home_shell.dart` — listens to the deep-link request, switches to the
  library destination, then clears the request post-frame so re-navigation works.
- `lib/ui/library/meeting_library_screen.dart` — new `initialMeetingId` param;
  `initState`/`didUpdateWidget` preselect the requested meeting when it exists,
  otherwise fall back to first item.
- `lib/ui/library/connected_meeting_library_screen.dart` — passes the watched
  deep-link id through to the preset screen.
- `lib/ui/recording/recording_screen.dart` — new "recent meetings" section
  (`meetingLibraryProvider` real data, top 5 by `startedAt` desc), each tile
  showing `meetingDisplayTitle`, date, and a real asset-status chip
  (`recentMeetingAssetStatus`: note > transcript > recording > none).
- `test/recording_prep_test.dart` — unit test for `recentMeetingAssetStatus` +
  widget tests for template/realtime/start-from-real-data, recent-meetings
  rendering, deep-link provider set, and shell switch + preselect.
- `test/loop4_visual_test.dart` — prep screen light/dark × extended/compact.
- `docs/architecture/loop-4-contract.md` — this slice.

No changes to session/recording core, persistence, processing, trash, tray, or
native audio. The double-start guard is an existing session-level invariant
re-confirmed by regression, not re-implemented here.

## Contract items satisfied

- Prep page template / realtime capability / downgrade / orphan recovery are all
  driven by real providers (unchanged, re-confirmed).
- New recent-meetings section is driven by real `meetingLibraryProvider` data;
  each tile shows the real asset-state chip.
- Recent-meeting tap deep-links into the library and preselects that meeting;
  tapping the same meeting again still navigates (request is cleared post-frame).
- Empty library hides the section entirely.
- Double-click start only creates one meeting (existing session-level test
  regression passes).
- Consistent Calm Focus visual; no overflow at 1080×720 or 880×600, light/dark.

## Review findings

- P0: none.
- P1: none.
- P2: none.
- P3: the recent-meetings list is derived from `meetingLibraryProvider`, which
  also feeds the library gutter; a large library pays the projection cost twice on
  the prep screen. Bounded by `kRecentMeetingsLimit = 5` and acceptable for this
  local-first app; noted for the Loop 6 asset-state projection work.

Verdict: `APPROVE`.

## Visual smoke evidence

`test/loop4_visual_test.dart` deterministically renders the real
`RecordingScreen` prep state (with two seeded real meetings) at 1080×720 and
880×600 across light/dark; all 4 cases pass as smoke assertions (no render
exception, "最近会议" and a seeded meeting title present). Pixel goldens were
produced locally with `EM_GEN_GOLDENS=1` and are repo-external evidence under
`test/goldens/recording-prep/` (SHA-256):

| File | SHA-256 |
|---|---|
| `compact-dark.png` | `8e04096f77fd1d0f4d03667bd4cd47f50b6f50eea0a33e9168b312bb60a53739` |
| `compact-light.png` | `3c75f90bf6f475dfca3462769268448d2695e8e614194a3628e6f49492e89ba9` |
| `extended-dark.png` | `4b2f4dd9b5ab3c6f272bc3005c0512a7f41c586e15c119a111514dae35f83e3e` |
| `extended-light.png` | `8491aeef98684edad178e935c753d9b93f80a1e6e2f064a7c00f1e45b9e2ab89` |

The visual test builds services in `setUp` (real async zone) and uses
fixed-duration pumps (not `pumpAndSettle`) because the full `TestAppServices`
RecordingCoordinator drives a continuous animation that would never settle —
matching the Loop 2/3 visual-test pattern.

## Local quality commands (exact)

| Command | Result |
|---|---|
| `dart format` on the 7 touched files | 3 formatted, PASS |
| `flutter analyze --no-pub` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 154 tests PASS |

## Requested decision

`READY_FOR_QA` (platform smoke via exact-commit CI; Windows/macOS Release +
Shared quality on the Loop 4 exact SHA).