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
| `docs/architecture/loop-3-contract.md`, `loop-3-review.md` | This slice's contract + review. |

## Commands and results

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test` | `Formatted 95 files (0 changed)` — PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 141 tests PASS |
| `packages/audio_capture` `flutter analyze` | `No issues found!` — PASS |
| `packages/audio_capture` `flutter test` | `All tests passed!` — 4 tests PASS |

## Internal review

- P0/P1/P2: none. P3 (registry global-consent granularity) documented; strict
  improvement over the hardcode, real-device check is the final gate.
- Verdict: `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED.
- `PLATFORM_GATE`: PENDING — exact-commit Windows + macOS Release CI (monitored
  after push); real-device Windows privacy verification recorded separately.
- `OVERALL_LOOP3`: PENDING_PLATFORM_GATE until CI confirms.