# EasyMeeting Loop 8 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、Loop 7 exact-commit
`OVERALL_LOOP7=APPROVED`。

## 1. 本轮目标

设置、回收站、插画与无障碍门禁（R-12）：

1. **减少动态效果（reduce-motion）**：应用尊重系统 `MediaQuery.disableAnimations`。
   导航栏选中动画与实时转写自动滚动在减少动态效果开启时不再运行动画（时长归零/直接跳转）。
2. **键盘顺序与焦点环**：导航栏已在点击后 `requestFocus` 并带 `shellFocusRingDecoration`
   焦点环；本轮补端到端键盘导航测试（Tab 按序聚焦、焦点环出现、Enter 激活）。
3. **Semantics**：导航目的地已带 `Semantics(label, button, selected,
   inMutuallyExclusiveGroup)`；本轮补断言测试，并核对主要交互有语义标签。
4. **点击区**：紧凑导航栏项视觉 40px → 提升到 48px 最小可点区域（WCAG 2.5.5 目标尺寸），
   并有测试断言主要控件可点区 ≥44。
5. **设置与回收站回归**：两屏已实现（`settings_screen.dart`/`trash_screen.dart`），本轮做
   Calm Focus 视觉冒烟（多尺寸、light/dark、无溢出）并补 golden。

## 2. 文件白名单

- `lib/ui/shell/desktop_navigation.dart`（reduce-motion 门控 AnimatedContainer；紧凑项
  minHeight 40→48）
- `lib/ui/recording/live_transcript_panel.dart`（reduce-motion 门控自动滚动）
- `test/accessibility_gate_test.dart`（新增：reduce-motion、键盘顺序、Semantics、点击区）
- `test/loop8_visual_test.dart`（新增：设置/回收站 多尺寸 light/dark 冒烟）
- `docs/architecture/loop-8-contract.md`、`loop-8-review.md`（首席文档）
- `docs/acceptance/loop-8-acceptance.md`（证据）

不改动：业务逻辑、持久化、录音/转写/纪要核心、原生插件。只改呈现层与无障碍。

## 3. 现状核对

| 项 | 现状 | 本轮 |
|---|---|---|
| 导航焦点环 | 已实现 `shellFocusRingDecoration` | ✅ 测试 |
| 导航 Semantics | 已实现 label/button/selected | ✅ 测试 |
| 减少动态效果 | 无门控 | ➕ AnimatedContainer/滚动门控 |
| 紧凑导航点击区 | 40px | ➕ 48px |
| 设置屏 | 已实现 | ✅ 冒烟 |
| 回收站屏 | 已实现 | ✅ 冒烟 |

## 4. 设计

### 4.1 减少动态效果

`desktop_navigation.dart` 的 `AnimatedContainer`：
`duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 120)`。
`live_transcript_panel.dart` 的 `_scrollToLatest`：`disableAnimations ? jumpTo(max) :
animateTo(...)`。

### 4.2 紧凑导航点击区

`AnimatedContainer.constraints.minHeight`：compact 40 → 48（与 extended 一致）。使
紧凑导航项可点区 ≥48px，改善键盘/指点目标。

### 4.3 无障碍测试授权

`test/accessibility_gate_test.dart`：
- reduce-motion：`MediaQuery(disableAnimations: true)` 下导航选中无动画（无进行中
  AnimationController 时长）。
- 键盘顺序：Tab 聚焦导航项、焦点环出现、Enter 触发选中。
- Semantics：导航项暴露 label/selected/button。
- 点击区：主要控件（导航项、开始录音、播放等）`RendererBox.size` ≥44。

`test/loop8_visual_test.dart`：设置/回收站 1080×720 与 880×600、light/dark 冒烟。
像素级 golden 用 `EM_GEN_GOLDENS=1 --update-goldens`；默认 CI 为确定性冒烟断言。
golden PNG 在 `test/goldens/settings|trash/`，属仓库外证据（不提交），SHA-256 录入
`loop-8-review.md`。

## 5. 精确验收

- `MediaQuery.disableAnimations == true` 时导航选中与实时滚动不运行动画（测试）。
- 键盘 Tab 按序聚焦导航项，焦点环可见，Enter 激活目标（测试）。
- 导航目的地 Semantics label/selected/button 正确暴露（测试）。
- 主要控件点击区 ≥44（测试）。
- 设置/回收站多尺寸 light/dark 渲染无溢出（冒烟）。
- 全量 format/analyze/test 通过。
- Shared quality 与 Platform builds exact-commit CI 成功。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。