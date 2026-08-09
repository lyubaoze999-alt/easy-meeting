# Loop 8 acceptance and internal review

Loop: 8 — Settings, trash, illustrations, accessibility (R-12)

## Baseline

- Base SHA: `d3bd3b2` (Loop 6 platform gate approval; Loop 7 `98dd3b3` also
  present on branch top; gate `OVERALL_LOOP7 = APPROVED`).
- Branch: `agent/macos-deliverable`.

## Scope

Completed the settings and trash screens and landed the R-12 accessibility gate
so the shell respects the system "reduce motion" setting, is keyboard-navigable
with a visible focus ring, exposes correct Semantics, and keeps primary controls
above the WCAG hit-target minimum:

1. **R-12 reduce motion**: the desktop navigation selection animation and the
   live-transcript auto-scroll both switch to `Duration.zero` / `jumpTo` when
   `MediaQuery.disableAnimationsOf` is set; otherwise they animate as before.
2. **R-12 keyboard order + focus ring**: nav destinations remain `FocusNode`-
   driven with `shellFocusRingDecoration`; Arrow keys move focus and
   Enter/Space activate; the focus ring renders with `tokens.focus`.
3. **R-12 Semantics**: each destination exposes `label`, `button`,
   `inMutuallyExclusiveGroup` and `selected`; the selected destination reports
   `selected=true`.
4. **R-12 hit targets**: compact rail items raised to a 48px minimum so every
   rail item's tap target is ≥44px in both compact and extended modes.
5. **Settings / trash regression**: both screens render cleanly at 1080×720 and
   880×600 in light and dark with no overflow; pixel goldens recorded.

### Changed / added files

| Path | Change |
|---|---|
| `lib/ui/shell/desktop_navigation.dart` | `AnimatedContainer` duration gated on `disableAnimations`; compact item minHeight 40→48 (.gitignore'd goldens). |
| `lib/ui/recording/live_transcript_panel.dart` | `_scrollToLatest` jumps under reduce-motion, animates otherwise. |
| `test/accessibility_gate_test.dart` (new) | R-12 gate: reduce-motion, keyboard + focus ring, Semantics, hit targets (10 tests). |
| `test/loop8_visual_test.dart` (new) | Settings/trash extended/narrow × light/dark smoke (8 tests). |
| `test/goldens/settings/*.png`, `test/goldens/trash/*.png` | 8 generated pixel goldens (repo-external, untracked, SHA-256 below). |
| `docs/architecture/loop-8-contract.md`, `loop-8-review.md` | This slice's contract + review. |

## Commands and results

| Command | Result |
|---|---|
| `dart format --output=none --set-exit-if-changed` | PASS |
| `flutter analyze` | `No issues found!` — PASS |
| `flutter test` | `All tests passed!` — 201 tests PASS |
| `EM_GEN_GOLDENS=1 flutter test --update-goldens test/loop8_visual_test.dart` | 8/8 PASS; goldens written |
| `flutter test test/loop8_visual_test.dart` (smoke path, no env) | 8/8 PASS |

## Visual evidence (repo-external goldens)

Goldens are local evidence, not byte-compared on CI (Ubuntu CJK font differs;
same decision as prior loops). Kept untracked, verified by recorded SHA-256:

| Golden | SHA-256 |
|---|---|
| `test/goldens/settings/extended-light.png` | `f8c520e04394e5d4c2cbaf41c5053dd371e7e5f0a16e14be0233c3a46b97ab65` |
| `test/goldens/settings/extended-dark.png` | `ed37f214b5c928808e653a3d3ac77cb18202d1cdfd647f9c44ba72d44b08d99e` |
| `test/goldens/settings/narrow-light.png` | `44f833f367456f92869cab91999eee87da2a368461ec3074df578fa0b65364fa` |
| `test/goldens/settings/narrow-dark.png` | `d27719bfe9792b337b700a39da1723f71595a6ea30fa263d19eb63130f77c8af` |
| `test/goldens/trash/extended-light.png` | `873551a781b2e0a54bb0de795b91005e9911b251e63bd98c4308964de7aa71cf` |
| `test/goldens/trash/extended-dark.png` | `b29c32a5e435d69c3952b1a688971e9253b80a753820b4ef8573fdea30edc36d` |
| `test/goldens/trash/narrow-light.png` | `74748cce9dd9a1987377d46f18b84ab6ffaa7c2e4eec7f3f35b305cefad4ea98` |
| `test/goldens/trash/narrow-dark.png` | `2905f33937335a33cc0bc4e1045c07f573a3a42dad851fcb9f249c5da72a78ff` |

The R-12 gate is exercised for real: `accessibility_gate_test.dart` drives the
actual `DesktopNavigation` and `LiveTranscriptPanel` widgets under synthetic
`MediaQuery` reduce-motion states and asserts the animation duration, scroll
behavior (`isScrollingNotifier`), focus traversal/activation, Semantics
`flagsCollection`, and >44px hit targets. `loop8_visual_test.dart` renders the
settings and trash screens against the `TestAppServices` harness (real file +
Drift DB) at 1080×720 and 880×600 in light and dark.

## Internal review

- P0/P1/P2: none.
- P3-1 (accepted): the compact rail item is visually 8px taller (40→48) — the
  explicit WCAG 2.5.5 minimum-tap-target improvement the contract calls for.
- P3-2 (accepted): Semantics testing walks and dedupes destination nodes because
  the mutually-exclusive group merges them into a separate root; this is a
  test-layer adaptation only, no product behavior change.
- Verdict: `APPROVE`.

## Gate status

- `CODE_GATE`: APPROVED.
- `REVIEW_GATE`: APPROVED.
- `PLATFORM_GATE`: APPROVED — exact-commit CI on Loop 8 branch top `36f8285`:
  Shared quality `success`, Platform builds `success`.
- `OVERALL_LOOP8`: APPROVED.