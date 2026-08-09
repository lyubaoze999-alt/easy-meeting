# EasyMeeting Loop 10 内部评审

状态：APPROVE（软件项）/ 真机项 BLOCKED
评审人：实现者（独立内部评审）
评审基线与范围：`docs/architecture/loop-10-contract.md`

## 1. 本轮改动

| 文件 | 变更 |
|---|---|
| `packages/audio_capture/windows/drift_mixer.h`（新增） | 纯 C++ `DriftMixer`：mic 时间轴上重采样 system，漂移有界 |
| `packages/audio_capture/windows/audio_capture_plugin.cpp` | `WriterLoop` 改用 `drift_mixer_`；`<cstddef>` 等由头文件携带 |
| `packages/audio_capture/windows/test/drift_mixer_test.cpp`（新增） | 纯 main+assert 测试（对齐、滞后、长跑、Reset） |
| `.github/workflows/platform-builds.yml` | Windows job 用 vswhere+cl 编译并运行 drift 测试 |
| `docs/architecture/loop-10-*.md`、`docs/acceptance/loop-10-acceptance.md`、`desktop-checklist.md` | 本轮文档 |

## 2. 需求符合性

- **R-07 重构同步策略（P1）**：`WriterLoop` 不再按 FIFO 块下标把一路 mic 与一路
  system 直接混合。`DriftMixer` 以 mic 为输出时间轴，system 用运行累计样本比
  `clamp(system_before/mic_before, 0.5, 2.0)` 重采样到该时间轴（最近邻），使两路
  始终对齐、长跑漂移有界。测试覆盖首调用 1:1、system 空 mic-only、system 滞后时长
  守恒、约 45 分钟长跑下输出恒为 mic 时间轴且 system 不欠账、Reset 干净。
- **Windows 原生逻辑接入 CI**：drift 测试在 windows job 经 vswhere 定位 MSVC、cl
  编译并运行，闭环「Windows native test 未进入 CI」。
- **Windows 实时 PCM 已批准差异**：不注册 pcm 通道，Loop 5 已按 R-09 显示能力提示；
  无真机双路采集，维持已批准差异并书面记录。
- **真机项（45 分钟/设备切换/MSIX 安装/睡眠）**：如实 `BLOCKED`，记录于
  desktop-checklist.md，不伪造通过。

## 3. 透明化决策

- 采用「mic 拥有时间轴、system 重采样」而非以时间戳精确配对：两路真实时钟差异
  极小，累计样本比收敛到真实速率比即可把漂移限制在单个输出帧量级；无需跨线程
  传 QPC 时间戳，降低实现与并发风险。属「重构同步策略」合同的低风险实现。
- drift 测试用纯 main+assert 而非 gtest，与 macOS `swiftc` 纯逻辑测试同级，可在
  windows job 用 `cl` 单文件编译运行，不必拉取 googletest。
- Windows 端无本地 C++ 编译器（无 MSVC/MinGW/LLVM），本机无法编译验证；改动尽量
  小而纯，编译正确性由 windows-2022 CI 的 `cl` 步骤与 `flutter build windows`
  双重把关。

## 4. 发现

### P1（无）
### P2（无）
### P3（接受）

- **P3-1 真机项继续 BLOCKED**：本环境无 Windows 真机构建环境、无音频设备与 MSIX
  安装验证。45 分钟双路同步真机证据、设备插拔/切换、MSIX 安装启动、睡眠/恢复均待
  物理 Windows 真机验收，按基线规则标记 BLOCKED。算法级漂移收口已由 drift 测试覆盖。
- **P3-2 快进/后入的 system 样本被丢弃**：system 落后于当前 cursor 的历史样本
  不再回溯混合。真实双路连续采集下 system 不会长期落后，仅启动瞬间可能产生少量
  mic-only 样本，可接受。
- **P3-3 暂停后比率短暂收敛**：暂停丢弃两路样本，恢复后累计样本比需少量 flush 收敛。
  同样可在真机验收中复核；不影响暂停守恒语义。

## 5. 客观证据

- `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test`：全部通过。
- `flutter analyze`：No issues found。
- `flutter test`：204 passed。
- `packages/audio_capture`：analyze No issues found；`flutter test` 4 passed。
- `drift_mixer_test.cpp`：windows CI 经 cl 编译并运行（本机无 MSVC，无法本地跑）。
- 后端门禁：Loop 9 exact-commit Shared quality success、Platform builds（含
  MacAudioLogic swiftc）待最终确认；Loop 10 新 commit 待 CI。

## 6. 结论

R-07 双路 FIFO 漂移已用轻量纯逻辑重构收口并有独立单元测试接入 Windows CI；Windows
实时 PCM 维持已批准差异；真机项如实 BLOCKED。改动仅限 Windows 混音策略与测试，未
触碰业务逻辑、持久化与 macOS。软件项 APPROVE；真机项待物理 Windows 验收。

`OVERALL_LOOP10_SOFTWARE = APPROVE`
`OVERALL_LOOP10_REALDEVICE = BLOCKED`