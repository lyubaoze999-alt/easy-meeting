# Loop 5 internal review

Loop: 5 — Real-time recording workspace

Reviewer: Ark-routed Claude Code session (execution + internal independent review).

## Baseline

- Base commit: `36b9407` (Loop 4 platform gate approval on exact SHA `36b9407`).
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
- Calm Focus visual at 1080×720 (extended / Row) and 680×720 (compact / Column),
  light/dark, no overflow (each visual case asserts `takeException() == null`).

## Review findings

Independent subagent review of the R-09 gate, safe-end dialog, layout hardening,
and test quality:

- P0: none.
- P1: none.
- P2: none.
- P3 (found, fixed): the local-only branch was only exercised at wide width; the
  compact <760px local-only layout was untested and the contract text said 880×600
  (which is actually wide). Added 680×720 local-only visual cases
  (`local-only-compact-*`) and corrected the contract to 1080×720 / 680×720.
  Also added a `mounted` guard after the safe-end dialog.
- P3 (accepted): a rapid double-tap on "结束录音" could stack two dialogs before
  the route lands (the button is not disabled while the dialog is pending). Low
  real-world risk; noted for the Loop 8 interaction hardening.
- P3 (accepted): `_stopMeeting` uses the `State`'s `context` for the dialog; the
  continuation is still safe because `session.stopRecording()` is context-free.
  Accepted.
- P3 (accepted): the `_LocalOnlyPanel` copy overlaps conceptually with the
  prep-screen realtime subtitle, but they serve different moments (before vs
  during recording) and both describe truth. Accepted.

Verdict: `APPROVE`.

## Visual smoke evidence

`test/loop5_visual_test.dart` deterministically renders the real `MeetingWorkspace`
(realtime and local-only) at 1080×720 (extended) and 680×720 (compact) across
light/dark; all 8 cases pass as smoke assertions. Pixel goldens were produced
locally with `EM_GEN_GOLDENS=1` and are repo-external evidence under
`test/goldens/recording-workspace/` (SHA-256):

| File | SHA-256 |
|---|---|
| `realtime-extended-light.png` | `b8952130790efa578c09925f70ec96737a4abf392e7b75e98157b46b79c3f6c7` |
| `realtime-extended-dark.png` | `1be106b4bbb7b3c0ddb5759d114ac66713e38972042fb329363a881f458dfdad` |
| `realtime-compact-light.png` | `ceeb7219af29956e34ed855b1ebd9ffce2bcf24a61ea0f425ddb1f4076c88980` |
| `realtime-compact-dark.png` | `5635a7c80bc0b941b463df1d63248e7dbedd5c6c4ee7763dca0f54bc27b89baa` |
| `local-only-extended-light.png` | `b8e717d80eca0d53a9783794a4f29393ab348eac2b28d892e7265c41de9c75ff` |
| `local-only-extended-dark.png` | `ed73bd700381432a3dd1e20472334a59d8f79bc0eb67d6e3fecad60305b8f9de` |
| `local-only-compact-light.png` | `3e65da2e2d26fc340a9f753dcc6523b2f921b5e5322dac06dc6f811275433379` |
| `local-only-compact-dark.png` | `174833c05aeaf5dd856878ce4f4f659b320f9695f4a8dcfd1386f76b8f875b38` |

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