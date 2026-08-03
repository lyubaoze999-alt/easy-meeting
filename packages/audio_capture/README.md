# audio_capture

Private four-platform audio capture plugin for Easy Meeting.

The control and level stream remains on `audio_capture/events`. Realtime audio
uses the independent `audio_capture/pcm` EventChannel and StandardMessageCodec.
Each event is a map containing:

- `sessionId`, `sequence`, and `startSample` timeline metadata;
- `sampleRate: 24000`, `channels: 1`;
- signed 16-bit little-endian PCM in a codec-native `Uint8List` under `bytes`.

Regular frames contain 200 ms (4,800 samples / 9,600 bytes). The last frame may
be shorter when capture stops. Native send queues may retain at most five
seconds of realtime copies; local WAV persistence has priority, and dropped
copies remain detectable through `sequence` and `startSample` discontinuities.

The normalized PCM stream is currently implemented on macOS. Windows, Android,
and iOS keep their existing recording behavior until their native frame pumps
are updated to the same contract.
