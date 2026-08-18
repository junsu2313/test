# Action-based watchdog optimization measurement

Date: 2026-07-28  
Target: GL.iNet Opal (`192.168.8.1`, local LAN) and Nikon D810

## Measurement method

- The same local HTTP endpoint, `/cgi-bin/status-v21`, was requested 20 times at three-second intervals.
- Each load interval lasted 60 seconds.
- A separate 60-second interval without status requests was measured before and after deployment.
- `/proc/stat` supplied total process forks, context switches, and CPU ticks.
- Client-side wall time supplied average, median, p95, and maximum response latency.
- Load results were adjusted by subtracting the adjacent idle interval.
- Tailscale SSH was not used.

## Changes deployed

- Camera actions run `bridge_action_guard` before accessing the camera stack.
- `runtime-guardian` changed from a 2-second to a 30-second safety interval.
- Battery worker wake interval changed from 5 to 30 seconds.
- Battery refresh interval changed from 45 to 300 seconds.
- `STATUS` no longer forces a PTP battery refresh.
- `status-v21` reads the bridge snapshot directly over one `nc` connection and does not source the runtime-management shell library.

## Raw measurements

| Phase | Forks | Context switches | CPU busy | Avg latency | Median | p95 | Max |
|---|---:|---:|---:|---:|---:|---:|---:|
| Before, 20 requests | 3,344 | 113,886 | 20.84% | 352.06 ms | 327.48 ms | 413.45 ms | 455.87 ms |
| Before, idle | 2,342 | 107,631 | 16.97% | - | - | - | - |
| First deployment, 20 requests | 1,742 | 101,650 | 11.37% | 137.92 ms | 131.44 ms | 166.80 ms | 172.35 ms |
| First deployment, idle | 1,251 | 98,692 | 10.31% | - | - | - | - |
| Final refactor, 20 requests | 1,331 | 99,812 | 10.38% | 44.28 ms | 41.80 ms | 54.58 ms | 76.02 ms |
| Final refactor, idle | 1,198 | 97,241 | 9.84% | - | - | - | - |

## Idle-adjusted result

| Metric | Before | Final | Reduction |
|---|---:|---:|---:|
| Status-request forks, 20 requests | 1,002 | 133 | 86.73% |
| Forks per status request | 50.10 | 6.65 | 86.73% |
| Status-request context switches | 6,255 | 2,571 | 58.90% |
| Incremental CPU busy | 3.87 percentage points | 0.54 percentage points | 86.05% |
| Average response latency | 352.06 ms | 44.28 ms | 87.42% |
| Median response latency | 327.48 ms | 41.80 ms | 87.24% |
| p95 response latency | 413.45 ms | 54.58 ms | 86.80% |

All 20 requests succeeded in every load interval.

## Runtime verification

- Camera session after deployment: `003_session`, `ready`.
- Bridge, WebSocket, runtime guardian, and battery worker each had one running process.
- Five consecutive status requests did not create or update the battery cache.
- Shell syntax, Lua syntax, repository contract tests, and `git diff --check` passed.

## Recovery

The original deployed files are preserved on the Opal at:

`/root/d810-deploy-backups/20260728-before-action-watchdog`

The first optimization stage is preserved at:

`/root/d810-deploy-backups/20260728-first-action-watchdog`

## Interpretation

These are paired 60-second measurements on the real device, not static estimates. They are one A/B sample per phase, so small differences should not be treated as statistically precise. The reduction is large and consistent across forks, CPU cost, context switches, and response latency.
