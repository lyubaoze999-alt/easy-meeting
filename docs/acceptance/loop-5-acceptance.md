# Loop 5 acceptance and internal review

Loop: 5 — Real-time recording workspace

## Baseline

- Base SHA: `36b9407` (Loop 4 feature SHA; gate `OVERALL_LOOP4 = APPROVED`).
- Branch: `agent/macos-deliverable`.

## Scope

Completed the real-time recording workspace interactions and platform
differences:

1. **R-09 (P2)**: on platforms without realtime PCM (Windows), the workspace no
   longer renders a misleading empty "实时文字" panel. It renders a capability
   notice (`_LocalOnlyPanel`: "当前平台无法实时转写 / 录音仍会正常保存到本地…")
   while recording controls stay unchanged.
2. **Safe-end**: 结束录音 now requires an explicit confirmation dialog before
   stopping. Cancel keeps recording; confirm issues the real `session.stopRecording`
   (native stop → WAV validation → DB archive). No AI work is promised on screen.
3. **State machine / pause / resume / highlight / degradation**: driven by real
   session + live providers, locked by contract tests (transition-disabled
   controls, degraded copy, highlight count).
4. Fixed the compact (<760px) workspace layout so the control card lays out
   correctly under the unbounded-height Column.

### Changed / added files

| Path | Change |
|---|---|
| `lib/ui/recording/meeting_workspace.dart` | `realtimeSupported` param; `_LocalOnlyPanel` (R-09); compact-layout control fix. |
| `lib/ui/recording/recording_screen.dart` | Safe-end confirm dialog in `_stopMeeting`; passes `realtimeSupported`. |
| `test/recording_workspace_widget_test.dart` (new) | State-machine + R-09 + real-session safe-end dialog tests. |
| `test/recording_redesign_widget_test.dart` | Updated for `realtimeSupported`; added R-09 assertion. |
| `test/loop5_visual_test.dart` (new) | Workspace realtime extended/compact + local-only, light/dark. |
| `test/goldens/recording-workspace/*.png` | 6 generated pixel goldens (repo-external evidence, SHA-256 below). |
| `docs/architecture/loop-5-contract.md`, `loop-5-review.md` | This slice's contract + review. |

## Commands and results

| Command | Result |
|---|---|
| `dart format` on 5 touched files | 0 changed — PASS |
| `flutter analyze --no-pub` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 167 tests PASS |
| `EM_GEN_GOLDENS=1 flutter test test/loop5_visual_test.dart --update-goldens` | 6/6 PASS; goldens written |
| `flutter test test/loop5_visual_test.dart test/recording_workspace_widget_test.dart test/recording_redesign_widget_test.dart` | 15/15 PASS (smoke path, no env) |

## Visual evidence (repo-external goldens)

The 6 generated goldens are local evidence and are not byte-compared on CI
(Ubuntu CJK font differs from this Windows host; same decision as prior loops).
Per contract §11 ("PNG 不进入 git diff") they are kept untracked (not in the
diff) and verified by recorded SHA-256:

| Golden | SHA-256 |
|---|---|
| `test/goldens/recording-workspace/realtime-extended-light.png` | `b8952130790efa578c09925f70ec96737a4abf392e7b75e98157b46b79c3f6c7` |
| `test/goldens/recording-workspace/realtime-extended-dark.png` | `1be106b4bbb7b3c0ddb5759d114ac66713e38972042fb329363a881f458dfdad` |
| `test/goldens/recording-workspace/realtime-compact-light.png` | `ceeb7219af29956e34ed855b1ebd9ffce2bcf24a61ea0f425ddb1f4076c88980` |
| `test/goldens/recording-workspace/realtime-compact-dark.png` | `5635a7c80bc0b941b463df1d63248e7dbedd5c6c4ee7763dca0f54bc27b89baa` |
| `test/goldens/recording-workspace/local-only-light.png` | `b8e717d80eca0d53a9783794a4f29393ab348eac2b28d892e7265c41de9c75ff` |
| `test/goldens/recording-workspace/local-only-dark.png` | `ed73bd700381432a3dd1e20472334a59d8f79bc0eb67d6e3fecad60305b8f9de` |

The workspace is a pure presentational widget (no provider), so the visual test
renders it directly with the Calm Focus theme using fixed-duration pumps. The
real-session safe-end behavior is covered in `recording_workspace_widget_test.dart`
via the `TestAppServices` harness built in `setUp`.

## Internal review

- P0/P1/P2: none.
- P3: `_stopMeeting`'s dialog uses the State context; navigation away mid-dialog
  is still safe because `session.stopRecording()` is context-free. P3: the
  `_LocalOnlyPanel` copy overlaps conceptually with the prep-screen realtime
  subtitle but serves a different moment. Both accepted.
- Verdict: `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED.
- `PLATFORM_GATE`: PENDING — exact-commit CI on the Loop 5 SHA (Shared quality +
  macOS + Windows Release/MSIX) to be recorded once green.
- `OVERALL_LOOP5`: PENDING PLATFORM.