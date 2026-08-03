import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final config =
      jsonDecode(await File('tool/product_config.json').readAsString()) as Map;
  final name = config['displayName'] as String;
  final identifier = config['bundleIdentifier'] as String;

  await _replace('lib/product_config.dart', [
    (RegExp(r"displayName = '[^']*'"), "displayName = '$name'"),
    (RegExp(r"bundleIdentifier = '[^']*'"), "bundleIdentifier = '$identifier'"),
  ]);
  await _replace('macos/Runner/Configs/AppInfo.xcconfig', [
    (RegExp(r'PRODUCT_NAME = .*'), 'PRODUCT_NAME = $name'),
    (
      RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = .*'),
      'PRODUCT_BUNDLE_IDENTIFIER = $identifier',
    ),
  ]);
  await _replaceMapped(
    'ios/Runner/Info.plist',
    RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
    (match) => '${match.group(1)}$name${match.group(2)}',
  );
  await _replaceMapped(
    'ios/Runner.xcodeproj/project.pbxproj',
    RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);'),
    (match) =>
        'PRODUCT_BUNDLE_IDENTIFIER = $identifier${match.group(1)!.endsWith('.RunnerTests') ? '.RunnerTests' : ''};',
  );
  await _replace('android/app/build.gradle.kts', [
    (RegExp(r'namespace = "[^"]+"'), 'namespace = "$identifier"'),
    (RegExp(r'applicationId = "[^"]+"'), 'applicationId = "$identifier"'),
  ]);
  await _replace('android/app/src/main/AndroidManifest.xml', [
    (RegExp(r'android:label="[^"]+"'), 'android:label="$name"'),
  ]);
  await _replace('windows/runner/main.cpp', [
    (RegExp(r'window\.Create\(L"[^"]+"'), 'window.Create(L"$name"'),
  ]);
  await _replace('windows/runner/Runner.rc', [
    (
      RegExp(r'VALUE "FileDescription", "[^"]+"'),
      'VALUE "FileDescription", "$name"',
    ),
    (RegExp(r'VALUE "ProductName", "[^"]+"'), 'VALUE "ProductName", "$name"'),
  ]);
  stdout.writeln('Product configuration synchronized.');
}

Future<void> _replaceMapped(
  String path,
  RegExp pattern,
  String Function(Match) replacement,
) async {
  final file = File(path);
  final source = await file.readAsString();
  await file.writeAsString(
    source.replaceAllMapped(pattern, replacement),
    flush: true,
  );
}

Future<void> _replace(String path, List<(RegExp, String)> replacements) async {
  final file = File(path);
  var source = await file.readAsString();
  for (final (pattern, replacement) in replacements) {
    source = source.replaceAll(pattern, replacement);
  }
  await file.writeAsString(source, flush: true);
}
