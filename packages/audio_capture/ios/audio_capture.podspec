#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint audio_capture.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'audio_capture'
  s.version          = '0.0.1'
  s.summary          = 'Easy Meeting microphone capture plugin.'
  s.description      = <<-DESC
Captures microphone audio for Easy Meeting on iOS.
                       DESC
  s.homepage         = 'https://meetingnotes.invalid'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'MeetingNotes' => 'dev@meetingnotes.invalid' }
  s.source           = { :path => '.' }
  s.source_files = 'audio_capture/Sources/audio_capture/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'audio_capture_privacy' => ['audio_capture/Sources/audio_capture/PrivacyInfo.xcprivacy']}
end
