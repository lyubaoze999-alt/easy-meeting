# 会议纪要（Easy Meeting）

常驻 macOS 菜单栏的极简会议纪要工具。开会时一键开始录音，同时采集系统声音与麦克风并混为一路；会议结束后以离线批处理方式调用你自配置的大模型服务，先完成语音转写，再依据所选模板生成结构化纪要。

定位是零学习成本：不做实时字幕、不做说话人区分、不展示逐字稿，只输出整理好的纪要。

## 功能

- **菜单栏常驻**：四态面板（待机 / 录音 / 处理 / 完成），点击图标即用
- **双音源采集**：系统声音（Core Audio Process Tap）+ 麦克风（AVAudioEngine）混音为 16kHz 单声道 WAV
- **离线处理流程**：音频保存 → 语音转写（超长自动切片）→ 纪要生成，分步进度可见，支持后台继续并完成通知
- **重点标记**：录音中一键打点，生成纪要时聚焦关键内容
- **纪要库**：左右分栏，按日期分组浏览与搜索，结构化展示，支持复制全文 / 导出 Markdown
- **纯文本 / 图文模式**：图文模式额外生成时间线、思维导图、关键数字卡片
- **自配置服务**：转写与总结服务各自配置兼容 OpenAI 协议的接口地址、密钥、模型名，支持连接测试
- **模板与主题**：内置默认 / 站会 / 评审 / 面试模板，支持自定义；浅色 / 深色 / 跟随系统主题，设计令牌驱动

## 技术栈

| 维度 | 选型 |
|------|------|
| 语言 / UI | Swift + SwiftUI |
| 最低系统 | macOS 14.4+（Core Audio Process Tap 免装虚拟声卡） |
| 系统音频 | Core Audio Process Tap |
| 麦克风 | AVAudioEngine |
| 网络 | URLSession（OpenAI 兼容接口） |
| 本地存储 | SQLite (GRDB.swift) + 文件系统；密钥存 Keychain |
| 通知 | UserNotifications |

## 架构

分层架构，自上而下：界面层（SwiftUI）→ 应用服务层（录音协调、处理流程编排、配置/模板/主题管理）→ 领域能力层（采集、转写、生成、仓储）→ 基础设施层（Core Audio、URLSession、SQLite、Keychain、权限、通知）。

```
Sources/MeetingNotes/
├── App/              应用入口与依赖装配
├── UI/               界面层（菜单栏面板、纪要库、设置、权限引导、主题令牌）
├── AppServices/      应用服务层（RecordingCoordinator / ProcessingPipeline / SettingsStore / TemplateManager / ThemeManager）
├── Domain/           领域能力层（Audio / Transcription / Summary / Models）
└── Infrastructure/   基础设施层（NoteRepository / KeychainStore / OpenAICompatibleClient / PermissionManager / CompletionNotifier）
```

## 构建与运行

需要 macOS 14.4+ 与 Swift 工具链：

```bash
swift build          # 构建
swift run            # 运行（菜单栏常驻）
swift test           # 运行测试（需完整 Xcode，提供 XCTest 模块）
```

> 注：`swift test` 依赖完整 Xcode（含 XCTest）；仅装 Command Line Tools 的环境无法运行测试，但 `swift build` 不受影响。

首次启动会引导授予屏幕录制（用于采集系统声音）与麦克风权限。使用前需在「设置」中配置转写服务与总结服务（兼容 OpenAI 协议）。

## 正确性属性

实现遵循 8 条正确性属性并以属性测试守护：录音不丢段、切片转写顺序一致、进度单调且完整、配置缺失即阻断、密钥不外泄、主题令牌唯一来源、图文模式不丢文字、界面文案全中文。
