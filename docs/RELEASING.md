# 内测包发布

所有密钥、证书和密码都由发布环境注入，不提交到仓库。Flutter 官方发布文档要求 Android release 使用上传密钥，Apple 平台使用有效开发者团队/证书；缺少材料时本工程只产出 unsigned 构建。

## Android

复制 `android/key.properties.example` 为 `android/key.properties`，填写发布者提供的 keystore 绝对路径和密码，然后执行：

```sh
flutter build apk --release
```

没有 `key.properties` 时仍可运行构建门禁，但产物是未签名 APK。

## macOS

安装完整 Xcode，选择 Xcode developer directory。无证书构建与 DMG：

```sh
flutter build macos --release
bash packaging/macos/create_dmg.sh
```

提供 Developer ID Application identity 后设置 `EASY_MEETING_MACOS_SIGN_IDENTITY`，脚本会先签名再创建 DMG。对外分发还需使用发布者 Apple 账号完成 notarization。

## Windows

在 Windows + Visual Studio 2022 Desktop C++ 环境执行：

```powershell
flutter build windows --release
./packaging/windows/build_msix.ps1
```

签名时额外传入 `-Publisher`、`-CertificatePath`、`-CertificatePassword`，Publisher 必须与证书 subject 一致。

## iOS

CI 使用 `flutter build ipa --release --no-codesign` 验证 archive。Ad Hoc IPA 需要发布者提供 Apple Team、分发证书、已登记设备和 Provisioning Profile，再在 Xcode 或 CI 中执行签名导出。

