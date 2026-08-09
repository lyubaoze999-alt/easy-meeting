# Loop 3 internal review

Loop: 3 — Permission onboarding and platform capability

Reviewer: Ark-routed Claude Code session (execution + internal independent review).

## Baseline

- Base commit: `cbf722db5f33ac3d35891477d1d73a6a8ad93b35` (Loop 2 exact commit).
- Branch: `agent/macos-deliverable`.
- Loop 2 gate: `OVERALL_LOOP2 = APPROVED`.

## Scope and files

- `packages/audio_capture/windows/audio_capture_plugin.cpp` — R-06 fix: replace the
  hardcoded `permissionStatus` (always granted) with the real Windows privacy
  consent read from `HKCU\...\CapabilityAccessManager\ConsentStore\microphone`.
  Loopback (system audio) is gated by the same consent on modern Windows, so both
  report the same truth.
- `packages/audio_capture/windows/test/audio_capture_plugin_test.cpp` — updated to
  assert structural validity (both consent keys present as bools, agreeing) instead
  of the old hardcoded `true/true`.
- `lib/ui/onboarding/permission_onboarding_screen.dart` — Calm Focus chip styling
  (`ThemeTokens.success`), plus an overridable `capture` for test injection.
- `test/permission_onboarding_test.dart` — new widget tests: granted chips, denied
  grant buttons, macOS mic-only limitation card, refresh re-reads state.
- `docs/architecture/loop-3-contract.md` — new, this slice.

macOS permission was already real (`AVCaptureDevice.authorizationStatus` +
`CGPreflightScreenCaptureAccess`); no macOS native change required.

## Contract items satisfied

- Windows `permissionStatus` no longer unconditionally reports granted; it reads
  the real user privacy consent (R-06).
- Permission/denied/open-settings/refresh states are driven by real status.
- macOS 13 (mic-only) vs 14.4+ (dual) and Windows profiles render correct tiles.
- 4 new onboarding tests; full suite green (141 tests).

## Review findings

- P0: none.
- P1: none.
- P2: none.
- P3: the Windows consent read reflects the global `ConsentStore\microphone` value
  rather than a per-app consent entry; on a Deny-by-app with global Allow this could
  over-report. Accepted as the best honest signal available without a per-app
  entitlement API and is a strict improvement over the hardcode; real-device
  verification is the final gate.

Verdict: `APPROVE`.

## Local quality commands (exact)

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test` | `Formatted 95 files (0 changed)` — PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 141 tests PASS |
| `packages/audio_capture` `flutter analyze` | `No issues found!` — PASS |
| `packages/audio_capture` `flutter test` | `All tests passed!` — 4 tests PASS |

## Requested decision

`READY_FOR_QA` (platform smoke via exact-commit CI; real-device Windows probe
recorded under evidence or marked `BLOCKED` if a real mic is unavailable).