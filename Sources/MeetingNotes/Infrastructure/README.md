# 基础设施层 (Infrastructure)

与系统框架、网络、存储的具体对接，实现领域能力层定义的协议。

对应设计文档「基础设施层」：
- CoreAudio Tap + AVAudioEngine：系统声音 Tap 与麦克风采集混音
- URLSession OpenAI 兼容客户端：转写/总结服务调用与连接测试（需求 15）
- SQLite(GRDB) + 文件系统：纪要元数据入库，音频/转写/正文存文件（需求 11）
- Keychain：apiKey 存储，不明文入库（需求 15.1、15.2）
- UserNotifications：后台处理完成通知（需求 8.7）
- PermissionManager：屏幕录制 + 麦克风权限检测与跳转（需求 3）
