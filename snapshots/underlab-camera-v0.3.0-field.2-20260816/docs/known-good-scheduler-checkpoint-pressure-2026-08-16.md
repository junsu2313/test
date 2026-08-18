# Scheduler checkpoint pressure baseline (2026-08-16)

## Scenario

- S10 live view was allowed to stabilize before pressure.
- At measurement +20 s, `/usr/bin/d810-log-checkpoint force` ran once.
- S10 `EVF_PULSE` and the Opal producer frame ID stream were measured together for 70 s.

## Result

- Stable 10 s before pressure: median 59 FPS, minimum 51 FPS.
- Forced checkpoint duration: 52.61 s (PC-observed 54.50 s).
- During pressure: median 42 FPS, minimum 28 FPS.
- Producer: 46.81 FPS average, frame ID gaps 0, producer-gap P95 38 ms, maximum 242 ms.
- S10: fallback count 0; decoded queue maximum 3.
- After pressure: FPS immediately returned to 47–48 in the two available samples.

## Interpretation and invariant

The slowdown follows the Opal producer frame IDs. It is not an S10 decode/display failure.
The forced checkpoint duplicates and hashes large log files and ends with a global `sync` on a 116 MiB-class device.
At this baseline the outbox held 12 ready objects (26,804 KiB), while source logs included two 7–8 MiB watch timelines.

Routine `periodic` checkpoints must continue to defer while live view is requested.
`force` is an explicit shutdown/recovery pressure path and must not be scheduled during live view as routine work.

## Evidence

- `artifacts/frame-id/20260816-044435-s10-checkpoint-pressure.log`
- `artifacts/frame-id/20260816-044435-opal-checkpoint-pressure.json`
- `artifacts/frame-id/20260816-044435-checkpoint-pressure-events.log`

## Optimized result

The checkpoint scheduler now defers both routine and forced checkpoints while
live view owns the camera path, unless an emergency caller explicitly sets
`D810_LOG_CHECKPOINT_ALLOW_LIVE_FORCE=1`. Unchanged force requests are hash
deduplicated, and a global `sync` runs only when at least one new snapshot was
written.

- Identical live-view force request: 52.61 s -> 0.02 s (`deferred-live`).
- Ten seconds before the request: median 59 FPS, minimum 54 FPS.
- Fifty-one samples after the request: median 57 FPS, minimum 38 FPS, no sample below 30 FPS.
- The isolated 38 FPS sample occurred 45 s after the request and is not correlated with it.
- Deferred idle checkpoint: 10.49 s, pending marker cleared, four changed snapshots queued.
- Final camera state: ready, live view off, frame failures 0, reconnects 0.

Optimized evidence:

- `artifacts/frame-id/20260816-045122-s10-checkpoint-pressure.log`
- `artifacts/frame-id/20260816-045122-checkpoint-pressure-events.log`
