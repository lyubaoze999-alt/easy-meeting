# EasyMeeting Loop 7 内部评审

状态：APPROVE
评审人：实现者（独立内部评审）
评审基线与范围：`docs/architecture/loop-7-contract.md`

## 1. 本轮改动

| 文件 | 变更 |
|---|---|
| `lib/ui/library/meeting_detail_screen.dart` | 详情默认标签：有可用纪要时落在"纪要"（index 2），否则"录音"（index 0）；`_RecordingTab` 移除假 Slider/假播放态，改为"使用系统播放器播放"主按钮（R-03 明确外部打开交互） |
| `lib/ui/library/meeting_library_screen.dart` | 详情按 `ValueKey(meeting.id)` 键控，切换选择时 `DefaultTabController` 重新初始化为该会议的默认标签 |
| `test/meeting_detail_screen_test.dart` | 适配默认纪要标签；播放断言改为"使用系统播放器播放"；新增默认纪要/回退录音两测试 |
| `test/loop7_visual_test.dart`（新增） | 详情页 1080×720 / 880×600、light/dark 冒烟 |
| `docs/architecture/loop-7-contract.md`、`loop-7-review.md` | 本轮合同 + 评审 |

## 2. 需求符合性

- **默认纪要（R-03 配套）**：`effectiveNoteStatus == ready && note != null → initialIndex 2`，
  否则 0。`meeting_library_screen` 以 `ValueKey(meeting.id)` 键控详情，选择切换时标签
  重置为该会议默认。测试覆盖默认纪要与回退录音。
- **播放器能力真实（R-03）**：移除从未接线的 Slider/`isPlaying`/`playbackPosition` 假控件，
  替换为 `FilledButton.icon` "使用系统播放器播放"，`onPressed` 仍调用 `onPlayRecording`
  → connected screen `Process.run('open'/'cmd start')` 真实经系统默认播放器播放该 WAV。
  R-03 允许"实现播放器，或改成明确的外部打开交互"，本实现取后者并经测试。
- **独立删除 + 缺失/损坏状态 + 删除提示回归**：三资产独立删除、确认对话框、缺失/损坏
  状态均由详情报文与 R-04 投影驱动，回归测试通过。
- **导出回归**：WAV 导出与 Markdown 导出入口保留。

## 3. 透明化决策

未引入新的原生音频播放依赖（`audioplayers`/`just_audio`）。理由：① 改动平台插件图，
与"GeneratedPluginRegistrant 仅在平台依赖图有意变更时提交"约束冲突；② 真机音频验收仍由
Loop 9/10 门禁。R-03 明确允许外部打开交互，故采用该合规路径。若后续产品要求内嵌播放器，
可在 Loop 9/10 真机验收阶段评估原生依赖。

## 4. 发现

### P1（无）
### P2（无）
### P3（接受）

- **P3-1 切换会议重置标签**：选择切换会重置到默认标签（有纪要→纪要，无→录音）。属
  设计意图；若用户想在两个会议间保持同一标签，可后续以"记住上次标签"增强。接受。
- **P3-2 真机播放未门禁**：系统播放器在 CI 无法验证（无 GUI 音频）。真机播放验收归入
  Loop 9/10。接受。

## 5. 客观证据

- `flutter analyze`：No issues found。
- `dart format --set-exit-if-changed`：全部通过。
- `flutter test`：183 passed（含 Loop 7 的 2 个默认标签测试 + 4 个视觉冒烟）。
- 视觉 golden（`EM_GEN_GOLDENS=1 --update-goldens`）SHA-256（仓库外证据）：
  - `test/goldens/detail/extended-light.png`  `8030d131bda5e1b7be818265aaf3ec684d3387b0c5dc9d36e56bb1b59d6debc4`
  - `test/goldens/detail/extended-dark.png`   `bb13d2d473804c4c64b3c9adda8ba40ac0582a8e4aad53ceb9fc244d3d780fc0`
  - `test/goldens/detail/narrow-light.png`    `d91fbda217c2c6812ea3e78f9bd73e2be1844dadf789aad9b60a23d809ea2e58`
  - `test/goldens/detail/narrow-dark.png`     `e756122dece785b2fcfdb31c69843f715b940fc30a0383a63c34def6c14af768`

## 6. 结论

需求全部满足，测试全绿，视觉无溢出。播放改为明确外部打开（R-03 合规路径），默认纪要
标签落地。未破坏既有 API。APPROVE。

`OVERALL_LOOP7_REVIEW = APPROVE`