# 领域能力层 (Domain)

核心业务能力与领域模型，以协议定义对外接口，由基础设施层提供实现。

对应设计文档「领域能力层」：
- AudioCaptureService：双音源采集混音（需求 5、6）
- TranscriptionService：转写 + 切片顺序合并（需求 8、9）
- SummaryService：纪要生成（需求 7、12、16）
- NoteRepository：纪要仓储（增删查改与搜索）

领域模型（MeetingNote / NoteSection / TodoItem / NoteVisuals / NoteTemplate
/ ServiceConfig / AppSettings / ThemeMode）也归属本层。
