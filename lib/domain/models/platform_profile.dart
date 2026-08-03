import 'dart:io';

enum PlatformKind { macos, windows, android, ios }

enum DeviceForm { desktop, mobile }

enum AudioCapability { dualSource, micOnly }

class PlatformProfile {
  const PlatformProfile({
    required this.platform,
    required this.form,
    required this.audio,
  });

  final PlatformKind platform;
  final DeviceForm form;
  final AudioCapability audio;

  bool get hasResidentEntry => form == DeviceForm.desktop;
  bool get supportsSystemAudio => audio == AudioCapability.dualSource;
  bool get supportsRealtimePcm => platform == PlatformKind.macos;

  static PlatformProfile current() {
    final platform = Platform.isMacOS
        ? PlatformKind.macos
        : Platform.isWindows
        ? PlatformKind.windows
        : Platform.isAndroid
        ? PlatformKind.android
        : PlatformKind.ios;
    return resolve(
      platform: platform,
      operatingSystemVersion: Platform.operatingSystemVersion,
    );
  }

  static PlatformProfile resolve({
    required PlatformKind platform,
    String operatingSystemVersion = '',
  }) {
    if (platform == PlatformKind.macos) {
      return PlatformProfile(
        platform: platform,
        form: DeviceForm.desktop,
        audio: _macSupportsSystemAudio(operatingSystemVersion)
            ? AudioCapability.dualSource
            : AudioCapability.micOnly,
      );
    }
    if (platform == PlatformKind.windows) {
      return const PlatformProfile(
        platform: PlatformKind.windows,
        form: DeviceForm.desktop,
        audio: AudioCapability.dualSource,
      );
    }
    if (platform == PlatformKind.android) {
      return const PlatformProfile(
        platform: PlatformKind.android,
        form: DeviceForm.mobile,
        audio: AudioCapability.dualSource,
      );
    }
    return const PlatformProfile(
      platform: PlatformKind.ios,
      form: DeviceForm.mobile,
      audio: AudioCapability.micOnly,
    );
  }

  static bool _macSupportsSystemAudio(String source) {
    final match = RegExp(r'(\d+)\.(\d+)').firstMatch(source);
    if (match == null) return false;
    final major = int.parse(match.group(1)!);
    final minor = int.parse(match.group(2)!);
    return major > 14 || (major == 14 && minor >= 4);
  }
}
