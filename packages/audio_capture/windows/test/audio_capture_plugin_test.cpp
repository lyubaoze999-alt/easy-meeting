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

// The permissionStatus result must be structurally valid (both consent keys
// present as bools) and no longer hardcode granted=true. Values reflect the
// real Windows privacy registry, so they are not asserted to a fixed boolean.
TEST(AudioCapturePlugin, ReportsAudioPermissionCapabilityFromRealConsentState) {
  AudioCapturePlugin plugin;
  bool invoked = false;
  bool microphone_granted = false;
  bool system_granted = false;
  plugin.HandleMethodCall(
      MethodCall("permissionStatus", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&invoked, &microphone_granted, &system_granted](
              const EncodableValue* result) {
            invoked = true;
            ASSERT_TRUE(std::holds_alternative<EncodableMap>(*result));
            const auto& map = std::get<EncodableMap>(*result);
            microphone_granted =
                std::get<bool>(map.at(EncodableValue("microphoneGranted")));
            system_granted =
                std::get<bool>(map.at(EncodableValue("systemAudioGranted")));
          },
          nullptr, nullptr));

  EXPECT_TRUE(invoked);
  // Both keys must be present and bool; system (loopback) consent mirrors the
  // microphone consent on modern Windows, so the two must agree.
  EXPECT_EQ(microphone_granted, system_granted);
}

}  // namespace test
}  // namespace audio_capture
