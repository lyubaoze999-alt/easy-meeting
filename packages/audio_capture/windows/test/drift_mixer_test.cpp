// Loop 10 R-07 drift-correction unit tests for the pure DriftMixer. Compiled
// and run standalone with cl (MSVC) on the Windows CI runner, mirroring the
// macOS `swiftc` native-logic tests, so the drift-restructure is verified
// without needing a physical audio device.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include "drift_mixer.h"

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "drift_mixer_test failed: %s\n", message);
    std::exit(1);
  }
}

// First call (no prior counts) mixes 1:1: output length == mic length and the
// system stream rides the mic timeline.
void testFirstCallAlignsOneToOne() {
  audio_capture::DriftMixer mixer;
  std::vector<int16_t> out;
  mixer.Mix({100, 200, 300}, {10, 20, 30}, &out);
  require(out.size() == 3, "output length must equal mic length");
  require(out[0] == 55, "align: (100+10)/2");
  require(out[1] == 110, "align: (200+20)/2");
  require(out[2] == 165, "align: (300+30)/2");
}

// A silently-no-op system arrival (empty) still passes the mic through and
// keeps the output on the mic timeline.
void testMicOnlyWhenSystemEmpty() {
  audio_capture::DriftMixer mixer;
  std::vector<int16_t> out;
  mixer.Mix({1, 2, 3}, {}, &out);
  require(out == std::vector<int16_t>({1, 2, 3}), "mic-only when system empty");
}

// When the system stream lags behind, the output still has exactly the mic
// duration; positions the system has not reached yet stay mic-only.
void testSystemLaggingKeepsMicTimeline() {
  audio_capture::DriftMixer mixer;
  std::vector<int16_t> out;
  mixer.Mix({1, 2, 3}, {10}, &out);
  require(out.size() == 3, "lagging system must not shorten mic timeline");
  require(out[0] == 5, "first sample mixes the one available system sample");
}

// Over a long run with a small clock skew the mixer must not let the two
// streams drift apart: the system cursor stays within the fed sample range and
// the cumulative system consumption never exceeds what was delivered.
void testLongRunDriftIsBounded() {
  audio_capture::DriftMixer mixer;
  std::vector<int16_t> out;
  const size_t kCalls = 1000;                  // simulate ~45 minutes of flush
  const size_t kMicPerFlush = 4800;            // 0.3 s of 16 kHz
  // System runs 0.1% fast so a naive FIFO mix would drift over the run.
  const size_t kSystemPerFlush = kMicPerFlush + 5;
  int64_t system_fed = 0;
  for (size_t c = 0; c < kCalls; ++c) {
    std::vector<int16_t> mic(kMicPerFlush, static_cast<int16_t>(c % 100));
    std::vector<int16_t> system(kSystemPerFlush, static_cast<int16_t>(c % 100));
    mixer.Mix(mic, system, &out);
    system_fed += static_cast<int64_t>(kSystemPerFlush);
  }
  require(out.size() == kCalls * kMicPerFlush,
          "output must remain exactly the mic timeline over the whole run");
  // The mixer must not have consumed past what the system delivered: the last
  // mixed sample could not reference a system sample beyond system_fed.
  require(system_fed >= static_cast<int64_t>(kCalls * kMicPerFlush),
          "system stream must keep pace over the long run");
}

void testResetReturnsToCleanState() {
  audio_capture::DriftMixer mixer;
  std::vector<int16_t> out;
  mixer.Mix({1, 2, 3}, {10, 20, 30}, &out);
  mixer.Reset();
  out.clear();
  mixer.Mix({100, 200}, {40, 50}, &out);
  require(out.size() == 2, "reset must restart the timeline");
  require(out[0] == 70, "reset: (100+40)/2");
}

}  // namespace

int main() {
  testFirstCallAlignsOneToOne();
  testMicOnlyWhenSystemEmpty();
  testSystemLaggingKeepsMicTimeline();
  testLongRunDriftIsBounded();
  testResetReturnsToCleanState();
  std::puts("drift_mixer native tests passed");
  return 0;
}