# 桌面端真机验收记录

## 自动化验收（2026-08-03）

- [x] `flutter analyze`：0 issue
- [x] Flutter 全量测试：81 项通过
- [x] `audio_capture` 插件 analyze 与 4 项测试通过
- [x] macOS `PCMFramePump` 原生测试通过；已接入 macOS CI 构建门禁
- [x] Android release APK 生成成功（58.4 MB）
- [x] 实时/批量转写并发 revision、跨会议事件隔离、pending connect 取消、退出 drain、暂停队列清理、录音归档重试均有自动化覆盖
- [x] 四端平台构建：[GitHub Actions run 30809195120](https://github.com/lyubaoze999-alt/easy-meeting/actions/runs/30809195120) 全部通过
- [x] macOS release + DMG：`macos-15` 已验证，unsigned DMG artifact 22.3 MB
- [x] Windows release + MSIX：`windows-2022` / Visual Studio 2022 已验证，unsigned MSIX artifact 14.2 MB
- [x] Android release APK：CI artifact 26.7 MB（压缩包大小），本地 APK 58.4 MB
- [x] iOS no-codesign archive：`macos-15` 已验证，unsigned xcarchive artifact 49.9 MB；签名后才可导出 IPA
- [x] 共享质量门禁：[GitHub Actions run 30809195094](https://github.com/lyubaoze999-alt/easy-meeting/actions/runs/30809195094) 通过
- [x] Loop 9 原生逻辑（`MacAudioLogic`）swiftc 测试接入 macOS CI：静音迟滞、环形缓冲
  溢出去旧、RMS 电平、错误分类与降级文案、`writeError` 上报链（原生 → Dart →
  协调器 → 工作区横幅）均有自动化覆盖

自动化通过不替代下列桌面真机音频验收。

> macOS 真机项（13.x mic-only、14.4+ dual、睡眠/恢复、设备切换、45 分钟长录、
> 暂停守恒、签名候选包）仍为 Loop 9 真机验收清单，本环境无物理 Mac，如实标记
> `BLOCKED`（见下方「结果：阻塞」）。不得以另一平台推断通过。

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
