# EasyMeeting Loop 9 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、Loop 8 exact-commit
`OVERALL_LOOP8=APPROVED`。

## 1. 本轮目标

macOS native 硬化。在发包前把 macOS 录音链路中可被无真机 CI 验证的、以及必须
上报到 UI 的缺陷收口：

1. **R-05 写盘失败可见（P1）**：原生 `write(_:)` 写盘异常过去只把 `writing` 置
   false ➜ 静默截断。本轮把写盘失败通过 `writeError` 事件上报到 Dart，经
   `RecordingCoordinator` 暴露为粘性 `writeErrorMessage`，并在录音工作区渲染
   常驻错误横幅，让用户明确知道「录音已停止保存」。这是 Loop 9 唯一必须改产品
   代码的项。
2. **原生逻辑单元测试（R-08 可验证部分）**：把 `MacOSAudioCapture.swift` 中
   不依赖 AVFoundation 的纯逻辑（`MacAudioError` 分类与文案、`AudioRingBuffer`
   环形缓冲、`AudioMeter.rms` 电平、`SilenceDetector` 静音迟滞）抽取到
   `MacAudioLogic.swift`，新增 `swiftc` 独立可执行测试并在 CI macOS job 中运行，
   与既有 `PCMFramePumpTests` 平级。这覆盖「静音检测、设备异常分类、电平」在无
   真机麦克风权限下的验证。
3. **真机验收清单（BLOCKED on hardware）**：13.x mic-only、14.4+ dual、睡眠/恢复、
   设备切换、45 分钟长录、暂停守恒、签名候选包均需物理 Mac 真机验收。本环境为
   Windows CI 主机，无法执行，按基线 §7 规则如实标记 `BLOCKED`，不得以另一平台
   推断通过。清单维护在 `docs/acceptance/desktop-checklist.md`。
4. **macOS Release + unsigned DMG 候选（CI）**：确认 exact-commit 的 Shared
   quality 与 Platform builds（含 macOS Release 构建与 DMG 产出）成功。

## 2. 文件白名单

- `packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacAudioLogic.swift`（新增）
- `packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacOSAudioCapture.swift`（去重 + writeError）
- `packages/audio_capture/macos/audio_capture/Tests/MacAudioLogicTests/main.swift`（新增）
- `packages/audio_capture/lib/audio_capture.dart`（新增 `writeError` 流）
- `lib/app_services/recording_coordinator.dart`（监听 `writeError`，暴露 `writeErrorMessage`）
- `lib/ui/recording/meeting_workspace.dart`（错误横幅）
- `lib/ui/recording/recording_screen.dart`（透传 `writeErrorMessage`）
- `test/recording_coordinator_test.dart`、`test/recording_workspace_widget_test.dart`（R-05 测试）
- `.github/workflows/platform-builds.yml`（macOS job 增加 MacAudioLogic swiftc 测试）
- `docs/architecture/loop-9-contract.md`、`loop-9-review.md`
- `docs/acceptance/loop-9-acceptance.md`、`docs/acceptance/desktop-checklist.md`

不改动：会议/转写/纪要业务逻辑、持久化 schema、Windows 原生、Windows PCM。

## 3. 现状核对

| 项 | 现状 | 本轮 |
|---|---|---|
| 写盘失败上报 | 静默 `writing=false` | ➕ `writeError` 事件 → 粘性横幅 |
| 静音/电平/环形缓冲/错误分类 | 藏在私有类型，无 CI 测试 | ➕ 抽取 + swiftc 测试 |
| 13.x mic-only / 14.4+ dual | 代码已实现 | 真机 BLOCKED |
| 睡眠/设备切换/45 分钟/暂停守恒 | 无真机证据 | 真机 BLOCKED |
| macOS Release + DMG | CI 已产出 | exact-commit 复核 |

## 4. 设计

### 4.1 R-05 写盘失败上报链

`MacOSAudioCapture.write(_:)` catch 分支：
```swift
} catch {
  writing = false
  onEvent?("writeError", error.localizedDescription)
}
```
`AudioCapturePlugin` 已把所有 `onEvent` 转发到 `audio_capture/events` 通道，
无需改动。Dart 侧在 `AudioCapture` 新增：
```dart
Stream<String> get writeError => _platform.events
    .where((event) => event['type'] == 'writeError')
    .map((event) => event['value'] as String? ?? '录音写入失败');
```
`RecordingCoordinator` 构造函数订阅并把消息存为粘性字段（`reset()` 清除）；
`MeetingWorkspace` 在 `writeErrorMessage != null` 时于内容上方渲染常驻错误横幅
（保留结束录音等控制，方便用户及时收尾）。

### 4.2 原生纯逻辑抽取与测试

`MacAudioLogic.swift` 只 import Foundation（不引 AVFoundation），承载
`MacAudioError`、`AudioRingBuffer`、`AudioMeter.rms`、`SilenceDetector`。
`MacOSAudioCapture.swift` 删除同名私有定义，麦克风电平改为读取
`floatChannelData` 后调用 `AudioMeter.rms`。
`Tests/MacAudioLogicTests/main.swift` 用与 `PCMFramePumpTests` 相同的
`swiftc` 独立可执行模式验证：错误文案、环形缓冲出入序/溢出去旧/复位、RMS 电平、
静音迟滞（2.5s）、降级文案决策。CI macOS job 增加一步编译并运行它。

## 5. 精确验收

- 原生写盘失败触发 `writeError` 事件（代码 + 评审）。
- `RecordingCoordinator.writeErrorMessage` 事件到达后置位、粘性、`reset()` 清除（测试）。
- 工作区 `writeErrorMessage` 非空时渲染「录音写入失败，已停止保存：…」横幅，且
  结束录音仍可点（测试）；为空时不渲染（测试）。
- `swiftc` 编译并运行 `MacAudioLogicTests` 通过（CI）。
- 全量 format/analyze/test 通过（含 audio_capture 包）。
- macOS Release + unsigned DMG candidate 构建成功（exact-commit CI）。
- 真机项（13.x/14.4/睡眠/设备切换/45 分钟/暂停守恒/签名候选包）如实 BLOCKED 于
  `desktop-checklist.md`，不伪造通过。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。