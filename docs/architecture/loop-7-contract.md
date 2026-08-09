# EasyMeeting Loop 7 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、`loop-6-contract.md`、
`loop-6-acceptance.md`、Loop 6 exact-commit `OVERALL_LOOP6=APPROVED`。

## 1. 本轮目标

会议详情、播放、导出与独立删除：

1. **默认纪要（R-03 配套）**：设计规格要求详情页默认打开"纪要"标签；当前代码默认
   打开"录音"。改为：当会议已有可用纪要时默认落在"纪要"标签，否则回落到"录音"。
2. **播放器能力真实（R-03）**：详情页内嵌的 Slider/播放态从未接线（`isPlaying` 恒
   false、`playbackPosition` 恒 zero），是误导性的假控件。按 R-03 的两种合规解法之
   一，改为**明确的外部打开交互**：移除假 Slider，替换为"使用系统播放器播放"主按钮，
   真正经系统默认播放器播放录音文件。不再展示无法工作的进度条。
3. **三个资产独立操作 + 缺失/损坏状态 + 删除提示**：录音/转写/纪要可分别删除、导出、
   展示独立缺失/损坏/就绪状态，删除均有确认对话框。已实现，本轮回归验证并补测试。
4. 透明化：不引入新的原生音频依赖（避免改动平台插件图，真机音频验收仍由 Loop 9/10
   门禁）。

## 2. 文件白名单

- `lib/ui/library/meeting_detail_screen.dart`（默认标签；`_RecordingTab` 播放卡改为
  明确的外部打开交互）
- `lib/ui/library/connected_meeting_library_screen.dart`（如需，播放按钮文案/回调）
- `test/meeting_detail_screen_test.dart`（可新增：默认纪要标签、播放卡文案、独立删除
  确认、缺失/损坏状态回归）
- `test/loop7_visual_test.dart`（可新增：详情页 1080×720 / 880×600、light/dark 冒烟）
- `docs/architecture/loop-7-contract.md`、`loop-7-review.md`（首席文档）
- `docs/acceptance/loop-7-acceptance.md`（证据）

不改动：持久化、录音/转写/纪要核心、原生插件、设置、回收站、托盘。只改详情呈现层与
播放交互。

## 3. 现状核对

| 项 | 现状 | 本轮 |
|---|---|---|
| 详情默认标签 | 录音（index 0） | ➕ 纪要（有纪要时） |
| 内嵌播放器 | 假 Slider + 假播放态 | ➕ 明确外部打开播放 |
| 独立删除三资产 | 已实现 + 确认对话框 | ✅ 回归 |
| 缺失/损坏状态 | 已实现（R-04 投影） | ✅ 回归 |
| 导出 WAV / Markdown | 已实现 | ✅ 回归 |

## 4. 设计

### 4.1 默认标签

`MeetingDetailScreen` 的 `DefaultTabController(initialIndex: ...)`：当
`effectiveNoteStatus == ready` 且 `note != null` 时 `initialIndex = 2`（纪要），否则
`0`（录音）。`DefaultTabController` 只取 `initialIndex` 一次，切换后由用户主导。

### 4.2 明确的外部打开播放（R-03）

`_RecordingTab` 可播放分支：删除 `IconButton.filled` 播放/暂停切换、`Slider`、
`position/duration` 时钟。替换为居中的 `FilledButton.icon`："使用系统播放器播放"，
`onPressed: onPlay`（回调仍由 connected screen 调用 `open`/`cmd start` 打开系统播放器，
真实播放该 WAV）。保留 来源/时长/文件大小/格式 元数据。`onSeekRecording`/`isPlaying`/
`playbackPosition` 参数保留但不再渲染假控件（或无调用方时置空）。

### 4.3 视觉冒烟测试授权

`test/loop7_visual_test.dart` 以 1080×720 与 880×600 确定性渲染真实详情页（含录音
可播放 + 纪要就绪），light/dark。像素级 golden 通过 `EM_GEN_GOLDENS=1 --update-goldens`
门控；默认 CI 路径为确定性冒烟断言。golden PNG 在 `test/goldens/detail/`，属仓库外
证据（不提交），SHA-256 录入 `loop-7-review.md`。

## 5. 精确验收

- 有纪要的会议详情默认落在"纪要"标签（有纪要→默认纪要；无纪要→默认录音）。
- 可播放录音详情不再渲染假 Slider；渲染"使用系统播放器播放"按钮，点击触发
  `onPlayRecording`。
- 三资产独立删除均有确认对话框，删除后各自消失、互不影响（回归）。
- 缺失/损坏/处理中/失败状态由 R-04 投影驱动（回归）。
- 全量 format/analyze/test 通过。
- Shared quality 与 Platform builds exact-commit CI 成功。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。