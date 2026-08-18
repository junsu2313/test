# Known-good healthy recovery no-op

- Parent baseline: `known-good-conditional-frame-cleanup-2026-08-16.md`
- Scope changed: a fresh healthy declaration with matching LIVE intent answers RECOVER without entering the camera queue
- Full live-view action contract: PASS
- Backup: `/root/d810-script-backups/20260816-healthy-recover-noop`
- Final state: healthy/ready, transportReady=true, liveView=false
- Final counters: frameFailures=0, reconnectCount=0

## Recovery latency

- Before: 1.16-3.52 s
- After, 10 requests: 0.37-0.85 s
- Every response: HTTP 200 and `healthyNoop=true`
- A real unsolicited UI recovery during the load test also used the queue-free path.

## Ten-cycle main-PC to Tailscale result

| Segment | Median | P95 | Success |
|---|---:|---:|---:|
| Manual status | 0.523 s | 1.352 s | 10/10 |
| Live on | 1.318 s | 2.801 s | 10/10 |
| Cached frame | 0.363 s | 1.544 s | 10/10 |
| Live off | 0.872 s | 2.212 s | 10/10 |

The healthy recovery queue collision is removed. A separate correlated spike still
appears across every segment near the end of a roughly 30-second continuous run;
that periodic scheduler/resource contention is the next target.

## Protected behavior

- Missing, stale, or unhealthy declarations still execute the original RECOVER.
- A mismatch between declared LIVE state and explicit user intent still executes RECOVER and restoration.
- Healthy idle cannot override explicit LIVE intent, and healthy LIVE cannot resurrect a stopped session.
- Active Opal hashes: action `aa2889244d769f66d2f0a48e81da2013113809e41cf692adbf543e4609269b34`, common `f2d15c61ddbe4d087fbbff5bcd55a9f638916e818e06b860176fab30c4ba95cf`.
