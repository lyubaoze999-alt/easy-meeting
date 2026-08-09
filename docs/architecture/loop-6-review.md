# EasyMeeting Loop 6 内部评审

状态：APPROVE
评审人：实现者（独立内部评审）
评审基线与范围：`docs/architecture/loop-6-contract.md`

## 1. 本轮改动

| 文件 | 变更 |
|---|---|
| `lib/app_services/providers.dart` | `MeetingLibraryController.load` 改为全量加载后 Dart 过滤；新增 `_projectRecordingStatus`/`_projectNoteStatus`/`_matchesQuery`；`MeetingAssetBundle` 增加 `recordingStatus`/`noteStatus` |
| `lib/ui/library/connected_meeting_library_screen.dart` | 转 `ConsumerStatefulWidget`，250ms 搜索防抖；透传投影状态到 `MeetingLibraryItem` |
| `lib/ui/library/meeting_detail_screen.dart` | 枚举改由 `asset_status.dart` 定义并在此 re-export（保持既有 import 兼容） |
| `lib/domain/models/asset_status.dart`（新增） | `RecordingDisplayStatus` / `MeetingNoteDisplayStatus` 领域枚举 |
| `lib/ui/library/meeting_library_screen.dart` | `MeetingLibraryItem` 支持投影状态；`effective*Status` 兜底 |
| `test/library_loop6_test.dart`（新增） | 正文可搜、录音三态、纪要四态、250ms 防抖 |
| `test/loop6_visual_test.dart`（新增） | 会议库 1080×720 / 880×600、light/dark 视觉冒烟 |
| `.gitignore` | 忽略 `test/goldens/`、`test/screenshot/`、`ci_monitor.js`（生成证据，不入库） |

## 2. 需求符合性

- **R-10 转写正文可搜索**：`_matchesQuery` 将会议模板、纪要（标题+章节）、转写正文
  拼入搜索缓冲；`load` 全量加载后在 Dart 过滤，保证"只在转写正文出现的词"也能命中。
  测试 `library search matches the formal transcript body text` 覆盖。
- **R-10 250ms 防抖**：`_onSearchChanged` 取消旧 Timer，250ms 后才是 `load(query)`；
  `dispose` 取消 Timer。测试 `library search box debounces for 250ms` 覆盖（100ms 未过滤、
  250ms 后仅剩命中项）。
- **R-04 资产状态投影**：录音由真实文件（`File.exists`/`length<=0`）→ missing/damaged/
  playable；纪要由 noteSummary Job（failed 优先、active=processing、无 note=notGenerated）
  → notGenerated/processing/failed/ready。`_projectNoteStatus` 按 `meetingId`+`jobType` 作用域
  隔离，测试以 `m-scope` 的失败 Job 证明不泄漏到 `m-processing`。
- 会议库 Calm Focus 视觉：extended/narrow、light/dark 冒烟无溢出（`takeException` 为 null）。

## 3. 发现

### P1（无）
### P2（无）
### P3（接受）

- **P3-1 全量加载成本**：`load` 改为总是 `meetings.list()` + `notes.list()` + 读取每个
  transcript body。会议数极多时一次性读取所有转写正文。属可接受（本机本地、会议库规模有限、
  由 250ms 防抖对冲频繁触发）。记入下一轮优化清单。
- **P3-2 `_matchesQuery` 全文 contains**：非分词、大小写不敏感、中文无空格也可命中。
  语义足够（本地搜索预期模糊命中）。接受。

## 4. 客观证据

- `flutter analyze`：No issues found。
- `flutter test`：177 passed（含 Loop 6 的 4 个功能测试 + 4 个视觉冒烟）。
- 视觉 golden（`EM_GEN_GOLDENS=1 --update-goldens`）SHA-256（仓库外证据）：
  - `test/goldens/library/extended-dark.png`  `74defd386afbdebf843bd20507cb8d15551f6a917b53beec5d15de8aba9fb7fd`
  - `test/goldens/library/extended-light.png` `3b86bf02f81f2304e3dbff530cf61733e0723c1482597ef2833391f29592eda3`
  - `test/goldens/library/narrow-dark.png`   `878516feb5b540fc4ae2c9a9821fec7cc7ef6c1b375c75a039dcdace21bdcefc`
  - `test/goldens/library/narrow-light.png`  `d5aee88a54c95e72e806b07417672b2c76cc39d427ecf65238e107d316087f1b`

## 5. 结论

需求全部满足，测试全绿，视觉无溢出。未引入新依赖、未改持久化/录音/处理核心。APPROVE。

`OVERALL_LOOP6_REVIEW = APPROVE`