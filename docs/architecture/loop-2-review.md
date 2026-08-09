# Loop 2 internal review

Loop: 2 — Desktop shell, navigation, brand, responsive shell (Calm Focus)

Reviewer: independent Claude Code subagent pass (Ark-routed session owns execution
+ internal review). Recorded by the implementation owner as the sole review owner
for this delivery.

## Baseline

- Base commit: `7f4cb222dc6d41029d98f491eba65709cb0f1d97` (Loop 1 theme baseline)
  merged on top of `44e44d9`.
- Branch: `agent/macos-deliverable`
- Loop 1 gate: `OVERALL_LOOP1 = APPROVED` (see `loop-1-acceptance.md`).

## Scope decision (chief note)

The Loop 2 §4.2 test whitelist was extended (2026-08-10) to authorize two
in-repo visual *smoke* tests (`test/loop2_visual_test.dart`,
`test/screenshot/loop2_shell_golden_test.dart`) so the §9.2 "no overflow at
880×600 / 1080×720" requirement becomes a deterministic regression gate. They
render the real `HomeShell` at the contract sizes/brightness and assert no
overflow exception and correct rail width. Pixel-golden capture is gated behind
the local-only `EM_GEN_GOLDENS=1` env var; the generated PNGs stay repo-external
(not committed), with SHA-256 recorded below. Product-file whitelist (§4.1) is
unchanged.

## Changed files

```
docs/architecture/loop-2-contract.md          | updated §4.2 (authorize visual smoke tests)
lib/ui/home_shell.dart                        | desktop shell wiring (Shortcuts/Actions/Focus, IndexedStack preserved)
lib/ui/shell/desktop_navigation.dart          | new — Calm Focus rail, breakpoint consts, states, semantics
lib/ui/shell/shell_focus.dart                 | new — focus group + constant-width focus ring
lib/ui/shell/shell_shortcuts.dart             | new — destination enum, shortcut map, platform labels
test/home_shell_test.dart                     | new — breakpoints, selection, shortcuts, IndexedStack, mobile
test/desktop_navigation_test.dart             | new — rail render, states, keyboard, semantics
test/shell_shortcuts_test.dart                 | new — shortcut map, labels, destination enum
test/theme_tokens_test.dart                    | appended nav/focus/breakpoint regressions
test/loop2_visual_test.dart                   | new — visual smoke gate (gated golden capture)
test/screenshot/loop2_shell_golden_test.dart   | new — visual smoke gate (gated golden capture)
```

The four generated plugin registrants
(`macos/Flutter/GeneratedPluginRegistrant.swift`,
`windows/flutter/generated_plugin_registrant.{cc,h}`,
`windows/flutter/generated_plugins.cmake`) show EOL/stat-only working-tree changes
and are intentionally left uncommitted per the delivery contract.

## Contract items satisfied

- Breakpoint as single constant `kShellExtendedBreakpoint = 1080`; 1080 Extended
  (rail 224), 1079/880 Compact (rail 72). No 1080 hardcoded in the widget tree.
- Four fixed destinations in order 记录/会议库/回收站/设置 (enum indices 0–3).
- `IndexedStack` preserved; re-selecting the current destination is a no-op that
  neither rebuilds nor reloads; first switch into the library still loads.
- Keyboard: macOS ⌘1–4, Windows Ctrl+1–4. Both Meta and Ctrl bound for
  automation; tooltips show only the platform convention. Plain digits reach text
  fields. ⌘Q/⌘W/Alt+F4/Ctrl+W untouched.
- Focus: widget-order Tab traversal; ↑/↓ move between destinations; Enter/Space
  activate; shortcut/click move focus onto the visible rail so it never strands on
  a hidden IndexedStack page. Focus ring uses `ThemeTokens.focus` at a constant
  width (no layout shift).
- Colors drawn only from `ThemeTokens`/`ColorScheme`; no new `Color(0x…)` or
  `Colors.*` business colors in the shell.
- States Default/Hover/Pressed/Selected/Keyboard Focus; selection conveyed by
  indicator + filled icon + weight (never color alone); no geometry change on
  state change.
- Mobile profile keeps the bottom `NavigationBar` with four entries; no regression.
- Loop 1 button min-width 0 / min-height 40 unchanged.

## Independent review findings

- P0: none.
- P1: none — the sole §4.2 whitelist breach raised by the reviewer was resolved by
  the documented §4.2 authorization above (repo-external PNGs, deterministic smoke
  gate, product whitelist unchanged).
- P2: none in the committed Loop 2 diff. (Generated registrants are pre-existing
  platform-deliverable working-tree changes and are excluded from this commit.)
- P3: `_HomeShellState.destinations` independently re-lists mobile labels/icons
  rather than deriving from `ShellDestination`. Acceptable: mobile is out of Loop 2
  scope and its visual is contract-frozen; left for a future cleanup, not a defect.

Verdict: `APPROVE`.

## Local quality commands (exact)

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test` | `Formatted 94 files (0 changed)` — PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 137 tests PASS |
| `packages/audio_capture` `flutter analyze` | `No issues found!` — PASS |
| `packages/audio_capture` `flutter test` | `All tests passed!` — 4 tests PASS |

## Deterministic visual evidence (repo-external, PNG not committed)

Generated with the real `HomeShell` + `easyMeetingTheme` at Flutter 3.44.8 /
Dart 3.12.2, pixel ratio 1.0, text scale 1.0, via
`EM_GEN_GOLDENS=1 flutter test test/loop2_visual_test.dart test/screenshot/loop2_shell_golden_test.dart`.
Hashes are stable across regenerations (deterministic).

`test/goldens/` (1080×720 + 880×600, record + library, light + dark):

| File | SHA-256 | Bytes |
|---|---|---|
| `test/goldens/shell-record-light-1080x720.png` | `df076addb985fb2f8a1d4a5bdf21b3e26985d3bf80e853195ec67a109acfa804` | 12053 |
| `test/goldens/shell-record-dark-1080x720.png` | `0bf52c73e2ed3e5defa2a804b9ac8517ff4a5c5bad8a712b9fbef06f6584919f` | 11956 |
| `test/goldens/shell-record-light-880x600.png` | `c92b3879872610ea34265551d07f0413dc6713ab04612480f2905e218676e002` | 9567 |
| `test/goldens/shell-record-dark-880x600.png` | `67e35f1a49b1474a25794d350c9b3fe4ffdcb31d24e1bc5c25ed66e8958b7a43` | 9538 |
| `test/goldens/shell-library-light-1080x720.png` | `a9a082eccb0692c4c7fbfa4808878daa1cd18f58af2458ffdb0ee54fd71f147e` | 8220 |
| `test/goldens/shell-library-dark-1080x720.png` | `c642dae8e7aef0d5928849f03260765268e9db09f904ce5f222c4ca63689c5ff` | 8202 |
| `test/goldens/shell-library-light-880x600.png` | `4910baefadb1a3a70861dc34d31afb3f07008026691fa17f7021f6f7993bce7d` | 5676 |
| `test/goldens/shell-library-dark-880x600.png` | `5754235f075c49e603451134e5db712f973918c46d3bf9588dc62f157f12f81a` | 5698 |

`test/screenshot/loop2/` (compact + extended, light + dark):

| File | SHA-256 | Bytes |
|---|---|---|
| `test/screenshot/loop2/shell-light-extended-1080.0x720.0.png` | `df076addb985fb2f8a1d4a5bdf21b3e26985d3bf80e853195ec67a109acfa804` | 12053 |
| `test/screenshot/loop2/shell-dark-extended-1080.0x720.0.png` | `7f2798f5579ef6ef7c4307af80889747ea7c1ba2d6f98c1a2a53016edc1d96a7` | 11989 |
| `test/screenshot/loop2/shell-light-compact-880.0x600.0.png` | `eb3bf6c97c701f8eeb0c41abf3d59fdc746636e30294b99a3722c039812a3d9c` | 9518 |
| `test/screenshot/loop2/shell-dark-compact-880.0x600.0.png` | `0a2f96523f1f3f2c202e21450d209ec9ac6d9b4489feacf1ec7f973b8a57077f` | 9533 |

Generation command plus Flutter/Dart version, pixel ratio, text scale, and the
intended commit SHA are logged above/locally. No log shows a Flutter exception or
overflow for these captures.

## Requested decision

`READY_FOR_QA` (subject to the external platform smoke gates executed by CI for
the exact commit SHA).