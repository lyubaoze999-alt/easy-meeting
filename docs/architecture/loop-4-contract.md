# EasyMeeting Loop 4 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、`loop-3-contract.md`、
`loop-3-acceptance.md`、Loop 3 exact-commit `OVERALL_LOOP3=APPROVED`。

## 1. 本轮目标

录音准备、恢复与最近会议：

1. 录音准备页（`RecordingScreen._PreparationPanel`）的模板、实时能力、降级与
   孤儿录音均已由真实数据驱动（`NoteTemplate.builtins`、
   `platformProfileProvider`、`settingsProvider`、`recordingRecoveryProvider`）。
2. **新增"最近会议"区**：由 `meetingLibraryProvider` 真实数据驱动，展示最近会议
   及其真实资产状态（录音已保存 / 转写就绪 / 纪要就绪），点击跳转到会议库并预选
   该会议。
3. 双击开始只创建一场会议：会话层 `_beginCaptureCommand` 已在首个 await 前取锁，
   二次 `startMeeting` 抛 `StateError`；既有的 `double start takes the capture
   lock before the first await` 测试已覆盖，本轮回归确认。
4. 录音准备页应用 Calm Focus 视觉，1080×720 与 880×600、light/dark 无溢出。

## 2. 文件白名单

- `lib/app_services/providers.dart`（新增 `selectedMeetingIdProvider` 深链请求）
- `lib/ui/home_shell.dart`（监听深链请求切换到会议库 tab）
- `lib/ui/library/meeting_library_screen.dart`（`initialMeetingId` 预选参数）
- `lib/ui/library/connected_meeting_library_screen.dart`（透传预选 id）
- `lib/ui/recording/recording_screen.dart`（最近会议区 + Calm Focus 视觉）
- `test/recording_prep_test.dart`（可新增：最近会议渲染/深链、准备页真实数据）
- `test/loop4_visual_test.dart`（可新增：准备页 1080×720/880×600 light/dark 视觉冒烟）
- `docs/architecture/loop-4-contract.md`、`loop-4-review.md`（首席文档）
- `docs/acceptance/loop-4-acceptance.md`（证据）

不改动：会话/录音核心、持久化、处理、回收、托盘、原生音频、business provider
数据语义。仅新增深链 provider 与 UI 接线。

### 4.2 视觉冒烟测试授权

`test/loop4_visual_test.dart` 以 1080×720 与 880×600 确定性渲染真实
`RecordingScreen` 准备态（light/dark × 两种宽度）。像素级 golden 通过
`EM_GEN_GOLDENS=1` 门控；默认 CI 路径为确定性冒烟断言（无渲染异常、开始按钮
存在）。golden PNG 产出在 `test/goldens/recording-prep/`，属仓库外证据（不提交），
其 SHA-256 录入 `loop-4-review.md`。复用 `TestAppServices` 夹具；服务在 `setUp`
（真实异步区）构建，避免 testWidgets FakeAsync 中的文件 I/O 挂起。

## 3. 真实数据驱动（现状核对）

| 项 | 数据源 | 现状 |
|---|---|---|
| 纪要模板 | `NoteTemplate.builtins` | ✅ 已接 |
| 实时能力提示 | `platformProfileProvider.supportsRealtimePcm` + `settings.realtimeTranscription` | ✅ 已接 |
| 降级提示 | 会话实时轴 phase | ✅ 已接（工作区） |
| 孤儿录音恢复 | `recordingRecoveryProvider.pending` | ✅ 已接 |
| 最近会议 | `meetingLibraryProvider`（新增） | ➕ 本轮新增 |

## 4. 最近会议设计

- 取 `meetingLibraryProvider` 数据中非回收、按 `startedAt` 降序的前 5 场。
- 每场展示 `meetingDisplayTitle`、日期、资产状态摘要（复用会议库的语义：
  有纪要→"纪要就绪"，仅转写→"转写就绪"，仅录音→"录音已保存"，无资产→"新会议"）。
- 点击：写入 `selectedMeetingIdProvider` → `HomeShell` 监听后切到会议库 tab →
  会议库通过 `initialMeetingId` 预选该会议 → 深链请求随即清空（可重复导航）。
- 空库时不显示该区。

## 5. 精确验收

- 准备页模板/实时/恢复均来自真实 provider；最近会议来自真实 meeting 数据。
- 点击最近会议跳转会议库并预选对应会议；再次点击同一会议仍可导航。
- 双击开始只创建一场会议（既有会话级测试回归通过）。
- 全量 format/analyze/test 通过。
- Windows Release 与 macOS Release exact-commit CI 成功。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。