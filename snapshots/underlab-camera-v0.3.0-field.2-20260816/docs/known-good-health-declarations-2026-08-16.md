# Known-good health-declaration baseline

- Parent baseline: `known-good-layer-latency-baseline-2026-08-16.md`
- Scope changed: bridge health publication, action guard routing, cached-frame guard routing
- Full contract suite: PASS
- Final state: ready, transportReady=true, frameFailures=0, reconnectCount=0
- Normal-path guardian escalations during 10 cycles: 0
- Synthetic missing-health escalation: PASS; guardian invoked once without disrupting service

## Ten-cycle latency comparison

| Segment | Before | After |
|---|---:|---:|
| Live on | 1.85-5.10 s | 1.78-3.18 s |
| Cached HTTP frame | 0.30-3.53 s | 0.23-0.38 s |
| Live off | 1.50-5.40 s | 1.38-1.88 s |

Manual status remained variable at 1.24-2.85 s because synchronous common-library setup and telemetry process creation remain on the normal path. Those are outside this change's guard-routing scope.

## Active deployment hashes

Local and `/www/cgi-bin` hashes matched after deployment.

```text
d98a681bc161806e7b7452cd403dd7c81637d6779e9d84598189c18c392898fc  d810bridge.lua
5d1311ecfd8e44a8f569704553ae7fcd633a215395de69638550e9c1b27f081e  bridge-common.sh
d1bf10f86777dd74c01073906501720f35f27aa29da7c5b4672cdf89509084ed  liveview-v21
```

## Protected behavior

- The bridge publishes `healthy` only while transport, hardware, and backend state agree.
- Health declarations expire within three seconds if the bridge stops publishing.
- Normal actions trust a fresh declaration and do not invoke the heavy guardian.
- Missing, stale, or unhealthy declarations invoke the existing guardian path.
- Cached frames are served without runtime inspection; missing frames invoke recovery checks.
