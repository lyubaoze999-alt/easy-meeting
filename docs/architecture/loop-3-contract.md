# EasyMeeting Loop 3 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、`loop-2-contract.md`、
`loop-2-acceptance.md`、Loop 2 exact-commit `OVERALL_LOOP2=APPROVED`。

## 1. 本轮目标

权限引导与平台能力：

1. Windows `permissionStatus` 不得硬编码为已授权（R-06）；必须以真实探测结果
   反映麦克风与系统音频端点的可用性。
2. macOS 13（mic-only）/14.4+（dual）与 Windows 的权限、拒绝、打开设置、
   刷新状态在 UI 中准确表达。
3. `PermissionOnboardingScreen` 应用 Calm Focus 视觉与真实状态驱动力。
4. 新增测试覆盖权限状态映射与平台差异，阻止硬编码回归。

## 2. 文件白名单

- `packages/audio_capture/windows/audio_capture_plugin.cpp`（权限探测）
- `packages/audio_capture/windows/test/audio_capture_plugin_test.cpp`（更新测试）
- `lib/ui/onboarding/permission_onboarding_screen.dart`
- `test/permission_onboarding_test.dart`（可新增）
- `docs/architecture/loop-3-contract.md`、`loop-3-review.md`（首席文档）
- `docs/acceptance/loop-3-acceptance.md`（证据）

macOS 原生权限已真实（`AVCaptureDevice`/`CGPreflightScreenCaptureAccess`），本轮
不改 macOS 原生；如需求要求，仅记录证据。

## 3. Windows 权限探测设计

`permissionStatus` 改为真实探测：

- `CoInitializeEx` 后创建 `MMDeviceEnumerator`。
- 麦克风：尝试 `OpenSource(eCapture, eCommunications, loopback=false)`，成功则
  `microphoneGranted=true`。
- 系统音频：尝试 `OpenSource(eRender, eConsole, loopback=true)`，成功则
  `systemAudioGranted=true`。
- 失败/无设备/权限被系统隐私设置阻断均返回 `false`，绝不臆断 `true`。

原生测试更新为：断言返回 map 且两个字段为 bool（真实探测，不假设 true）；
端点不可用时为 false。此测试不进 CI（Windows native test 现状），以本地/真机为准。

## 4. Onboarding 状态映射

| 场景 | 表达 |
|---|---|
| 平台支持系统音频（macOS 14.4+/Windows） | 显示"系统声音" tile，以 `status.systemAudioGranted` 驱动 |
| 平台仅麦克风（macOS 13-14.3） | 显示说明卡片，不显示系统声音 tile |
| 已授权 | `已授权` chip |
| 未授权/拒绝 | `去授权` 按钮，点击 `openPermissionSettings` 后自动刷新 |
| 刷新 | `刷新权限状态` 立即重新探测 |

## 5. 精确验收

- Windows 原生不再返回无条件 `true`；探测反映真实端点。
- `permission_onboarding_test.dart` 覆盖：macOS dual / macOS micOnly / Windows
  三种 profile 的 tile 渲染与状态映射；刷新调用；拒绝态按钮。
- 全量 format/analyze/test 通过；audio_capture 独立 analyze/test 通过。
- Windows Release 与 macOS Release exact-commit CI 成功。
- real-device 探测（Windows 真机权限）记录真机或 `BLOCKED` 说明，不臆断。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。