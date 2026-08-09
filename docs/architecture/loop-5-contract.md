# EasyMeeting Loop 5 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、`loop-4-contract.md`、
`loop-4-acceptance.md`、Loop 4 exact-commit `OVERALL_LOOP4=APPROVED`。

## 1. 本轮目标

实时录音工作区（`MeetingWorkspace`）完整交互与平台差异：

1. **R-09（P2）平台差异**：Windows 等不支持实时 PCM 的平台，录音工作区不得再渲染
   误导性的空"实时文字"面板。改为按能力渲染"仅本地录音"提示，明确告知实时转写在
   本平台不可用、录音仍正常本地保存、可录音后生成转写。
2. **安全结束（设计规格缺口）**：结束录音前显示二次确认对话框；取消则保持录音，
   确认才执行安全结束（原生停止 → WAV 校验 → 数据库归档）。明确不承诺任何 AI 工作。
3. **状态机 / 暂停 / 继续 / 重点 / 断网降级**：由真实会话与实时 provider 驱动，
   本轮以契约测试固定其行为（过渡期控件禁用、降级提示文案、标记重点计数）。
4. 工作区应用 Calm Focus 视觉，1080×720（宽 / Row 布局）与 680×720（窄 / Column
   布局，<760px）、light/dark 无溢出。

## 2. 文件白名单

- `lib/ui/recording/meeting_workspace.dart`（新增 `realtimeSupported` 参数与
  `_LocalOnlyPanel`；透明渲染 controls/transcript/notice）
- `lib/ui/recording/recording_screen.dart`（`_stopMeeting` 增加结束二次确认；
  向 `MeetingWorkspace` 传入 `realtimeSupported`）
- `test/recording_workspace_widget_test.dart`（可新增：R-09 提示、结束确认、
  暂停/继续/重点/降级/过渡态禁用）
- `test/loop5_visual_test.dart`（可新增：工作区 1080×720/880×600 light/dark 视觉冒烟）
- `docs/architecture/loop-5-contract.md`、`loop-5-review.md`（首席文档）
- `docs/acceptance/loop-5-acceptance.md`（证据）

不改动：会话/录音核心、持久化、处理、回收、托盘、原生音频、business provider
数据语义。只改工作区呈现层与结束确认 UI。

### 4.2 视觉冒烟测试授权

`test/loop5_visual_test.dart` 以 1080×720 与 680×720 确定性渲染真实
`MeetingWorkspace`（with/without realtime，light/dark × 扩展/紧凑两种宽度）。像素级 golden
通过 `EM_GEN_GOLDENS=1` 门控；默认 CI 路径为确定性冒烟断言（无渲染异常、关键控件
存在）。golden PNG 产出在 `test/goldens/recording-workspace/`，属仓库外证据（不提交），
其 SHA-256 录入 `loop-5-review.md`。

## 3. 现状核对

| 项 | 数据源 | 现状 |
|---|---|---|
| 状态机 | `meetingSessionProvider.state.capturePhase` | ✅ 已接 |
| 暂停/继续 | `session.pauseRecording / resumeRecording` | ✅ 已接 |
| 重点标记 | `session.markHighlight` | ✅ 已接（计数） |
| 断网降级 | `recording.degradationReason` + `live.phase` | ✅ 已接 |
| 结束录音 | `session.stopRecording`（安全归档） | ➕ 本轮加二次确认 |
| 平台差异（R-09）| `platformProfileProvider.supportsRealtimePcm` | ➕ 本轮新增 |

## 4. 设计

### 4.1 R-09：按能力渲染

`MeetingWorkspace` 新增 `required bool realtimeSupported`。当 `false`：
- 宽布局（≥760px）与窄布局都把 `LiveTranscriptPanel` 替换为 `_LocalOnlyPanel`：
  一个 Card，图标 `Icons.subtitles_off_outlined`，文案"当前平台无法实时转写 /
  录音仍正常保存到本地，可在录音结束后生成转写与纪要"。控件面板（电平、暂停、
  重点、结束）不变。
- 不渲染"实时文字"标题、连接状态或空态等待文案。

### 4.2 安全结束二次确认

`RecordingScreen._stopMeeting` 先 `showDialog` 确认（标题"结束录音？"，正文说明
录音会安全保存、不会自动生成纪要，按钮"继续录音 / 结束录音"）。取消直接返回；
确认才 `_run(session.stopRecording)`。`MeetingWorkspace` 保持纯展示，`onStop` 仍
由父级传入。

## 5. 精确验收

- R-09：`realtimeSupported: false` 时工作区不显示"实时文字"面板，显示本地录音提示。
- 结束录音：点击弹确认；取消不停止；确认才停止（会话级 `stopRecording`）。
- 暂停/继续/重点/降级由真实 provider 驱动；过渡期控件禁用。
- 全量 format/analyze/test 通过。
- Windows Release 与 macOS Release exact-commit CI 成功。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。