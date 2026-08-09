# EasyMeeting Loop 10 实施合同

状态：实施中

依赖：`docs/architecture/calm-focus-loop-baseline.md`、Loop 9 exact-commit
`OVERALL_LOOP9=APPROVED`（软件项）。

## 1. 本轮目标

Windows native、平台一致性与发布。收口 Windows 录音链路中可无真机验证的缺陷，
并如实记录真机/BLOCKED 项：

1. **R-07 双路同步漂移（P1）**：Windows `WriterLoop` 过去把一路 mic 块与一路
   system 块按 FIFO 下标直接混合，两路 WASAPI 时钟独立、样本/秒略有差异，长会
   议下相位漂移且一路被先耗尽。本轮新增纯 C++ `DriftMixer`「重构同步策略」：以
   mic 为输出时间轴、system 用累计样本比做运行比率重采样到 mic 时间轴，使两路
   始终时间对齐、漂移有界。新增独立 `drift_mixer_test.cpp`（纯 main+assert，
   与 macOS `swiftc` 测试同级）并接入 Windows CI，用 cl 编译运行。
2. **Windows native 逻辑接入 CI**：drift 测试在 `windows-2022` job 中经
   `vswhere` 找到 MSVC、`cl` 编译并运行，闭环「Windows native test 未进入 CI」。
3. **Windows 实时 PCM 差异（已批准）**：Windows 不注册 `audio_capture/pcm` 通道，
   实时转写不可用；Loop 5 已按 R-09 在录音页显示「当前平台无法实时转写」能力提示
   而非误导性空面板。本环境无 Windows + 真机双路采集，维持该已批准差异并书面记录。
4. **真机验收清单（BLOCKED on hardware）**：45 分钟双路同步真机证据、设备插拔/
   切换、MSIX 安装启动、睡眠/恢复均需物理 Windows 真机。本环境无 Windows 真机构建
   与音频设备，如实标记 `BLOCKED`，维护在 `desktop-checklist.md`。
5. **全回归签署**：全量 format/analyze/test 通过；exact-commit Shared quality 与
   Platform builds（含 macOS/Windows release、MSIX、新 drift 测试、MacAudioLogic
   swiftc 测试）成功。

## 2. 文件白名单

- `packages/audio_capture/windows/drift_mixer.h`（新增：纯 C++ 漂移校正混音器）
- `packages/audio_capture/windows/audio_capture_plugin.cpp`（WriterLoop 改用 DriftMixer）
- `packages/audio_capture/windows/test/drift_mixer_test.cpp`（新增：纯 main 断言测试）
- `.github/workflows/platform-builds.yml`（Windows job 增加 cl 编译并运行 drift 测试）
- `docs/architecture/loop-10-contract.md`、`loop-10-review.md`
- `docs/acceptance/loop-10-acceptance.md`、`docs/acceptance/desktop-checklist.md`

不改动：macOS 原生、会议/转写/纪要业务逻辑、持久化 schema、Windows PCM 通道
（维持已批准差异）。

## 3. 现状核对

| 项 | 现状 | 本轮 |
|---|---|---|
| 双路 FIFO 混音漂移 | `(mic+system)/2` 按块下标 | ➕ DriftMixer 时间轴重采样 |
| Windows 原生测试进 CI | 未接入 | ➕ drift 测试 cl 编译运行 |
| permissionStatus | 已真实读取注册表（Loop 3） | ✅ 不变 |
| Windows 实时 PCM | 未注册通道（已批准差异） | ✅ 书面记录 |
| 45 分钟/设备切换/MSIX 安装 | 无真机证据 | 真机 BLOCKED |

## 4. 设计

### 4.1 DriftMixer（R-07 重构同步策略）

`drift_mixer.h`：mic 拥有输出时间轴（每 mic 样本产出 1 个输出样本，会议时长由
mic 定义）；system 被重采样到该时间轴。维护：
- `carry_`：未消费的 system 样本缓冲；`carry_start_`：`carry_[0]` 的绝对样本下标。
- `system_total_` / `mic_total_`：两路累计样本数；每次调用前 `ratio = clamp(
  system_before/mic_before, 0.5, 2.0)`，启动阶段（任一路为 0）取 1:1。
- `system_cursor_`：已消费的 system 绝对小数值位置；每输出 1 个 mic 样本推进 ratio。

每 mic 样本取 `pos = round(system_cursor_)`，`local = pos - carry_start_`，若
`0 <= local < carry_.size()` 则与 `carry_[local]` 混合（`(mic+system)/2`），否则
mic-only（system 尚未到达对应时间点）。调用末尾按 `round(system_cursor_) -
carry_start_` 丢弃已消费的 system 样本。纯 C++、无 Windows/Flutter 依赖，可任意
主机编译测试。

### 4.2 插件接入

`WriterLoop` 每次弹出 1 块 mic 与当前已达的全部 system 块，交给 `drift_mixer_`
混合后写盘；`drift_mixer_` 在 `Start()` 重置。暂停仍按原语义丢弃两路样本（暂停不
落盘），恢复后漂移比率经累计样本快速收敛。

### 4.3 测试

`drift_mixer_test.cpp`（纯 main+assert）：首调用 1:1 对齐、system 空时 mic-only 且
时长守恒、system 滞后时输出仍为 mic 时长、长跑（约 1000 次 flush × 4800 样本，
模拟 45 分钟）下 system 持续跟得上且输出恒为 mic 时间轴、Reset 恢复干净状态。
Windows CI 用 `vswhere` 定位 MSVC，`cl /EHsc /std:c++17` 编译并运行。

## 5. 精确验收

- `DriftMixer` 输出恒为 mic 时长；system 滞后/超前时无崩溃、无负消费、无无界缓冲。
- 长跑漂移有界：system 累计消费 ≤ 已交付，输出长度 == mic 累计长度（测试）。
- `drift_mixer_test.cpp` 经 cl 编译并在 Windows CI 运行通过。
- 全量 format/analyze/test（Dart）通过；audio_capture 包 analyze/test 通过。
- exact-commit Shared quality 与 Platform builds（macOS/Windows release、MSIX、
  drift 测试、MacAudioLogic swiftc 测试）成功。
- 真机项（45 分钟/设备切换/MSIX 安装/睡眠）如实 BLOCKED 于 desktop-checklist.md。

## 6. 交接

开发输出：Changed files、Contract items、Commands/results、Visual、
Known risks、`READY_FOR_QA | BLOCKED`。QA 独立验证后 `APPROVE | CHANGES_REQUESTED | BLOCKED`。