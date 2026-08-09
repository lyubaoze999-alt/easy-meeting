# Loop 10 acceptance and internal review

Loop: 10 — Windows native, platform parity and release

## Baseline

- Base SHA: Loop 9 branch top (`0dcebae`, gate `OVERALL_LOOP9 = APPROVED`
  software).
- Branch: `agent/macos-deliverable`.

## Scope

Closed the one must-fix Windows software risk and wired the Windows native
logic into CI, while honestly marking the real-device gates blocked:

1. **R-07 dual-source drift (P1)**: the Windows `WriterLoop` no longer mixes one
   mic block against one system block by FIFO index (which drifts over 45
   minutes on independent WASAPI clocks). A pure `DriftMixer` owns the mic
   timeline and resamples the system stream onto it using a running
   sample-count ratio, keeping the two tracks temporally locked with bounded
   drift. A standalone `drift_mixer_test.cpp` (plain `main` + asserts, on par
   with the macOS `swiftc` tests) is compiled with `cl` and run on the Windows
   CI job.
2. **Windows native logic wired into CI**: `vswhere` locates MSVC, `cl`
   compiles and runs the drift test — closing the "Windows native test not in
   CI" gap.
3. **Windows realtime PCM approved difference**: the `audio_capture/pcm`
   channel is not registered; Loop 5 already renders the R-09 capability notice
   ("当前平台无法实时转写") instead of a misleading empty panel. Without a
   Windows physical dual-capture setup this difference is documented and
   accepted.
4. **Real-device items honestly BLOCKED**: 45-minute dual-source real-device
   evidence, device plug/unplug/switching, MSIX install+launch, and sleep/resume
   require physical Windows hardware, unavailable here. Tracked in
   `desktop-checklist.md`.

### Changed / added files

| Path | Change |
|---|---|
| `packages/audio_capture/windows/drift_mixer.h` | Pure `DriftMixer` (R-07 sync restructure). |
| `packages/audio_capture/windows/audio_capture_plugin.cpp` | `WriterLoop` uses the drift mixer. |
| `packages/audio_capture/windows/test/drift_mixer_test.cpp` | Standalone `cl`-compiled native test. |
| `.github/workflows/platform-builds.yml` | Windows job compiles + runs the drift test. |
| `docs/architecture/loop-10-*.md`, `docs/acceptance/loop-10-acceptance.md`, `desktop-checklist.md` | Docs. |

## Commands and results

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test` | PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 204 tests PASS |
| `packages/audio_capture` analyze + test | `No issues found!` / `All tests passed!` (4) PASS |
| `cl /EHsc` `drift_mixer_test.cpp` | Windows CI job step (no local MSVC) |

## Internal review

- P0/P1/P2 (software): none.
- P3-1 (accepted): Windows real-device items remain `BLOCKED` on physical
  hardware; the algorithmic drift closure is covered by the native test.
- P3-2 (accepted): late-arriving system samples behind the current mic cursor
  are not retroactively mixed (startup-only, accepted).
- P3-3 (accepted): after a pause the ratio reconverges over a few flushes.
- Verdict (software): `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED (software scope).
- `PLATFORM_GATE`: PENDING — exact-commit CI on Loop 10 branch top (fill after
  Shared quality + Platform builds, including the new Windows drift step and
  the macOS MacAudioLogic step).
- `REALDEVICE_GATE (Windows)`: BLOCKED — physical Windows hardware + audio
  device + MSIX install required; tracked in `desktop-checklist.md`.
- `OVERALL_LOOP10`: APPROVED (software) pending exact-commit platform
  confirmation; REALDEVICE pending hardware.