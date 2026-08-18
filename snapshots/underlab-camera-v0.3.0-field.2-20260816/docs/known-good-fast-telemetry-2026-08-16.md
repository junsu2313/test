# Known-good fast telemetry baseline

- Parent baseline: `known-good-health-declarations-2026-08-16.md`
- Scope changed: shell clock reuse, ingress token sanitization, duplicate event removal
- Full contract suite: PASS
- Final health: healthy, ready, transportReady=true
- Final counters: frameFailures=0, reconnectCount=0
- Completion telemetry: trace ID, command ID, result, and duration preserved

## Ten-cycle latency comparison

| Segment | Health baseline | Fast telemetry |
|---|---:|---:|
| Manual status | 1.24-2.85 s | 0.40-1.26 s |
| Live on | 1.78-3.18 s | 1.29-1.57 s |
| Cached HTTP frame | 0.23-0.38 s | 0.17-0.25 s |
| Live off | 1.38-1.88 s | 0.83-1.10 s |

All 10 cycles returned HTTP 200. No camera or bridge recovery occurred.

## Active deployment hashes

Local and `/www/cgi-bin` hashes matched after deployment.

```text
b799dc09ac63f5e0f70ffc72e05787dfb6ae4a58539f0ca9c82442df9ea2be43  bridge-common.sh
d716cc0f4371301fdb5422fec635922686229e63d64e93ca4efc1031329f17fe  action-v21
```

## Protected behavior

- Exact wall-clock milliseconds are initialized once per CGI process.
- Later stage timestamps use `/proc/uptime` without spawning Lua.
- External trace, command, client, and UI timestamp values remain sanitized at ingress.
- Stage logs preserve request-entry evidence.
- One correlated completion event preserves result and duration without a duplicate synchronous start event.
