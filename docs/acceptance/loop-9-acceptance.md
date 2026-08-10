# Loop 9 acceptance and internal review

Loop: 9 — macOS native hardening

## Baseline

- Base SHA: Loop 8 branch top (`36f8285`, gate `OVERALL_LOOP8 = APPROVED`).
- Branch: `agent/macos-deliverable`.

## Scope

Hardened the macOS recording chain so the one must-fix software risk is closed
and every piece of native logic that can be verified without a physical Mac is
now covered by automated CI:

1. **R-05 write-failure visibility (P1)**: a native disk-write failure no longer
   silently truncates the recording. `MacOSAudioCapture.write` now emits a
   `writeError` event; it flows through the plugin event channel to
   `RecordingCoordinator.writeErrorMessage` (sticky until `reset()`); the
   recording workspace renders a persistent "录音写入失败，已停止保存" banner
   while keeping the stop control reachable.
2. **Native pure-logic unit tests**: the AVFoundation-free pieces of
   `MacOSAudioCapture` (error classification/messages, ring buffer order +
   overrun-drop-oldest + reset, RMS meter, silence-detector hysteresis, and the
   degradation-text decision) were extracted to `MacAudioLogic.swift` and
   covered by a standalone `swiftc` test wired into the macOS CI job, on par
   with the existing `PCMFramePumpTests`.
3. **Real-device items honestly BLOCKED**: 13.x mic-only, 14.4+ dual, sleep/
   wake, device switching, 45-minute recording, pause conservation, and the
   signed-candidate package all require physical macOS hardware + full Xcode,
   unavailable on the Windows CI host. Per the baseline rule these are marked
   `BLOCKED` (not inferred-passed) and tracked in `desktop-checklist.md`.

### Changed / added files

| Path | Change |
|---|---|
| `packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacAudioLogic.swift` | Extracted pure logic (no AVFoundation). |
| `packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacOSAudioCapture.swift` | Removed moved types; mic level via `AudioMeter.rms`; R-05 `writeError` emit. |
| `packages/audio_capture/macos/audio_capture/Tests/MacAudioLogicTests/main.swift` | `swiftc` native tests. |
| `packages/audio_capture/lib/audio_capture.dart` | `writeError` stream. |
| `lib/app_services/recording_coordinator.dart` | Sticky `writeErrorMessage`. |
| `lib/ui/recording/meeting_workspace.dart` | Persistent write-error banner. |
| `lib/ui/recording/recording_screen.dart` | Thread-through `writeErrorMessage`. |
| `test/recording_coordinator_test.dart`, `test/recording_workspace_widget_test.dart` | R-05 tests (3). |
| `.github/workflows/platform-builds.yml` | macOS job runs `MacAudioLogic` swiftc test. |
| `docs/architecture/loop-9-*.md`, `docs/acceptance/loop-9-acceptance.md`, `desktop-checklist.md` | Docs. |

## Commands and results

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test` | PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 204 tests PASS |
| `packages/audio_capture` analyze + test | `No issues found!` / `All tests passed!` (4) PASS |
| `swiftc` `MacAudioLogicTests` | CI macOS job step (Windows host can't run Swift) |

## Internal review

- P0/P1/P2 (software): none.
- P3-1 (accepted): real-device macOS items remain `BLOCKED` on physical
  hardware; their code-level testable paths are all covered.
- P3-2 (accepted): a write failure stops writing but does not auto-stop the
  session; the banner tells the user the capture is no longer saved and lets
  them end it deliberately.
- Verdict (software): `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED (software scope).
- `PLATFORM_GATE`: APPROVED on exact-commit `d71ad31` — Shared quality
  success + Platform builds success (macOS job runs the `MacAudioLogic`
  swiftc test, incl. the corrected ring-read count; Windows job runs the
  Loop 10 drift test; macOS/Windows release + MSIX + DMG built).
- `REALDEVICE_GATE (macOS)`: BLOCKED — physical Mac + full Xcode + signing
  identity required; tracked in `desktop-checklist.md`.
- `OVERALL_LOOP9`: APPROVED (software).

### Platform-gate correction

The first Loop 9 branch-top exact-commit run (`0dcebae`) failed its macOS
`Verify mac audio logic` swiftc step. Diagnosis via a temporary debug
workflow's annotations surfaced the real defect: `AudioRingBuffer.read`
returned `Void`, but the native test assigns `var read = ring.read(...)`
expecting the count read, so `read` inferred as `()` and the
`read == 3` / `read == 8` assertions would not compile. The product code was
corrected (`read` now returns the amount read, `@discardableResult`;
production callers ignore it unchanged) and a cosmetic `ArraySlice` guard was
added to the test. Re-verified green on `d71ad31` (all four platform jobs:
ios/android/windows/macos).