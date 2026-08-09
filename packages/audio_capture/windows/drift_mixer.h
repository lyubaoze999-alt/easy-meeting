#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace audio_capture {

// Drift-corrected mono mixer for the two WASAPI capture streams (R-07).
//
// The microphone and system-loopback sources run on independent clocks, so
// their sample counts per wall-second differ slightly. Naively mixing a mic
// block against a system block by FIFO index lets the two tracks drift out of
// phase over a long meeting (and drains one stream ahead of the other). This
// mixer keeps a carry buffer of unconsumed system samples and resamples the
// system stream onto the microphone timeline using a running sample-count
// ratio, so the two tracks stay temporally locked regardless of clock drift.
//
// The microphone stream owns the output timeline (one output sample per mic
// sample — the meeting is as long as the mic says). The system stream is what
// gets resampled onto it. Pure C++ with no Windows/Flutter dependencies so it
// can be unit-tested on any host.
class DriftMixer {
 public:
  // Feeds one microphone block and the newest system samples (may be empty),
  // and appends the mixed mono int16 output to `out`. The output always has
  // exactly `mic_samples.size()` samples (the mic timeline), each mixed with
  // the temporally aligned system sample when one has arrived.
  void Mix(const std::vector<int16_t>& mic_samples,
           const std::vector<int16_t>& system_samples,
           std::vector<int16_t>* out) {
    const int64_t mic_before = mic_total_;
    const int64_t system_before = system_total_;
    const size_t mic_count = mic_samples.size();

    carry_.insert(carry_.end(), system_samples.begin(), system_samples.end());
    system_total_ += static_cast<int64_t>(system_samples.size());

    // System samples to consume per mic sample, estimated from the (already
    // streamed) cumulative counts. Both streams are realtime and roughly rate
    // matched, so this converges to the true clock ratio and lets the two
    // tracks ride the same timeline instead of drifting. Until both streams
    // have produced data we assume 1:1 (startup), and we clamp to a sane range
    // so a one-sided burst can never stall or explode the cursor.
    const double raw_ratio =
        (mic_before > 0 && system_before > 0)
            ? static_cast<double>(system_before) /
                  static_cast<double>(mic_before)
            : 1.0;
    const double ratio = std::clamp(raw_ratio, 0.5, 2.0);

    for (size_t i = 0; i < mic_count; ++i) {
      const int64_t pos = static_cast<int64_t>(system_cursor_ + 0.5);
      const int64_t local = pos - carry_start_;
      int16_t sample = mic_samples[i];
      if (local >= 0 &&
          local < static_cast<int64_t>(carry_.size())) {
        const int mixed =
            (static_cast<int>(mic_samples[i]) +
             carry_.at(static_cast<size_t>(local))) /
            2;
        sample = static_cast<int16_t>(std::clamp(mixed, -32768, 32767));
      }
      out->push_back(sample);
      system_cursor_ += ratio;
    }
    mic_total_ = mic_before + static_cast<int64_t>(mic_count);

    // Drop the system samples that have been consumed into the output.
    const int64_t consumed = static_cast<int64_t>(system_cursor_ + 0.5) -
                             carry_start_;
    if (consumed > 0) {
      const size_t drop = static_cast<size_t>(std::min<int64_t>(
          consumed, static_cast<int64_t>(carry_.size())));
      carry_.erase(carry_.begin(),
                   carry_.begin() + static_cast<std::ptrdiff_t>(drop));
      carry_start_ += static_cast<int64_t>(drop);
    }
  }

  void Reset() {
    carry_.clear();
    carry_start_ = 0;
    system_total_ = 0;
    mic_total_ = 0;
    system_cursor_ = 0;
  }

 private:
  std::vector<int16_t> carry_;
  int64_t carry_start_ = 0;   // absolute system-sample index of carry_[0]
  int64_t system_total_ = 0;  // cumulative system samples fed
  int64_t mic_total_ = 0;     // cumulative mic samples fed
  double system_cursor_ = 0;  // absolute fractional system position consumed
};

}  // namespace audio_capture