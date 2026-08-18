# Known-good conditional legacy frame cleanup

- Parent baseline: `known-good-fast-telemetry-2026-08-16.md`
- Scope changed: skip legacy frame-worker cleanup when neither its PID file nor lock exists
- Full live-view action contract: PASS
- Deployment backup: `/root/d810-script-backups/20260816-conditional-frame-cleanup/action-v21`
- Final state: healthy/ready, transportReady=true, liveView=false
- Final counters: frameFailures=0, reconnectCount=0

## Measured effect

The unused `frame-refresh-v21 stop` process cost 150-220 ms per invocation. After the
conditional check, action ingress-to-forwarding gaps changed as follows:

| Segment | Before | After |
|---|---:|---:|
| Live on | 180-260 ms | 20-30 ms |
| Live off | 150-210 ms | 40-80 ms |

Two 10-cycle runs completed with every request returning HTTP 200. The main-PC to
Tailscale run showed wider whole-request tails under continuous load: manual
0.46-1.70 s, live on 1.25-3.18 s, frame 0.29-1.12 s, and live off 0.74-1.55 s.
These tails are retained as evidence of a separate scheduling/contention target;
they do not occur in the removed pre-forwarding segment.

## Protected behavior

- A present legacy PID file or lock directory still invokes the original stop path.
- The persistent bridge remains the sole live-frame producer.
- No bridge, camera, or worker restart is required for deployment.
- Active local and Opal SHA-256: `88df542c8b922e1d9adafa8b5291afe56e3ba9494b25ac5750ee39b36f004edf`.
