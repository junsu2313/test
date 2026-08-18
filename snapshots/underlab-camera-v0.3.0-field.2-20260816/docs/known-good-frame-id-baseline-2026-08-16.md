# Known-good frame ID baseline

- Scope: distinguish camera/PTP production jitter from scheduler and delivery drops
- Measurement source: Opal direct stream `127.0.0.1:8190`
- Final state: healthy/ready, frameFailures=0, reconnectCount=0

## Idle producer, 60 seconds

- Frame IDs: 9974-13528
- Frames: 3,555
- Average: 59.23 FPS
- ID gaps: 0
- Producer gap P95: 27 ms
- Producer gap max: 136 ms

## Scheduled puller deferred during LIVE, 45 seconds

- Frame IDs: 13654-16319
- Frames: 2,666
- Average: 59.22 FPS
- ID gaps: 0
- Producer gap P95: 27 ms
- Producer gap max: 116 ms

## Forced Tailscale log transfer during LIVE, 45 seconds

- Frame IDs: 16446-19036
- Frames: 2,591
- Average: 57.56 FPS
- ID gaps: 0
- Producer gap P95: 31 ms
- Producer gap max: 100 ms

## Finding

Idle variation around 54-59 FPS is compatible with producer jitter. The forced log
transfer causes a small measurable reduction, but not the observed 10-30 FPS cliff.
The severe drop is downstream of frame production: Opal-to-S10 delivery, JPEG decode,
or display scheduling. The S10 EVF benchmark already records frame IDs and per-layer
times, but the S10 wireless ADB endpoint was unavailable for this run.

The PC-over-Tailscale WebSocket is intentionally excluded as an app baseline. At the
live-view bitrate it backpressures after several seconds and falls back to the cached
stream; the camera app correctly uses the Opal SSID local path instead.
