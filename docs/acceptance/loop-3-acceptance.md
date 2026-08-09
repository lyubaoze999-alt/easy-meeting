# Loop 3 acceptance and internal review

Loop: 3 — Permission onboarding and platform capability

## Baseline

- Base SHA: `cbf722db5f33ac3d35891477d1d73a6a8ad93b35` (Loop 2 exact commit).
- Branch: `agent/macos-deliverable`.

## Scope

Fixed the Windows permission P1 (R-06): `permissionStatus` no longer hardcodes
granted. It now reads the real Windows privacy consent
(`HKCU\...\ConsentStore\microphone\Value == "Allow"`); loopback system audio is
gated by the same consent on modern Windows. The macOS permission path was already
real and unchanged. The onboarding screen applies Calm Focus `ThemeTokens.success`
to the granted chip and accepts an injected `AudioCapture` for widget tests.

### Changed / added files

| Path | Change |
|---|---|
| `packages/audio_capture/windows/audio_capture_plugin.cpp` | `CheckMicrophonePermission()` reads registry consent; `permissionStatus` reports it instead of unconditional granted. |
| `packages/audio_capture/windows/test/audio_capture_plugin_test.cpp` | Asserts structural validity and consent agreement instead of hardcoded true. |
| `lib/ui/onboarding/permission_onboarding_screen.dart` | Calm Focus chip + overridable `capture`. |
| `test/permission_onboarding_test.dart` | 4 widget tests (granted/denied/mic-only/refresh). |
| `test/helpers/test_app_services.dart` (new) | Shared in-memory `AppServices` harness + `StubAudioCapturePlatform` for recording-owned widget tests. |
| `test/loop3_visual_test.dart` (new) | Light/dark × granted/denied visual evidence at 1080×720; gated golden capture behind `EM_GEN_GOLDENS=1`, else deterministic smoke assertion. |
| `test/goldens/onboarding/*.png` | 4 generated pixel goldens (repo-external evidence, SHA-256 recorded below). |
| `docs/architecture/loop-3-contract.md`, `loop-3-review.md` | This slice's contract + review. |

## Commands and results

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test` | `Formatted 95 files (0 changed)` — PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — full suite PASS |
| `EM_GEN_GOLDENS=1 flutter test test/loop3_visual_test.dart --update-goldens` | 4/4 PASS; goldens written |
| `flutter test test/loop3_visual_test.dart test/permission_onboarding_test.dart` | 8/8 PASS (smoke path, no env) |
| `packages/audio_capture` `flutter analyze` | `No issues found!` — PASS |
| `packages/audio_capture` `flutter test` | `All tests passed!` — 4 tests PASS |

## Visual evidence (repo-external goldens)

The 4 generated goldens are local evidence and are not byte-compared on CI
(Ubuntu CJK font differs from this Windows host; same decision as Loop 2). Per
contract §11 ("PNG 不进入 git diff") they are kept untracked (not in the diff)
and verified by recorded SHA-256:

| Golden | SHA-256 |
|---|---|
| `test/goldens/onboarding/light-granted.png` | `6838512c46c974f059326ff0ae080c19dd255f114c82a207b5040d3a37c96917` |
| `test/goldens/onboarding/dark-granted.png` | `0897d6c861bb55f9be44621ce8aff2fc16d15ea70a1b4ed6229e4dbd608e71d8` |
| `test/goldens/onboarding/light-denied.png` | `d91cd78678096cf9674f74d462710506d4789e47821a54dadcd0ba6555679b3a` |
| `test/goldens/onboarding/dark-denied.png` | `0e77520954e5da7f268ed312aeca2a65139231c2c582028846c002dfb6c222d3` |

The `loop3_visual_test.dart` timeout was root-caused: `TestAppServices.create()`
performs real file I/O (`Directory.systemTemp.createTemp`) which does not complete
inside a `testWidgets` FakeAsync zone. Services are now built in `setUp` (real
async zone), matching the passing Loop 2 and permission-onboarding tests.

## Internal review

- P0/P1/P2: none. P3 (registry global-consent granularity) documented; strict
  improvement over the hardcode, real-device check is the final gate.
- Verdict: `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED.
- `PLATFORM_GATE`: APPROVED — exact-commit CI on `2a05d04`: Shared quality
  `31330199754` ✅, Platform builds `31330199748` both macOS ✅ and Windows ✅
  (Release + MSIX). Real-device Windows privacy verification recorded
  separately (loop 3 P3).
- `OVERALL_LOOP3`: APPROVED.