# Known-good layer and latency baseline

- Captured: 2026-08-16T03:15:53+09:00
- Route policy: camera API stays on the Opal LAN; Tailscale is control/log transport only.
- Contract suite: PASS (215 checks)
- Final state: ready, transportReady=true, softwareReady=true, liveView=false
- Health counters: frameFailures=0, reconnectCount=0
- Camera frame internals: total 10-26 ms normally; final sample 12 ms
- Status API (10): 53-88 ms
- Manual-status API (10): 0.92-4.06 s; bridge/PTP portion about 90-170 ms
- Live-on API (10): 1.85-5.10 s
- HTTP frame (10): 0.30-3.53 s, 29-35 KB, all HTTP 200
- Live-off API (10): 1.50-5.40 s
- Tailscale ping (10): min 12 ms, avg 29 ms, max 74 ms, loss 0%
- Fresh Tailscale SSH (5): 1.64-2.20 s
- Opal storage: 84% used, 14,320 KiB free; outbox ready files: 14
- Observed bottleneck: synchronous shell process discovery and field telemetry before bridge dispatch; frame CGI also runs bridge_start before serving an existing frame.

## Active deployment hashes

Local and `/www/cgi-bin` hashes matched at capture time.

```text
c9d0bbf15f78f644e3219f2d7cb7d404a3d8f0e50a2f443e62d644dec6fc7b51  d810bridge.lua
d26e73ceb8d8a2cc8056239cb0501827b4bada5d325830fbd8857af41ef605ef  d810d.lua
e38e82518780b9ee706cf08f0c716a0f9d7de770b0128fd125718831829ca4e5  action-v21
1cd2e63d3d1f855f406e18e8e512003b21249873b2898c23e0c70b425f55069b  liveview-v21
20a452f2594a2a542720fa8714d1c4235e44c5e6695933efe121721e8dbd52ad  bridge-common.sh
6c1bbc2350eb00c8af25a97fd18a97567021bd2007500eec08cac172e12b953c  variant-v21-env.sh
```

## Regression rule

Future work must preserve the hashes of untouched files and keep all health counters at zero. Any latency regression or state mismatch must be classified as a regression or a newly exposed latent defect before deployment.
