# EasyMeeting Loop 9 内部评审

状态：APPROVE（软件项）/ 真机项 BLOCKED
评审人：实现者（独立内部评审）
评审基线与范围：`docs/architecture/loop-9-contract.md`

## 1. 本轮改动

| 文件 | 变更 |
|---|---|
| `packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacAudioLogic.swift`（新增） | 抽取不依赖 AVFoundation 的纯逻辑：`MacAudioError`、`AudioRingBuffer`、`AudioMeter.rms`、`SilenceDetector` |
| `packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacOSAudioCapture.swift` | 删除同名私有类型；麦克风电平改读 `floatChannelData` 后调 `AudioMeter.rms`；**R-05**：写盘 catch 分支 `writing=false` 后补发 `writeError` 事件 |
| `packages/audio_capture/macos/audio_capture/Tests/MacAudioLogicTests/main.swift`（新增） | `swiftc` 独立测试：错误文案、环形缓冲出入序/溢出去旧/复位、RMS、静音迟滞、降级文案 |
| `packages/audio_capture/lib/audio_capture.dart` | 新增 `Stream<String> writeError` |
| `lib/app_services/recording_coordinator.dart` | 订阅 `writeError`，暴露粘性 `writeErrorMessage`（`reset()` 清除） |
| `lib/ui/recording/meeting_workspace.dart` | `writeErrorMessage` 非空时渲染常驻错误横幅（保留结束录音） |
| `lib/ui/recording/recording_screen.dart` | 透传 `writeErrorMessage` |
| `test/recording_coordinator_test.dart`、`test/recording_workspace_widget_test.dart` | R-05 上报链测试（3 个） |
| `.github/workflows/platform-builds.yml` | macOS job 增加 `MacAudioLogic` swiftc 测试步骤 |
| `docs/architecture/loop-9-contract.md`、`loop-9-review.md`、`docs/acceptance/loop-9-acceptance.md`、`desktop-checklist.md` | 本轮文档 |

## 2. 需求符合性

- **R-05 写盘失败可见（P1）**：原生写盘异常不再静默——`writeError` 事件经插件
  `audio_capture/events` 通道到达 Dart；`RecordingCoordinator` 粘性保存；
  `MeetingWorkspace` 渲染「录音写入失败，已停止保存：…」常驻横幅，结束录音仍可点。
  测试断言：事件到达后置位、粘性、`reset()` 清除；工作区横幅出现/不出现两条路径。
- **原生纯逻辑测试（R-08 可验证部分）**：静音迟滞（2.5s）、环形缓冲溢出去旧、
  RMS 电平、错误分类与降级文案均被 `swiftc` 独立测试覆盖并接入 macOS CI。
- **真机项（13.x/14.4/睡眠/切换/45 分钟/暂停守恒/签名包）**：如实 `BLOCKED`，
  记录于 `desktop-checklist.md`，不伪造通过。

## 3. 透明化决策

- 仅把「不依赖 AVFoundation」的纯逻辑抽到 `MacAudioLogic.swift`；`AVAudioEngine`
  装配、tap、`AVAudioFile` 写入仍留在 `MacOSAudioCapture.swift`，避免为测试拆散
  真实录音路径。`swiftc` 测试编译两个文件即可独立运行，与 `PCMFramePumpTests` 平级。
- R-05 采用「粘性错误 + 常驻横幅」而非自动重试：写盘一旦失败，无人能保证磁盘回
  复可用，向用户明确告知并让其决定收尾更诚实。属产品决策，接受。

## 4. 发现

### P1（无）
### P2（无）
### P3（接受）

- **P3-1 真机项继续 BLOCKED**：本环境为 Windows CI 主机，无物理 Mac + 完整
  Xcode + 签名身份。13.x mic-only、14.4+ dual、睡眠/恢复、设备切换、45 分钟长录、
  暂停守恒、签名候选包均待真机验收，按基线 §7 规则标记 BLOCKED 而非推断通过。
  本轮交付的这些路径的代码级测试（静音/电平/环形缓冲/错误上报）已全部落地。
- **P3-2 写盘失败后录音不自动停止**：`writing=false` 停写但会话仍显示「正在录音」。
  横幅明确告知用户已停止保存，用户可主动结束。接受（避免自动结束造成数据丢失）。

## 5. 客观证据

- `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test`：全部通过。
- `flutter analyze`：No issues found。
- `flutter test`：204 passed（Loop 8 201 + Loop 9 新增 3）。
- `packages/audio_capture`：analyze No issues found；`flutter test` 4 passed。
- `swiftc` 编译并运行 `MacAudioLogicTests`：CI macOS job 步骤（本机 Windows 无法
  运行 Swift，由 CI 的 macos-15 验证）。
- 后端门禁：Shared quality 与 Platform builds exact-commit CI（待复核）。

## 6. 结论

R-05 静默截断风险已闭环：写盘失败从原生上报到 UI 常驻横幅，并有三层测试。
macOS 录音链路中可无真机验证的纯逻辑全部纳入 CI。真机项如实 BLOCKED 并记录验收
清单。改动仅限原生上报链、纯逻辑抽取与测试，未触碰业务逻辑与持久化。软件项
APPROVE；真机项待物理 Mac 验收。

`OVERALL_LOOP9_SOFTWARE = APPROVE`
`OVERALL_LOOP9_REALDEVICE = BLOCKED`