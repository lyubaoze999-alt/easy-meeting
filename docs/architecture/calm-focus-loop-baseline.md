# EasyMeeting Calm Focus 重构技术基线

状态：Loop 0 已审计，等待 Loop 1 实施

基线分支：`agent/macos-deliverable`

基线提交：`77bbcbc`

审计日期：2026-08-07

## 1. 目标与完成口径

本项目目标是在保留现有真实功能、数据兼容性和本地优先原则的前提下，将桌面 UI 替换为 Calm Focus 视觉体系，并把 macOS、Windows 做到可安装、可验证、可交付。

当前不能判定为“两端完成”：两端 Release 构建和 unsigned 安装包已经由 CI 产出，但真机音频、长会议、权限、设备异常和安装体验仍未验收。自动化构建证据见 `.github/workflows/platform-builds.yml:32-54,72-125`；未完成的真机项目见 `docs/acceptance/desktop-checklist.md:20-53`。

最终完成必须同时满足：

- Calm Focus 覆盖约定的所有桌面页面及完整交互状态。
- 不出现日历、说话人识别、AI 问答、协作分享等未实现入口。
- 旧会议、录音、转写、纪要和回收站数据保持兼容。
- macOS 与 Windows 均完成安装、核心流程和原生音频真机验收。
- 无 P0/P1；获准保留的 P2 有负责人、期限和回归范围。
- GLM 开发证据、QA 独立验证和开发首席审核三方齐全。

## 2. 架构基线

现有共享业务层可以保留，不进行推倒重写：

- `lib/main.dart:14-37`：建立桌面窗口、创建服务容器、恢复后台任务并初始化托盘。
- `lib/app_services/app_services.dart:71-168`：装配 drift 仓库、设置、录音、实时转写、后处理、资产生命周期与恢复服务。
- `lib/app_services/providers.dart:15-42,112-169`：Riverpod 暴露会话、设置、会议库和回收站状态。
- `lib/app_services/meeting_session_state.dart:3-40,53-74`：本地录音、实时转写和后处理为三个相互独立的状态轴。
- `lib/app_services/persistent_meeting_capture.dart:14-90`：先持久化会议草稿，再开始原生录音；WAV 归档成功后才将会议标为 recorded。
- `lib/infrastructure/database/app_database.dart:39-169`：会议、录音、转写、转写段和纪要独立存储；当前 schema v2。
- `lib/app_services/post_processing_queue.dart:42-45,136-211`：正式转写和纪要使用持久化串行队列，不隐式串联。
- `lib/app_services/meeting_asset_lifecycle.dart:49-94`：会议级 30 天回收站和永久删除路径校验。
- `lib/app_services/recording_recovery_service.dart:41-102`：未归档 WAV 只能经用户明确选择后归档或删除。

保留但需要后续清理的技术债：

- 新 `PostProcessingQueue` 与旧 `ProcessingPipeline` 仍同时装配；产品路径使用新队列，旧对象只保留兼容行为，见 `lib/app_services/app_services.dart:102-138` 和 `lib/app_services/meeting_session_controller.dart:203-212`。
- `lib/ui/library/notes_library_screen.dart` 是未接入 `HomeShell` 的旧会议库界面；正式入口是 `ConnectedMeetingLibraryScreen`，见 `lib/ui/home_shell.dart:35-40`。
- `recording_screen.dart` 和 `meeting_detail_screen.dart` 体积过大；后续视觉重构需抽组件，但不得改变业务所有权。

## 3. 真实功能矩阵

| 能力 | 当前状态 | 真实边界 | 代码证据 |
|---|---|---|---|
| 内置纪要模板 | 已实现 | 默认、站会、评审、面试；没有用户模板管理 | `lib/domain/models/note_template.dart:28-53` |
| 录音准备 | 已实现 | 选择本场模板、可选实时文字、处理未归档 WAV | `lib/ui/recording/recording_screen.dart:323-500` |
| 本地录音 | 已实现 | 麦克风必需；系统声音失败时允许降级 | `lib/app_services/recording_coordinator.dart:89-166` |
| 暂停/继续/结束 | 已实现 | 过渡期间控制禁用 | `lib/ui/recording/meeting_workspace.dart:153-169` |
| 重点标记 | 已实现 | 记录时间点，不是书签编辑器 | `lib/ui/recording/meeting_workspace.dart:153-157` |
| 双路音量 | 已实现接口 | 表示即时电平，不是可回溯波形 | `packages/audio_capture/lib/audio_capture.dart:50-53` |
| 实时转写 | 部分实现 | 当前仅 macOS 暴露实时 PCM；Windows 录后转写 | `lib/domain/models/platform_profile.dart:21-22` |
| 断线降级 | 已实现 | 实时失败不应中断本地录音 | `lib/app_services/meeting_session_controller.dart:449-477` |
| 安全归档 | 已实现 | 原生停止、WAV 校验和数据库归档完成后才 recorded | `lib/app_services/persistent_meeting_capture.dart:69-90` |
| 正式转写 | 已实现 | 生成、补全、重试、重新转写；依赖用户 API 配置 | `lib/ui/library/meeting_detail_screen.dart:580-595` |
| 结构化纪要 | 已实现 | 只读分区、待办、时间线、思维导图、关键数字 | `lib/ui/library/meeting_detail_screen.dart:688-823` |
| 待办 | 部分实现 | 可显示负责人/截止日期；复选框只读 | `lib/ui/library/meeting_detail_screen.dart:722-770` |
| 会议库 | 已实现 | ≥840px 列表/详情双栏 | `lib/ui/library/meeting_library_screen.dart:129-157` |
| 独立资产生命周期 | 已实现 | 录音、转写、纪要可分别删除/恢复 | `lib/ui/library/meeting_detail_screen.dart:151-230` |
| 回收站 | 已实现 | 单项和整场会议恢复/永久删除，30 天清理 | `lib/ui/trash/trash_screen.dart:81-220` |
| 搜索 | 部分实现 | 当前无 debounce，且未直接索引正式转写正文 | `lib/ui/library/meeting_library_screen.dart:268-275`; `lib/infrastructure/repositories/meeting_repository.dart:132-157` |
| 录音播放 | 部分实现 | 实际调用系统默认播放器；内嵌 Slider/播放状态未接线 | `lib/ui/library/connected_meeting_library_screen.dart:101-113`; `lib/ui/library/meeting_detail_screen.dart:385-408` |
| API 与隐私设置 | 已实现 | 三类服务配置；密钥使用系统安全存储 | `lib/ui/settings/settings_screen.dart:118-174`; `lib/infrastructure/settings/settings_store.dart:22-55` |
| 导出 | 已实现 | WAV、Markdown、隐私安全诊断 ZIP | `lib/ui/library/connected_meeting_library_screen.dart:131-160`; `lib/ui/settings/settings_screen.dart:362-375` |
| 桌面托盘 | 已实现但有错误文案 | 关闭窗口隐藏到托盘；停止录音不会自动生成纪要 | `lib/desktop/desktop_tray_controller.dart:19-31,48-74,128-131` |

明确不在本轮项目范围：日历、参与者/联系人、说话人识别、视频、AI 问答、云协作分享、待办编辑。除非产品负责人另立需求，不得把这些能力加入设计或代码。

## 4. 平台完成度

### 4.1 macOS

已有：

- deployment target 为 macOS 13.0：`macos/Runner.xcodeproj/project.pbxproj:556,606`。
- 麦克风与系统音频权限说明：`macos/Runner/Info.plist:31-34`。
- Release sandbox、网络、音频输入和用户选择文件 entitlement：`macos/Runner/Release.entitlements:5-12`。
- macOS 14.4+ Core Audio Process Tap：`packages/audio_capture/macos/audio_capture/Sources/audio_capture/SystemAudioTap.swift:5-26`。
- 14.4 以下麦克风降级：`packages/audio_capture/macos/audio_capture/Sources/audio_capture/MacOSAudioCapture.swift:131-165`。
- 24 kHz mono PCM 帧泵供实时转写：`packages/audio_capture/macos/audio_capture/Sources/audio_capture/PCMFramePump.swift:18-23`。
- CI Release 和 unsigned DMG：`.github/workflows/platform-builds.yml:32-54`。

未完成：

- 双路真录音、静音提示、暂停守恒、45 分钟、睡眠/唤醒、设备切换、托盘、安装包均无人工验收。
- 文件写入异常只把 native `writing` 置为 false，没有向 Dart 报错，存在静默截断风险：`MacOSAudioCapture.swift:215-243`。
- `macos/RunnerTests/RunnerTests.swift:5-10` 仍是模板空测试；CI 仅验证 PCMFramePump。
- unsigned 构建不能证明签名/公证后的 Sandbox + Process Tap 可用。

结论：构建链路通过，产品验收未放行。

### 4.2 Windows

已有：

- WASAPI 麦克风和 loopback 双源：`packages/audio_capture/windows/audio_capture_plugin.cpp:257-287`。
- 输出 16 kHz PCM16 mono WAV：`audio_capture_plugin.cpp:36-38,76-89`。
- 暂停、继续和 WAV 收尾：`audio_capture_plugin.cpp:229-242`。
- Release/MSIX CI：`.github/workflows/platform-builds.yml:72-125`。
- MSIX microphone capability：`packaging/windows/build_msix.ps1:53-63`。

未完成：

- `permissionStatus` 无条件返回两个 true：`audio_capture_plugin.cpp:473-479`；现有 native test 只验证该硬编码结果：`packages/audio_capture/windows/test/audio_capture_plugin_test.cpp:25-40`。
- 所有权限请求都打开麦克风设置：`audio_capture_plugin.cpp:480-483`。
- 两路音频按 FIFO 批次直接混合，没有时间戳或时钟漂移校正：`audio_capture_plugin.cpp:340-367`。
- Windows 未注册 `audio_capture/pcm` 通道：`audio_capture_plugin.cpp:389-410`，因此当前不支持实时转写。
- 没有设备变更、拔插、睡眠恢复和长会议真机证据。
- Windows native test 未进入 CI。

结论：可编译、可打包，但原生音频和功能一致性未放行。若“两端完成”要求实时转写同等可用，必须补 Windows PCM；若接受能力差异，需产品负责人书面批准并在 UI 中准确表达。

## 5. Calm Focus 差距

- 当前主色仍为靛蓝 `#6366F1`，不是暖底、石墨和鼠尾草绿：`lib/ui/theme/theme_tokens.dart:27-45`。
- Theme 只覆盖基础 ColorScheme、输入框和卡片圆角：`theme_tokens.dart:87-112`。
- 桌面导航仍是默认 `NavigationRail`，品牌头只有通用波形图标：`lib/ui/home_shell.dart:57-78`。
- 保存成功图标硬编码 `Colors.green`：`lib/ui/recording/recording_saved_panel.dart:50-54`。
- 生成的 Calm Focus App Icon 与插画尚未进入仓库；`pubspec.yaml:87-89` 仅声明现有两端图标。
- 设计规格要求详情默认打开“纪要”，代码默认打开“录音”：`outputs/EasyMeeting-assets-and-interactions.md:110-116` 对比 `lib/ui/library/meeting_detail_screen.dart:85-105`。
- 设计规格要求结束录音二次确认或 600ms 长按，当前直接执行停止：设计规格 `:73-92` 对比 `lib/ui/recording/meeting_workspace.dart:165-169`。
- 设计要求 Default/Hover/Pressed/Focus/Disabled/Loading 及减少动态效果：设计规格 `:37-54`；当前没有统一组件状态实现。
- 待办只读、无说话人头像、无 AI 问答与当前真实功能一致，应保留。

## 6. 风险登记

| ID | 等级 | 风险 | 放行条件 |
|---|---|---|---|
| R-01 | P1 | 托盘“结束并生成纪要”与实际 stop-only 行为冲突 | Loop 1 修正文案和状态，并有回归测试 |
| R-02 | P1 | 托盘把 recorded 映射为“纪要已生成” | Loop 1 改为“录音已保存” |
| R-03 | P1 | 详情展示未接线的内嵌播放器控制 | Loop 7 实现播放器，或改成明确的外部打开交互 |
| R-04 | P1 | 录音损坏、纪要处理中/失败等 UI 状态未由真实数据驱动 | Loop 6 建立资产状态投影并测试 |
| R-05 | P1 | macOS 写盘异常可能静默截断 | Loop 9 native 错误必须上报并可见 |
| R-06 | P1 | Windows 权限状态固定为已授权 | Loop 3 修正并通过真机验证 |
| R-07 | P1 | Windows 双路 FIFO 混音可能随时间漂移 | Loop 10 提供 45 分钟同步证据或重构同步策略 |
| R-08 | P1 | 两端均无正式真机音频验收 | Loop 9/10 阻断最终发布 |
| R-09 | P2 | Windows 录音页显示误导性的实时文字空面板 | Loop 5 按能力渲染 |
| R-10 | P2 | 搜索无 debounce，且不覆盖正式转写正文 | Loop 6 修正 |
| R-11 | P2 | 旧 Pipeline、旧会议库界面增加维护歧义 | 不在 Loop 1；另立清理切片并保证数据回归 |
| R-12 | P2 | 没有视觉 golden、键盘、Semantics 和减少动态效果测试 | Loop 2 起逐步补齐，Loop 8 全量门禁 |

## 7. 11 轮路线与门禁

### 共同门禁

每个实现 Loop 都必须提交以下证据：

1. `dart format --output=none --set-exit-if-changed lib test packages/audio_capture/lib packages/audio_capture/test`
2. `flutter analyze`
3. `flutter test`
4. `packages/audio_capture` 独立 analyze/test
5. macOS Release build
6. Windows Release build
7. GLM 变更说明、命令输出、截图/录像和已知风险
8. QA 独立 PASS/FAIL/BLOCKED 矩阵
9. 开发首席代码审查与最终 `APPROVED`

平台未受某轮直接影响时也不得跳过两端编译门禁。真实平台环境暂缺时只能标记 `BLOCKED`，不得以另一平台推断通过。

| Loop | 切片 | 专属门禁 |
|---|---|---|
| 0 | 技术基线 | 功能、架构、平台、视觉差距和风险完成只读审计；基线文档落库 |
| 1 | 产品真实性热修 + Calm Focus Token | 托盘无自动纪要承诺；冻结精确 Light/Dark、Typography、间距、圆角和组件状态；业务行为不变 |
| 2 | 桌面 Shell、导航、品牌与窗口响应式 | 880×600 至宽屏无溢出；四个真实入口；新 App Icon 16/32px 和托盘验证；键盘可达 |
| 3 | 权限引导与平台能力 | macOS 13/14.4+、Windows 的权限、拒绝、打开设置、刷新状态准确；Windows 不得硬编码已授权 |
| 4 | 录音准备、恢复与最近会议 | 模板、实时能力、降级、孤儿录音和最近会议均来自真实数据；双击开始只创建一场会议 |
| 5 | 实时录音工作区 | 状态机、暂停、继续、重点、安全结束、断网降级、平台差异均可验证；Windows 不显示误导性实时文字 |
| 6 | 会议库、搜索与资产状态投影 | 250ms debounce；转写正文可搜索；缺失/损坏/处理中/失败由真实文件和 Job 驱动 |
| 7 | 会议详情、播放、导出与独立删除 | 默认纪要；播放器能力真实；三个资产独立操作、缺失状态和删除提示回归通过 |
| 8 | 设置、回收站、插画与无障碍 | 生成资产落库；键盘顺序、焦点环、Semantics、点击区和减少动态效果通过 |
| 9 | macOS native 硬化 | 13.x mic-only、14.4+ dual、静音、设备异常、睡眠、45 分钟、暂停守恒、写盘失败、签名候选包全部验证 |
| 10 | Windows native、平台一致性与发布 | WASAPI 双路同步、设备切换、45 分钟、MSIX 安装通过；完成 Windows PCM 或批准差异；全回归签署 |

## 8. 审核状态

Loop 0：`APPROVED`，仅代表技术基线已建立。

产品发布：`REJECTED`。

允许进入 Loop 1；Loop 1 的文件白名单和精确合同见 `docs/architecture/loop-1-contract.md`。
