# 会议纪要（Easy Meeting）

本地优先、用户自带 OpenAI 兼容 API 的 Flutter 四端会议纪要应用。macOS、Windows 和 Android 尽可能同时采集系统声音与麦克风；iOS 明确降级为仅麦克风。录音结束后按顺序转写、生成只读结构化纪要并保存在本机。

## 已实现

- Riverpod + drift 共享业务层，安全存储 API 密钥
- 持久化 ProcessingJob、原子检查点、失败重试与启动恢复
- 30 天回收站、搜索、Markdown 导出、图文纪要
- 脱敏诊断日志与用户主动导出的 ZIP 反馈包
- macOS Core Audio Process Tap、Windows WASAPI、Android AudioPlaybackCapture、iOS AVAudioEngine 原生插件源码
- 桌面托盘、后台处理和四端本地完成通知
- Android debug APK 已在当前机器实际构建通过

## 本地开发

要求 Flutter 3.44.8 stable 和 Dart 3.12.2。Android 需要 JDK 17、API 36 SDK、NDK 28.2；Apple 平台需要完整 Xcode；Windows 需要 Visual Studio 2022 Desktop development with C++。

```sh
flutter pub get
flutter analyze
flutter test
```

平台构建：

```sh
flutter build apk --debug
flutter build macos --release
flutter build windows --release
flutter build ipa --release --no-codesign
```

产品名称与标识的源配置位于 `tool/product_config.json`。修改后运行 `dart run tool/sync_product_config.dart`，再人工检查平台工程中的签名标识。

发布与签名见 `docs/RELEASING.md`，桌面真机验收见 `docs/acceptance/desktop-checklist.md`。

## 当前外部阻塞

- 当前 macOS 机器只有 Command Line Tools，没有完整 Xcode，因此 macOS/iOS 尚未本机编译。
- 当前没有 Windows 真机与 Visual Studio C++ 环境，因此 WASAPI 插件等待 Windows CI/真机验证。
- 正式签名所需 Android keystore、Apple 证书/Team/Provisioning Profile、Windows 代码签名证书由发布者提供。

原 Swift 版本保存在 Git 标签 `swift-native-v1`。
