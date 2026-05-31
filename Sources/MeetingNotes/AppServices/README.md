# 应用服务层 (AppServices)

编排与状态管理，连接界面层与领域能力层。

对应设计文档「应用服务层」：
- RecordingCoordinator：录音状态机（待机/录音中/暂停/结束）
- ProcessingPipeline：离线处理流程编排（音频保存 → 转写 → 生成）
- TemplateManager：纪要模板管理（需求 16）
- ThemeManager：主题管理（需求 17）
- SettingsStore：配置管理（需求 15）

本层持有业务编排逻辑，向上驱动界面状态，向下调用领域能力。
