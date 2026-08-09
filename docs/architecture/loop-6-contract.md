# EasyMeeting Loop 6 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、`loop-5-contract.md`、
`loop-5-acceptance.md`、Loop 5 exact-commit `OVERALL_LOOP5=APPROVED`。

## 1. 本轮目标

会议库、搜索与资产状态投影：

1. **250ms 搜索防抖（R-10）**：会议库搜索框输入不立即触发 `load`，而是 250ms 防抖后
   再查询；避免每次按键都全量重算 bundle。
2. **转写正文可搜索（R-10）**：搜索词同时匹配 会议模板 / 纪要标题 / 纪要正文 与
   **正式转写正文**（`transcript.bodyPath` 文件内容）。当前 `meeting_repository.list`
   只匹配模板与纪要，不覆盖转写正文。
3. **资产状态投影（R-04）**：会议库列表的 录音（缺失/损坏/可播放）、纪要
   （未生成/处理中/已完成/失败）、转写（就绪/待修复/处理中/失败）由 **真实文件与
   Job** 驱动，而非默认乐观状态。`MeetingLibraryController.load` 计算并透传到
   `MeetingLibraryItem`，使列表与详情一致。
4. 会议库应用 Calm Focus 视觉，1080×720 与 880×600、light/dark 无溢出。

## 2. 文件白名单

- `lib/app_services/providers.dart`（`MeetingLibraryController.load`：读取转写正文、
  计算录音/纪要真实状态；`MeetingAssetBundle` 增加状态字段）
- `lib/ui/library/connected_meeting_library_screen.dart`（转 ConsumerStatefulWidget，
  搜索 250ms 防抖；把投影状态透传给 `MeetingLibraryItem`）
- `lib/ui/library/meeting_library_screen.dart`（如需，接收投影状态参数）
- `lib/infrastructure/repositories/meeting_repository.dart`（如需，转写正文检索）
- `test/library_search_test.dart`（可新增：防抖、正文可搜、状态投影）
- `test/loop6_visual_test.dart`（可新增：会议库 1080×720/880×600 light/dark 视觉冒烟）
- `docs/architecture/loop-6-contract.md`、`loop-6-review.md`（首席文档）
- `docs/acceptance/loop-6-acceptance.md`（证据）

不改动：会话/录音核心、持久化、处理队列、回收、托盘、原生音频。只改会议库呈现层、
搜索防抖与状态投影。

### 4.2 视觉冒烟测试授权

`test/loop6_visual_test.dart` 以 1080×720 与 880×600 确定性渲染真实会议库
（含多种资产状态 bundle）。像素级 golden 通过 `EM_GEN_GOLDENS=1` 门控；默认 CI 路径
为确定性冒烟断言。golden PNG 产出在 `test/goldens/library/`，属仓库外证据（不提交），
其 SHA-256 录入 `loop-6-review.md`。

## 3. 现状核对

| 项 | 现状 | 本轮 |
|---|---|---|
| 会议库列表 | `meetingLibraryProvider` 双栏/列表 | ✅ 已接 |
| 搜索 | 无防抖，每次按键即 `load` | ➕ 250ms 防抖 |
| 转写正文检索 | 不匹配 | ➕ 覆盖 bodyPath 文本 |
| 录音状态 | `recordingStatus` 未传 → 默认 playable/missing | ➕ 真实文件投影（damaged） |
| 纪要状态 | `noteStatus` 未传 → 默认 ready/notGenerated | ➕ 由 Job 投影（processing/failed） |
| 转写状态 | `transcript.status` 已驱动列表 chip | ✅ 已接 |

## 4. 设计

### 4.1 搜索防抖

`ConnectedMeetingLibraryScreen` 转 `ConsumerStatefulWidget`，持有 `Timer? _searchDebounce`。
文本框 onChanged → 取消旧 Timer → 250ms 后 `load(query)`。`dispose` 取消 Timer。

### 4.2 转写正文可搜索

`MeetingLibraryController.load(query)`：先按现有 `meetings.list(query)` 得到候选会议，
再将每个 bundle 的 `transcriptText`（已从 bodyPath 读取）与查询词匹配；匹配的会议排序
靠前。保证"只在转写正文出现的词"能命中对应会议。

### 4.3 资产状态投影

- 录音：`recording == null → missing`；`recording != null` 但
  `File(recording.path)` 不存在或为空 → `damaged`；否则 `playable`。
- 纪要：`note == null → notGenerated`；有 `noteSummary` Job 且 `stage == failed` →
  `failed`；有活跃 Job（`done` 之外）→ `processing`；有 note → `ready`。
- 转写：沿用 `transcript.status`（ready/needsRepair/failed/processing）。

## 5. 精确验收

- 搜索输入 250ms 防抖后才触发 `load`（防抖测试）。
- 只在转写正文出现的词能搜到对应会议（正文可搜测试）。
- 录音文件缺失 → 列表显示"损坏/缺失"；纪要 Job failed → "失败"；处理中 → "处理中"
  （状态投影测试，由真实文件/Job 驱动）。
- 全量 format/analyze/test 通过。
- Windows Release 与 macOS Release exact-commit CI 成功。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。