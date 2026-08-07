# EasyMeeting Loop 1 实施合同

状态：待 GLM 实施

依赖：`docs/architecture/calm-focus-loop-baseline.md`

目标：修复用户可见的产品真实性错误，并建立 Calm Focus 全局视觉 Token；不重排页面、不改业务行为、不改原生音频。

## 1. 本轮结果

Loop 1 完成后必须同时得到：

- 托盘停止操作只承诺“结束录音”。
- 本地录音完成只显示“录音已保存”，不会冒充“纪要已生成”。
- Light/Dark Calm Focus 颜色、排版、间距、圆角、描边、状态和 Material 组件主题成为唯一全局视觉来源。
- 现有页面结构、录音状态机、持久化、后处理、网络和平台能力保持不变。
- 新增测试能够阻止错误文案和旧靛蓝主题回归。

## 2. 文件白名单

GLM 只允许修改或新增以下产品/测试文件：

- `lib/ui/theme/theme_tokens.dart`
- `lib/desktop/desktop_tray_controller.dart`
- `lib/desktop/desktop_tray_presentation.dart`（可选；仅用于抽取可单测的纯文案/状态映射，不得依赖插件）
- `test/theme_tokens_test.dart`（可新增）
- `test/desktop_tray_presentation_test.dart`（可新增）
- `test/recording_redesign_widget_test.dart`（仅增加真实性回归断言）

文档由开发首席维护，GLM 不得擅自扩写范围。若实现必须触碰白名单以外文件，立即停止并提交 `BLOCKED: scope expansion`，说明文件、原因和最小替代方案；不得先改后报。

## 3. 明确禁止文件与行为

禁止修改：

- `lib/app_services/**`
- `lib/domain/**`
- `lib/infrastructure/**`
- `lib/ui/recording/**`（除白名单中的测试文件，不含产品页面）
- `lib/ui/library/**`
- `lib/ui/settings/**`
- `lib/ui/trash/**`
- `lib/ui/onboarding/**`
- `packages/audio_capture/**`
- `macos/**`
- `windows/**`
- `android/**`
- `ios/**`
- `pubspec.yaml`、`pubspec.lock`
- 数据库 schema、迁移、API 配置和生成资产

禁止行为：

- 不重排任何页面或导航。
- 不新增功能入口、按钮、路由、依赖或第三方包。
- 不修改录音、实时转写、后处理或退出状态机。
- 不删除旧 Pipeline 或旧会议库界面。
- 不接入 App Icon、Logo 或空状态插画。
- 不用截图测试代替行为测试，也不通过更新预期值掩盖回归。
- 不执行 destructive git 命令，不覆盖其他 Agent 的并行修改。

## 4. Calm Focus 精确 Token

以下数值是 Loop 1 合同常量。任何更改必须由开发首席先批准并更新本合同。

### 4.1 Light

| Token | 值 |
|---|---|
| `background` | `#F6F5EF` |
| `surface` | `#FFFFFF` |
| `surfaceSubtle` | `#EFF1EC` |
| `primary` | `#4F6F5B` |
| `primaryHover` | `#435F4D` |
| `primaryPressed` | `#384F41` |
| `primaryContainer` | `#DDE8DF` |
| `onPrimary` | `#FFFFFF` |
| `textPrimary` | `#202721` |
| `textSecondary` | `#667068` |
| `outline` | `#D7DDD6` |
| `outlineStrong` | `#B7C1B9` |
| `focus` | `#557A65` |
| `success` | `#3F7654` |
| `warning` | `#A56B1F` |
| `danger` / recording | `#C84B44` |

### 4.2 Dark

| Token | 值 |
|---|---|
| `background` | `#121613` |
| `surface` | `#1B211D` |
| `surfaceSubtle` | `#222A25` |
| `primary` | `#91B29B` |
| `primaryHover` | `#A2C1AA` |
| `primaryPressed` | `#7DA48A` |
| `primaryContainer` | `#2E4436` |
| `onPrimary` | `#142018` |
| `textPrimary` | `#ECF1EC` |
| `textSecondary` | `#AAB5AC` |
| `outline` | `#39443D` |
| `outlineStrong` | `#56635A` |
| `focus` | `#A8D0B4` |
| `success` | `#92C9A2` |
| `warning` | `#F1C27A` |
| `danger` / recording | `#FFB4AC` |

### 4.3 尺寸与排版

- 间距阶梯：`4, 8, 12, 16, 20, 24, 32, 40, 48`。
- 圆角：small `8`、control `10`、card `16`、dialog `20`、pill `999`。
- 默认卡片 elevation 为 `0`，使用 1px `outline`；浮层最多使用 elevation `8`。
- 主按钮最小高度 `40`，紧凑按钮 `32`；默认水平 padding `16`。
- 焦点环 `2px focus`，视觉外扩 `2px`；不得只靠颜色表达状态。
- 字体使用系统字体，不在本轮引入字体资产。
- Typography：
  - display：32/40，weight 600
  - headline：24/32，weight 600
  - title：18/26，weight 600
  - body：14/22，weight 400
  - label：13/18，weight 500
  - caption：12/16，weight 400

### 4.4 组件主题

`easyMeetingTheme` 必须集中定义以下主题，不允许在本轮修改页面以补样式：

- `ColorScheme`
- `Scaffold`、`AppBar`
- `Card`
- `FilledButton`、`OutlinedButton`、`TextButton`、`IconButton`
- `InputDecoration`
- `NavigationRail`、`NavigationBar`
- `Dialog`
- `Divider`
- `Chip`
- `ProgressIndicator`
- `Focus`/overlay 状态

状态规则：

- Hover 使用对应 `primaryHover` 或 8% primary state layer，不改变布局。
- Pressed 使用 `primaryPressed` 或 12% state layer；Loop 1 不增加缩放动画。
- Disabled 必须保持文案可读，前景不低于 38% opacity，背景不低于 12% opacity。
- Keyboard focus 必须可见；不能依赖鼠标 Hover。
- Loading 组件交互留到页面切片；Loop 1 只建立不跳动的尺寸基础。

## 5. 产品真实性修复

必须满足以下精确映射：

| 场景 | 允许文案 | 禁止文案 |
|---|---|---|
| 录音中托盘停止动作 | `结束录音` | `结束并生成纪要` |
| capture 已 recorded、纪要状态未知 | `录音已保存` | `纪要已生成` |
| 真实纪要生成完成 | 本轮不改变现有通知/页面 | 不允许由 capture phase 推断 |

`DesktopTrayController` 可以继续调用兼容 stop-only 方法，但用户可见文案必须准确。推荐将托盘文案/状态映射抽成无插件依赖的纯函数，供单元测试调用；不得借此重构会话状态机。

## 6. GLM 开发要求

GLM 在开始前必须：

1. 读取本合同和 Loop 0 基线。
2. 执行 `git status --short`，记录已有改动并避免覆盖。
3. 搜索 `结束并生成纪要`、`纪要已生成`、`#6366F1` 和 `ThemeTokens` 的全部引用。
4. 先提交简短实现说明，再修改白名单文件。

GLM 必须提交：

```text
Loop: 1
Commit/working tree:
Changed files:
Contract items satisfied:
Behavior intentionally unchanged:
Commands and results:
Screenshots: light/dark at 1080x720
Known risks:
Requested decision: READY_FOR_QA | BLOCKED
```

实现质量要求：

- `ThemeTokens.copyWith` 和 `lerp` 必须覆盖所有新增字段。
- Light/Dark `ThemeData` 均从对应 Token 派生，不复制散落颜色。
- 不保留 `#6366F1` 作为可见主色。
- 不使用 `Colors.green` 等页面硬编码来伪造本轮覆盖；页面硬编码将在对应页面 Loop 处理。
- 不改变任何公共业务 API。
- 新增测试必须验证语义值和状态映射，不能只验证 Widget 存在。

GLM 自检命令：

```powershell
dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test
flutter analyze
flutter test
Push-Location packages/audio_capture
flutter analyze
flutter test
Pop-Location
flutter build windows --release
```

macOS Release build 由 CI/macOS 执行；GLM 必须提供对应 run 或明确标记 `BLOCKED`，不能写“预计通过”。

## 7. QA 独立验证要求

QA 不接受仅由 GLM 提供的结论，必须从 GLM 提交的 commit/working tree 独立执行验证。

### 7.1 自动化

- 全量 format/analyze/test 通过。
- `theme_tokens_test.dart` 至少验证：
  - Light/Dark 全部合同颜色精确相等。
  - 间距、圆角和 Typography 精确相等。
  - `copyWith` 不丢字段。
  - `lerp(t=0/1)` 返回两端等价语义值。
  - Filled/Outlined/Text/Icon button、Card、Input、Navigation、Dialog、Chip 已接入主题。
- 托盘纯映射测试至少验证 recording、paused、recorded 三个状态。
- 全仓用户可见代码中不存在 `结束并生成纪要`。
- capture recorded 的托盘状态不存在 `纪要已生成`。

### 7.2 视觉与交互

QA 提交 1080×720 Light/Dark 截图，至少覆盖 HomeShell 和一个带表单/按钮/卡片的页面，并确认：

- 暖色背景、白/深色 surface、鼠尾草绿主色正确。
- 文字、边框、按钮和焦点环可辨识。
- 页面没有因全局 Theme 产生溢出、裁切或不可读状态。
- Hover、Pressed、Keyboard Focus、Disabled 在 Windows 或 macOS 桌面至少实测一种；另一平台至少完成构建并在对应平台 Loop 补齐实测。
- 880×600 和 1080×720 均无新增布局回归。

QA 输出格式：

```text
Loop: 1
Environment:
Commit:
Automated gates: PASS | FAIL | BLOCKED
Truth-copy checks: PASS | FAIL
Light visual: PASS | FAIL
Dark visual: PASS | FAIL
Keyboard/focus: PASS | FAIL
Windows release: PASS | FAIL | BLOCKED
macOS release: PASS | FAIL | BLOCKED
Evidence paths:
Defects with severity:
Recommendation: APPROVE | CHANGES_REQUESTED | BLOCKED
```

## 8. 首席放行标准

只有以下条件全部成立，Loop 1 才能 `APPROVED`：

- git diff 只包含文件白名单。
- 精确 Token、组件主题和产品真实性映射全部满足。
- GLM 自检通过并提交可追踪证据。
- QA 独立验证为 APPROVE。
- macOS、Windows Release 均有实际成功证据。
- 无 P0/P1；不存在通过删测试、降低断言或扩大范围规避合同的行为。

出现以下任一情况直接 `CHANGES_REQUESTED`：

- 修改白名单外文件。
- 用户仍能看到“结束并生成纪要”或 capture 推断出的“纪要已生成”。
- 颜色/间距/圆角与本合同不一致且无已批准 ADR。
- 页面结构或业务行为发生变化。
- 只有截图没有测试，或只有 GLM 自测没有 QA 独立证据。
- 以单个平台结果替代另一平台。

Loop 1 完成不代表整体产品完成；放行后进入 Loop 2 桌面 Shell、导航、品牌与响应式切片。
