# Loop 5 internal review

Loop: 5 — Real-time recording workspace

Reviewer: Ark-routed Claude Code session (execution + internal independent review).

## Baseline

- Base commit: `36b9407` (Loop 4 feature SHA; `OVERALL_LOOP4 = APPROVED` on
  `c39746b`).
- Branch: `agent/macos-deliverable`.
- Loop 4 gate: `OVERALL_LOOP4 = APPROVED`.

## Scope and files

- `lib/ui/recording/meeting_workspace.dart` — new `realtimeSupported` param;
  when false the live-transcript panel is replaced by a `_LocalOnlyPanel`
  capability notice (R-09). Also fixes the compact (<760px) layout: the control
  column now uses `Center` + `mainAxisSize.min` + `SizedBox` instead of a
  `Spacer`, so it lays out correctly under the unbounded-height workspace Column.
- `lib/ui/recording/recording_screen.dart` — `_stopMeeting` now shows a
  safe-end confirmation dialog before stopping; `MeetingWorkspace` receives
  `realtimeSupported: supportsRealtimePcm`.
- `test/recording_workspace_widget_test.dart` — presentational state-machine
  tests (paused relabel, transition-disabled controls, degradation, highlight
  count, realtime vs local-only panel) plus a real-session safe-end dialog test
  (cancel keeps recording; confirm stops).
- `test/recording_redesign_widget_test.dart` — updated existing workspace tests
  for the new `realtimeSupported` param; added an R-09 assertion.
- `test/loop5_visual_test.dart` — workspace realtime extended/compact + local-only,
  light/dark.
- `docs/architecture/loop-5-contract.md` — this slice.

No changes to session/recording core, persistence, processing, trash, tray, or
native audio. Only the workspace presentation layer and the safe-end confirm UI.

## Contract items satisfied

- R-09: `realtimeSupported: false` renders the `_LocalOnlyPanel` notice
  ("当前平台无法实时转写 / 录音仍会正常保存到本地…") and never the misleading
  empty "实时文字" panel; recording controls are unchanged.
- Safe end: 结束录音 first shows a confirmation dialog; 取消 keeps recording;
  确认 issues `session.stopRecording`. No AI work is promised on this screen.
- Pause/resume/highlight/degradation are driven by real session + live providers;
  transitioning disables all controls (locked by widget test).
- Calm Focus visual at 1080×720 and 880×600, light/dark, no overflow.

## Review findings

- P0: none.
- P1: none.
- P2: none.
- P3: `_stopMeeting` shows the dialog via the `State`'s `context`; if the shell
  navigates away while it is open the continuation is still safe because
  `session.stopRecording()` is context-free (invalidates the library provider
  unconditionally). Accepted.
- P3: the `_LocalOnlyPanel` copy overlaps conceptually with the prep-screen
  realtime-subtitle, but they serve different moments (before vs during
  recording) and both describe truth. Accepted.

Verdict: `APPROVE`.

## Visual smoke evidence

`test/loop5_visual_test.dart` deterministically renders the real
`MeetingWorkspace` (realtime and local-only) at 1080×720 and 680×720 across
light/dark; all 6 cases pass as smoke assertions. Pixel goldens were produced
locally with `EM_GEN_GOLDENS=1` and are repo-external evidence under
`test/goldens/recording-workspace/` (SHA-256):

| File | SHA-256 |
|---|---|
| `realtime-extended-light.png` | `b8952130790efa578c09925f70ec96737a4abf392e7b75e98157b46b79c3f6c7` |
| `realtime-extended-dark.png` | `1be106b4bbb7b3c0ddb5759d114ac66713e38972042fb329363a881f458dfdad` |
| `realtime-compact-light.png` | `ceeb7219af29956e34ed855b1ebd9ffce2bcf24a61ea0f425ddb1f4076c88980` |
| `realtime-compact-dark.png` | `5635a7c80bc0b941b463df1d63248e7dbedd5c6c4ee7763dca0f54bc27b89baa` |
| `local-only-light.png` | `b8e717d80eca0d53a9783794a4f29393ab348eac2b28d892e7265c41de9c75ff` |
| `local-only-dark.png` | `ed73bd700381432a3dd1e20472334a59d8f79bc0eb67d6e3fecad60305b8f9de` |

The workspace is a pure presentational widget (no provider dependency), so the
visual test renders it directly with the Calm Focus theme and fixed-duration
pumps; the real-session safe-end behavior is covered separately in
`recording_workspace_widget_test.dart` using the `TestAppServices` harness built
in `setUp`.

## Local quality commands (exact)

| Command | Result |
|---|---|
| `dart format` on the 5 touched files | 0 changed, PASS |
| `flutter analyze --no-pub` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 167 tests PASS |

## Requested decision

`READY_FOR_QA` (platform smoke via exact-commit CI; Windows/macOS Release +
Shared quality on the Loop 5 exact SHA).