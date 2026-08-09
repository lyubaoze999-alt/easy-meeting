# EasyMeeting Loop 8 内部评审

状态：APPROVE
评审人：实现者（独立内部评审）
评审基线与范围：`docs/architecture/loop-8-contract.md`

## 1. 本轮改动

| 文件 | 变更 |
|---|---|
| `lib/ui/shell/desktop_navigation.dart` | `AnimatedContainer` 选中动画门控「减少动态效果」：`MediaQuery.disableAnimationsOf(context) ? Duration.zero : 120ms`；紧凑项 minHeight 40→48（与 extended 一致，WCAG 2.5.5 目标尺寸） |
| `lib/ui/recording/live_transcript_panel.dart` | `_scrollToLatest` 门控减少动态效果：`disableAnimations ? jumpTo(max) : animateTo(180ms easeOut)` |
| `test/accessibility_gate_test.dart`（新增） | R-12 门禁：reduce-motion（导航动画归零、实时滚动跳转 vs 动画）、键盘顺序与焦点环、Semantics label/button/selected、点击区 ≥44 |
| `test/loop8_visual_test.dart`（新增） | 设置/回收站 1080×720 / 880×600 × light/dark 冒烟（无溢出） |
| `test/goldens/settings|trash/*.png` | 8 张像素 golden（仓库外证据，SHA-256 见下） |
| `docs/architecture/loop-8-contract.md`、`loop-8-review.md` | 本轮合同 + 评审 |

## 2. 需求符合性

- **减少动态效果（R-12）**：导航选中动画与实时转写自动滚动在 `disableAnimations` 时不再动画。
  测试分别断言 `AnimatedContainer.duration == Duration.zero`（on）`== 120ms`（off），以及
  实时滚动在 reduce-motion 下 `jumpTo`（无进行中滚动动画）vs 常态 `animateTo`（进行中）。
- **键盘顺序与焦点环（R-12）**：导航项已带 `FocusNode` + `shellFocusRingDecoration`；
  测试断言聚焦后焦点环边框用 `tokens.focus`，且 Arrow 移动焦点、Enter/Space 激活目标。
- **Semantics（R-12）**：导航目的地已带 `Semantics(label, button, selected,
  inMutuallyExclusiveGroup)`；测试经 `ensureSemantics` 遍历去重后的节点，断言暴露
  button+group+label，且选中项（回收站）节点 `isSelected`。
- **点击区（R-12）**：紧凑导航项 mminHeight 40→48，全部导航项可点区 ≥44（测试断言
  compact 与 extended 的 AnimatedContainer 高宽 ≥44）。
- **设置/回收站回归**：两屏经多尺寸 light/dark 冒烟无溢出，golden 生成。

## 3. 透明化决策

- Semantics 测试因导航目的地处于独立 semantics 根（`inMutuallyExclusiveGroup` 会合并节点），
  采用「遍历去重节点」而非单节点断言；`SemanticsNode.hasFlag` 已弃用，改用
  `flagsCollection`。纯测试层适配，不影响产品行为。
- reduce-motion 的实时滚动测试用 `isScrollingNotifier` 区分 `jumpTo`（无动画）与
  `animateTo`（进行中），规避 `ListView.builder` 懒布局导致的 maxScrollExtent 不稳定。

## 4. 发现

### P1（无）
### P2（无）
### P3（接受）

- **P3-1 紧凑导航项视觉增高 8px**：40→48 使紧凑模式每项略高一点，换取 ≥48px 点击目标。
  属合同明确的 WCAG 2.5.5 改进。接受。

## 5. 客观证据

- `dart format --output=none --set-exit-if-changed`：全部通过。
- `flutter analyze`：No issues found。
- `flutter test`：201 passed（含 Loop 8 的 10 个无障碍门禁测试 + 8 个视觉冒烟）。
- 视觉 golden（`EM_GEN_GOLDENS=1 --update-goldens`）SHA-256（仓库外证据）：
  - `test/goldens/settings/extended-light.png` `f8c520e04394e5d4c2cbaf41c5053dd371e7e5f0a16e14be0233c3a46b97ab65`
  - `test/goldens/settings/extended-dark.png`  `ed37f214b5c928808e653a3d3ac77cb18202d1cdfd647f9c44ba72d44b08d99e`
  - `test/goldens/settings/narrow-light.png`  `44f833f367456f92869cab91999eee87da2a368461ec3074df578fa0b65364fa`
  - `test/goldens/settings/narrow-dark.png`   `d27719bfe9792b337b700a39da1723f71595a6ea30fa263d19eb63130f77c8af`
  - `test/goldens/trash/extended-light.png`   `873551a781b2e0a54bb0de795b91005e9911b251e63bd98c4308964de7aa71cf`
  - `test/goldens/trash/extended-dark.png`    `b29c32a5e435d69c3952b1a688971e9253b80a753820b4ef8573fdea30edc36d`
  - `test/goldens/trash/narrow-light.png`     `74748cce9dd9a1987377d46f18b84ab6ffaa7c2e4eec7f3f35b305cefad4ea98`
  - `test/goldens/trash/narrow-dark.png`      `2905f33937335a33cc0bc4e1045c07f573a3a42dad851fcb9f249c5da72a78ff`

## 6. 结论

R-12 无障碍门禁全部落地：减少动态效果、键盘顺序与焦点环、Semantics、点击区，并回归
设置/回收站多尺寸 light/dark 无溢出。改动仅限呈现层与工具，未触碰业务逻辑与原生插件。
测试全绿，analyze 无告警。APPROVE。

`OVERALL_LOOP8_REVIEW = APPROVE`