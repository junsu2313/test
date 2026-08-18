# Known-good S10 frame ID baseline

- Device: SM-G973N over Opal 5 GHz SSID
- App version: 0.3.0-field.1 (20260805)
- Added observation only: one bounded `EVF_PULSE` line per second
- Final Opal state: ready, liveView=false, frameFailures=0, reconnectCount=0

## Idle local live view, 65 seconds

- Pulse frame IDs: 28274-31898
- No fallback transition
- Median displayed FPS: 57
- Stable range after startup: approximately 50-61 FPS
- Startup ramp: 17, 36, 48, 43, 37, 37, 40, 41, 49 FPS
- Final rendered frames: 3,381
- Final overwritten frames: 259
- Initial 60-frame benchmark: output 41.72 FPS, frame ID gaps 4, decode P95 12.8 ms, render wait P95 29.9 ms

## Forced log transfer during local live view, 65 seconds

- Pulse frame IDs: 33431-37246
- No fallback transition
- Median displayed FPS: 58
- P05 displayed FPS: 47
- Sub-50 events: ID 35236 at 49 FPS, 35761 at 44 FPS, 36125 at 47 FPS, 37246 at 46 FPS
- Final rendered frames: 3,568
- Final overwritten frames: 294
- Initial 60-frame benchmark: output 59.81 FPS, frame ID gaps 5, decode P95 9.8 ms, render wait P95 40.1 ms

## Finding

The observed 54-59 FPS variation is normal producer/display jitter. Forced Tailscale
log transfer can temporarily reduce production/delivery to the mid-40s, but did not
cause a fallback or a frame-ID stop. The previously observed 10-30 FPS cliff was not
reproduced except for the normal live-view startup ramp. A future recurrence can now
be assigned to an exact frame ID using `EVF_PULSE`; fallback, queue depth, and overwrite
counters are recorded on the same line.

Absolute `transportAfterCaptureMs` is excluded because the S10 and Opal wall clocks
had an offset. Relative frame IDs and monotonic client timings remain valid.

## Artifacts

- `artifacts/frame-id/s10-idle-65s.log`
- `artifacts/frame-id/s10-scheduler-transfer-65s.log`
- Installed debug APK SHA-256: `2b7b284a10fd37a03162bcc51cf0c585289bd727705088406b6179b277c04c25`
