# EasyMeeting Loop 2 技术合同

状态：`DRAFT_BLOCKED_BY_LOOP1_PLATFORM_GATE`

依赖：

- `docs/architecture/calm-focus-loop-baseline.md`
- `docs/architecture/loop-1-contract.md`
- Loop 1 exact-commit macOS Release 与 Windows Release 均成功

## 1. 启动条件

本文件可以在 Loop 1 平台门禁未完成时评审、修订和拆分任务，但不得据此修改任何产品代码。

只有开发首席将 Loop 1 的以下状态全部标记为 `APPROVED`，Loop 2 才能进入实施：

- `CODE_GATE`
- `VISUAL_GATE`
- `REVIEW_GATE`
- `PLATFORM_GATE`
- `OVERALL_LOOP1`

Windows 本机 Developer Mode/symlink 阻塞可以由同一提交 SHA 的 Windows CI Release 成功证据替代；macOS 必须由同一 SHA 的 macOS runner 完成 Release 构建。不得使用 Loop 1 基线提交、另一工作树或“预计通过”代替。

在 `PLATFORM_GATE` 未放行前，允许的工作仅限：只读审查、合同修改、任务拆分和仓库外原型；禁止变更本合同白名单中的产品文件。

## 2. 本轮目标

Loop 2 只重构桌面壳层，不改变页面业务：

1. 将 macOS/Windows `HomeShell` 统一为 Calm Focus 桌面导航壳层。
2. 固定紧凑与展开导航断点及最小窗口行为。
3. 保持四个真实入口：记录、会议库、回收站、设置。
4. 保持 `IndexedStack` 页面实例和页面内部状态，不因切换导航而重建业务页面。
5. 补齐导航和公共 Material 组件的 Hover、Pressed、Selected、Keyboard Focus、Disabled 状态。
6. 提供 macOS/Windows 桌面快捷键、Tab 顺序和清晰焦点环。
7. 不破坏现有移动端底部导航；移动端不做 Calm Focus 重设计。

## 3. 现有行为基线

- 桌面窗口默认 `1080×720`，最小 `880×600`：`lib/main.dart:18-24`。
- `HomeShell` 使用四个固定 destination：`lib/ui/home_shell.dart:21-40`。
- 移动端使用 `NavigationBar`，桌面使用 `NavigationRail`：`lib/ui/home_shell.dart:43-84`。
- 桌面当前在宽度 `>=1080` 时展开 NavigationRail：`lib/ui/home_shell.dart:60-62`。
- 页面通过 `IndexedStack` 保持实例：`lib/ui/home_shell.dart:48,80`。
- 进入会议库时调用 `meetingLibraryProvider.notifier.load()`：`lib/ui/home_shell.dart:87-92`。
- Loop 1 已集中建立 Calm Focus `ThemeTokens` 和 Material 组件主题；Loop 2 必须复用，不得新增第二套颜色体系。

上述行为除本合同明确要求外均视为回归保护项。

## 4. 文件白名单

实施 Agent 仅允许修改或新增以下文件：

### 4.1 产品文件

- `lib/ui/home_shell.dart`
- `lib/ui/theme/theme_tokens.dart`（仅限导航、焦点和公共组件状态的必要修正；不得改变 Loop 1 已批准的 Token 常量）
- `lib/ui/shell/desktop_navigation.dart`（可新增）
- `lib/ui/shell/shell_shortcuts.dart`（可新增）
- `lib/ui/shell/shell_focus.dart`（可新增；仅限焦点顺序/焦点表现）

### 4.2 测试文件

- `test/home_shell_test.dart`（可新增）
- `test/desktop_navigation_test.dart`（可新增）
- `test/shell_shortcuts_test.dart`（可新增）
- `test/theme_tokens_test.dart`（仅追加导航/焦点回归）

### 4.3 首席文档

- `docs/architecture/loop-2-contract.md`
- `docs/architecture/loop-2-review.md`（由开发首席新增）

如果实现需要白名单外文件，实施 Agent 必须停止并提交 `BLOCKED: scope expansion`。未经开发首席更新合同，不得先改后报。

## 5. 明确不做

本轮禁止：

- 修改 `lib/main.dart` 的窗口尺寸或窗口生命周期。
- 修改 `lib/app.dart`、Provider、路由、录音状态机、数据库、仓库、网络或后处理。
- 修改记录、会议库、回收站、设置、权限引导等页面内部布局。
- 新增、删除或重命名导航入口。
- 增加日历、联系人、模板管理、说话人、视频、AI 问答、分享协作等未实现功能。
- 改产品名称、bundle identifier、Windows executable 或安装包元数据。
- 接入 App Icon、Logo、插画或新字体；品牌资产属于后续独立切片。
- 自定义 macOS titlebar/traffic lights 或 Windows caption buttons。
- 新增第三方依赖或修改 `pubspec.yaml`/`pubspec.lock`。
- 修改 `macos/**`、`windows/**` 及任何 generated registrant。
- 删除 `IndexedStack`，或为动画而重建四个业务页面。
- 增加页面切换动画、复杂缩放动画或自定义手势。
- 改动移动端导航视觉；只允许保证共享代码不回退。

## 6. 桌面壳层规格

### 6.1 断点

桌面宽度契约：

| 窗口宽度 | 导航形态 | 导航目标宽度 | 说明 |
|---:|---|---:|---|
| `<880` | 不属于桌面支持窗口 | 不定义 | `window_manager` 已阻止；测试仅验证无异常 |
| `880–1079` | Compact | `72` | 图标为主，保留 Tooltip 和 Semantics label |
| `>=1080` | Extended | `224` | 显示图标和完整中文 label |

断点必须由单一常量定义，不得在 Widget 树中重复硬编码。`1080` 边界必须归入 Extended；`1079` 必须归入 Compact。

### 6.2 结构与尺寸

- 导航固定在内容左侧；分隔线使用 Loop 1 `outline` Token。
- 导航背景使用 `surface` 或 `background` Token，选择一种后 Light/Dark 保持一致语义。
- 顶部品牌区只使用现有通用图标和当前产品文案；不引入未批准图片资产。
- Compact 图标点击区至少 `40×40`；Extended destination 高度至少 `40`。
- destination 顺序固定：记录、会议库、回收站、设置。
- 选中态必须同时包含 indicator、selected icon 或字重变化，不能只靠颜色。
- 选中态、Hover、Pressed 不得改变 destination 的几何尺寸。
- 导航与内容之间不得产生双重滚动条。
- `IndexedStack` 必须保留；切换后原页面滚动位置、表单草稿和局部状态不得因壳层重建丢失。

### 6.3 导航行为

- 鼠标点击和键盘动作必须统一调用同一个 destination selection 方法。
- 重复选择当前 destination 不得重建页面，也不得重复触发不必要的数据读取。
- 首次切换到会议库时保持现有 reload 行为；实现不得扩大为所有页面无条件 reload。
- 录音进行中仍允许查看其他页面，保持现有行为；本轮不新增导航锁。
- 返回记录页不得开始、暂停或停止录音。

## 7. macOS 与 Windows 差异

共享行为：

- 两端使用相同布局、断点、Token、destination 顺序和焦点视觉。
- 两端 Tab/Shift+Tab、方向键、Enter/Space 行为一致。
- 两端均保留系统原生窗口边框和标题栏，不绘制伪原生控件。

平台快捷键：

| 动作 | macOS | Windows |
|---|---|---|
| 记录 | `⌘1` | `Ctrl+1` |
| 会议库 | `⌘2` | `Ctrl+2` |
| 回收站 | `⌘3` | `Ctrl+3` |
| 设置 | `⌘4` | `Ctrl+4` |

要求：

- 根据 `platformProfileProvider` 的 `PlatformKind` 选择平台主快捷键。
- 为自动化和外接键盘兼容，可以同时注册 Meta/Ctrl，但 UI 或 Tooltip 只能提示当前平台约定。
- 不覆盖系统级 `⌘Q`、`⌘W`、`Alt+F4`、`Ctrl+W`。
- macOS 不截获菜单栏原生事件；Windows 不模拟 macOS traffic lights。
- 快捷键必须在 TextField 获得焦点时仍谨慎处理：仅数字 1–4 加平台修饰键触发，普通输入不得丢失。

## 8. 键盘焦点与公共组件状态

### 8.1 焦点顺序

- Shell 使用明确的 `FocusTraversalGroup`。
- Tab 顺序：导航 destination 按视觉顺序，然后进入当前页面内容。
- Shift+Tab 反向遍历。
- 导航获得焦点时，上/下方向键移动到前/后 destination；Home/End 可作为非阻塞增强，但不是本轮必需。
- Enter 或 Space 激活当前聚焦 destination。
- 页面切换后焦点不得丢到不可见 IndexedStack 子树。
- 键盘快捷键切换页面后，焦点应保持在可见 Shell 或新页面的有效节点；不得落在旧页面控件。

### 8.2 状态表现

必须覆盖：

- Default
- Hover
- Pressed
- Selected
- Keyboard Focus
- Disabled（公共按钮主题回归；导航 destination 当前无业务禁用态）

焦点环必须使用 Loop 1 `focus`、`focusRingWidth=2` 和 `focusOutlineWidth=2` 语义。不得通过修改批准的颜色常量提高对比；如现有 Theme API 无法形成外扩环，可使用无布局位移的 decoration/overlay。

公共按钮必须继续保持 `Size(0, 40)` 的内容宽度下限，禁止重新引入无限宽 P1。IconButton 最小目标维持 `40×40`。

动态状态不能导致布局位移；本轮不新增 Loading 行为，但不得破坏 Loop 1 的 Disabled 规则。

### 8.3 Semantics 与 Tooltip

- Compact destination 必须有 Tooltip 和 Semantics label。
- selected 状态必须通过 Semantics 暴露。
- 装饰性品牌图标不得被重复朗读。
- Tooltip 必须显示当前平台快捷键，例如 macOS `会议库（⌘2）`、Windows `会议库（Ctrl+2）`。
- 语义顺序与视觉顺序一致。

## 9. 精确验收标准

### 9.1 代码与范围

- git diff 的产品/测试文件全部位于白名单。
- 无 generated registrant、平台工程、依赖锁文件或业务页面变更。
- `dart format --output=none --set-exit-if-changed` 通过。
- `flutter analyze` 为 0 issue。
- 全量 `flutter test` 通过。
- Loop 1 的 90 项既有测试不得减少或跳过；Loop 2 新增测试计入新总数。

### 9.2 布局

- `880×600` Light/Dark：Compact，导航宽 `72`，无 overflow、裁切和双滚动条。
- `1079×720`：Compact。
- `1080×720` Light/Dark：Extended，导航宽 `224`。
- `1440×900`：Extended，内容正常扩展，不把页面无限拉宽到不可读。
- textScale `1.0` 与 `1.25` 均无导航 label 裁切；Compact 依靠 Tooltip/Semantics。
- destination 点击区满足最小尺寸。

### 9.3 行为

- 鼠标点击四个入口均显示正确页面。
- macOS `⌘1–4`、Windows `Ctrl+1–4` 对应正确入口。
- Tab、Shift+Tab、方向键、Enter、Space 可完全操作导航。
- 焦点环可见且不被导航边界裁切。
- 快捷键切换后没有不可见焦点。
- 页面局部状态在导航往返后保留。
- 重复选择当前 destination 不重复 reload。
- 进入会议库的既有加载行为保留。
- 移动端仍使用四项底部 `NavigationBar`，无功能回退。

### 9.4 视觉

- 所有颜色来自 `ThemeTokens`/`ColorScheme`，Shell 不出现新 `Color(0x...)` 或 `Colors.*` 业务颜色。
- Light/Dark 都符合 Calm Focus。
- Compact/Extended 的选中、Hover、Pressed、Focus 状态无尺寸跳动。
- 选中态不是仅颜色表达。
- Loop 1 按钮内容宽度和禁用态视觉不回退。

### 9.5 平台

- 同一 Loop 2 commit 的 Windows Release build 成功。
- 同一 commit 的 macOS Release build 成功。
- Windows 至少一张真实窗口截图验证系统标题栏和键盘焦点。
- macOS 至少一张真实窗口截图验证原生窗口、快捷键和焦点；CI 组件图不能替代最终平台 smoke。

## 10. 测试矩阵

| 测试类型 | 场景 | 必须断言 |
|---|---|---|
| Unit | breakpoint `879/880/1079/1080/1440` | Compact/Extended 边界精确 |
| Widget | 880×600 desktop | Compact 宽度 72、四入口、无异常 |
| Widget | 1080×720 desktop | Extended 宽度 224、中文 label 可见 |
| Widget | Light/Dark | Shell、divider、indicator、focus 使用 Token |
| Widget | 点击 1–4 | selected index 与可见页面一致 |
| Widget | 重复点击当前项 | 页面不重建、会议库不重复 reload |
| Widget | IndexedStack 往返 | 页面 Key/局部测试状态保留 |
| Widget | macOS profile | `⌘1–4` 生效，Ctrl 提示不显示 |
| Widget | Windows profile | `Ctrl+1–4` 生效，⌘ 提示不显示 |
| Widget | TextField focus | 普通数字输入不触发导航；带修饰键才触发 |
| Widget | Tab/Shift+Tab | 焦点按视觉顺序移动 |
| Widget | Arrow/Enter/Space | 聚焦和激活 destination 正确 |
| Semantics | Compact/Extended | label、selected、顺序、装饰图标正确 |
| Regression | Button themes | minimum width 0、height 40 |
| Regression | Mobile profile | Bottom NavigationBar 和四入口保持 |
| Build | Windows Release | exact commit 成功 |
| Build | macOS Release | exact commit 成功 |

测试不得用复制 HomeShell 的假 Widget 替代生产实现。允许通过 Provider override 注入 macOS/Windows `PlatformProfile` 和测试页面，但必须直接构建真实 `HomeShell` 或抽出的真实 Shell 组件。

## 11. 截图矩阵

仓库外视觉 harness 必须直接 import 当前 commit 的真实 Shell、`easyMeetingTheme` 和确定性页面 fixture。PNG 不进入 git diff。

### 11.1 自动化组件截图

最小 8 张：

| 文件建议名 | 尺寸 | 主题 | destination | 状态 |
|---|---:|---|---|---|
| `shell-record-light-880x600.png` | 880×600 | Light | 记录 | Compact Selected |
| `shell-library-dark-880x600.png` | 880×600 | Dark | 会议库 | Compact Selected |
| `shell-focus-light-880x600.png` | 880×600 | Light | 回收站 | Compact Keyboard Focus |
| `shell-settings-focus-dark-880x600.png` | 880×600 | Dark | 设置 | Compact Keyboard Focus |
| `shell-record-light-1080x720.png` | 1080×720 | Light | 记录 | Extended Selected |
| `shell-library-dark-1080x720.png` | 1080×720 | Dark | 会议库 | Extended Selected |
| `shell-focus-light-1080x720.png` | 1080×720 | Light | 回收站 | Extended Keyboard Focus |
| `shell-settings-focus-dark-1080x720.png` | 1080×720 | Dark | 设置 | Extended Keyboard Focus |

每张记录 SHA-256、字节数、Flutter/Dart 版本、pixel ratio、text scale、commit SHA 和生成命令。日志不得有 Flutter exception 或 overflow。

### 11.2 平台 smoke 截图

- Windows：`1080×720` Light，Extended，导航 Keyboard Focus 可见，包含真实系统窗口框架。
- macOS：`1080×720` Dark，Extended，导航 Keyboard Focus 可见，包含原生 traffic lights。

平台截图只验证 Shell 与原生窗口共存；不得借本轮改造标题栏。

## 12. 三方交接

### 12.1 开发 Agent

```text
Loop: 2
Base commit:
Implementation commit/working tree:
Platform gate that authorized start:
Changed files:
Contract items satisfied:
Breakpoints implemented:
Keyboard map implemented:
State-preservation evidence:
Commands and results:
Screenshot manifest:
Known risks:
Requested decision: READY_FOR_QA | BLOCKED
```

开发 Agent 必须附 `git diff --name-status`、测试新增数量和两端构建链接。不得用 Loop 1 的截图或构建证据复用为 Loop 2 证据。

### 12.2 QA Agent

```text
Loop: 2
Environment:
Commit:
Scope gate: PASS | FAIL
Automated tests: PASS | FAIL | BLOCKED
Breakpoint matrix: PASS | FAIL
Keyboard matrix macOS: PASS | FAIL | BLOCKED
Keyboard matrix Windows: PASS | FAIL | BLOCKED
Semantics/focus: PASS | FAIL
Visual matrix: PASS | FAIL
Windows Release/smoke: PASS | FAIL | BLOCKED
macOS Release/smoke: PASS | FAIL | BLOCKED
Evidence paths:
Defects by P0/P1/P2/P3:
Recommendation: APPROVE | CHANGES_REQUESTED | BLOCKED
```

QA 必须独立运行测试并核对 PNG，不接受开发 Agent 的自报结论。任何 overflow、不可见焦点、错误快捷键、页面状态丢失或白名单越界至少为 P1。

### 12.3 GLM Reviewer

```text
Loop: 2
Reviewer/model/session:
Commit reviewed:
Contract and whitelist reviewed: YES | NO
Architecture findings:
Cross-platform findings:
Focus/semantics findings:
State-preservation findings:
P0:
P1:
P2:
P3:
Verdict: APPROVE | REQUEST_CHANGES | BLOCKED
```

GLM reviewer 必须重点检查：

- 是否为视觉重构破坏 `IndexedStack` 状态所有权。
- 快捷键是否误拦截文本输入或系统快捷键。
- 焦点是否可能落入不可见页面。
- breakpoint 是否散落硬编码。
- 是否重复实现 Loop 1 Token 或引入页面级颜色。
- 是否修改白名单外业务代码。

## 13. 回滚边界

Loop 2 不允许数据库迁移、依赖变更、平台工程变更或资产格式变更，因此必须保持单提交可回滚。

回滚规则：

- 回滚目标仅为 Loop 2 实现提交及其新增测试。
- 不回滚 Loop 1 Calm Focus Token 常量和 tray truth 修复。
- 若 `theme_tokens.dart` 同时含 Loop 1 与 Loop 2 修改，回滚只能撤销 Loop 2 导航/焦点差异，不得整文件覆盖。
- 不删除用户数据、设置、会议、录音、转写或纪要。
- 不使用 `git reset --hard`、`git checkout --` 等破坏性命令处理回滚。
- 若 Shell 在某平台启动失败，优先回滚到原 `HomeShell` + Loop 1 Theme；不得通过修改业务页面绕过。
- generated registrant、平台工程和依赖锁文件不应出现在提交中；若出现，提交直接驳回而不是“回滚后接受”。

## 14. 首席放行

Loop 2 只有在以下条件全部成立时才可 `APPROVED`：

- 启动前 Loop 1 `OVERALL_LOOP1=APPROVED`。
- 产品和测试 diff 严格位于白名单。
- 全部断点、键盘、焦点、状态保持和 Semantics 测试通过。
- 8 张自动化截图和两张平台 smoke 截图通过。
- exact-commit macOS/Windows Release 均成功。
- QA 推荐 `APPROVE`。
- GLM reviewer 为 `APPROVE`，且无 P0/P1/P2。
- 开发首席复核无范围扩张、无功能真实性回退。

在任何平台构建或 smoke 尚未完成时，状态必须是 `BLOCKED_PENDING_PLATFORM_GATE`，不得以 CODE/QA/REVIEW 通过替代整体放行。
