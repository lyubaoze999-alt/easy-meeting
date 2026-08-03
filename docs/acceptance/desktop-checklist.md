# 桌面端真机验收记录

## 自动化验收（2026-08-03）

- [x] `flutter analyze`：0 issue
- [x] Flutter 全量测试：76 项通过
- [x] `audio_capture` 插件 analyze 与 4 项测试通过
- [x] macOS `PCMFramePump` 原生测试通过；已接入 macOS CI 构建门禁
- [x] Android release APK 生成成功（58.1 MB）
- [x] 实时/批量转写并发 revision、跨会议事件隔离、pending connect 取消、退出 drain、暂停队列清理、录音归档重试均有自动化覆盖
- [ ] macOS release + DMG：待推送后由 `macos-15` GitHub Actions 验证
- [ ] Windows release + MSIX、iOS no-codesign IPA：待推送后由平台 CI 验证

自动化通过不替代下列桌面真机音频验收。

## macOS 13.0+

- [ ] macOS 13.0–14.3 可启动并明确降级为仅麦克风录音
- [ ] macOS 14.4+ 系统声音不可用时自动降级为仅麦克风并显示操作提示

- [ ] 系统声音与麦克风同时有电平并写入同一 WAV
- [ ] 任一路静音提示准确，另一条通路继续录制
- [ ] 暂停区间不写入，继续后时长守恒
- [ ] 45 分钟以上音频可切片、按序转写
- [ ] 关闭窗口后托盘状态和处理任务继续
- [ ] 转写/总结失败后从检查点恢复
- [ ] 完成第一场后可开始第二场
- [ ] DMG 可安装并启动

执行日期：待完整 Xcode 环境
执行人：待填写
结果：阻塞
阻塞原因：当前机器仅安装 Command Line Tools，没有完整 Xcode。

## Windows 10 1809+

- [ ] WASAPI loopback 与麦克风同时有电平并写入同一 WAV
- [ ] 任一路静音提示准确，另一条通路继续录制
- [ ] 暂停区间不写入，继续后时长守恒
- [ ] 45 分钟以上音频可切片、按序转写
- [ ] 关闭窗口后托盘状态和处理任务继续
- [ ] 转写/总结失败后从检查点恢复
- [ ] 完成第一场后可开始第二场
- [ ] MSIX 可安装并启动

执行日期：待 Windows 真机环境
执行人：待填写
结果：阻塞
阻塞原因：当前没有 Windows + Visual Studio C++ 真机构建环境。
