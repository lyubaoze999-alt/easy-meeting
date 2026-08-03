#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "audio_capture_plugin.h"

namespace audio_capture {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

}  // namespace

TEST(AudioCapturePlugin, ReportsAudioPermissionCapability) {
  AudioCapturePlugin plugin;
  bool microphone_granted = false;
  bool system_granted = false;
  plugin.HandleMethodCall(
      MethodCall("permissionStatus", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&microphone_granted, &system_granted](const EncodableValue* result) {
            const auto& map = std::get<EncodableMap>(*result);
            microphone_granted = std::get<bool>(map.at(EncodableValue("microphoneGranted")));
            system_granted = std::get<bool>(map.at(EncodableValue("systemAudioGranted")));
          },
          nullptr, nullptr));

  EXPECT_TRUE(microphone_granted);
  EXPECT_TRUE(system_granted);
}

}  // namespace test
}  // namespace audio_capture
