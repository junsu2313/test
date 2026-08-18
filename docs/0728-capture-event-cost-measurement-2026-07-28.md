# Capture-event preview optimization measurement

Date: 2026-07-28  
Target: GL.iNet Opal (`192.168.8.1`, local LAN) and Nikon D810

## Goal

Keep the existing camera-body shutter and image-save path unchanged while replacing repeated preview-JPEG probes with Nikon capture-event observation.

## Before

The UI requested `/cgi-bin/captured-preview?probe=...` every 1.6 seconds. Each probe:

- loaded the runtime-management shell library;
- checked or started runtime processes;
- returned the complete cached preview JPEG;
- used preview metadata changes as an indirect capture signal.

## After

- The bridge reads Nikon `GetEvent` (`0x90C7`).
- PTP `ObjectAdded` (`0x4002`) increments a persistent bridge event sequence.
- The new `/cgi-bin/capture-event` endpoint returns compact JSON.
- The bridge downloads and caches a thumbnail once when `ObjectAdded` occurs.
- The UI compares `captureEventSeq` and requests the normal preview only after the sequence changes.
- The camera shutter and storage path were not changed.

## Measurement method

- Each endpoint was requested 20 times at 1.6-second intervals over 32 seconds.
- A separate 32-second idle interval was measured for fork and CPU adjustment.
- `/proc/stat` supplied process forks and CPU ticks.
- Client-side wall time supplied response latency.
- HTTP body size measured transfer cost.
- Tailscale SSH was not used.

## Result

| Metric | JPEG probe | Capture event | Reduction |
|---|---:|---:|---:|
| Idle-adjusted forks, 20 requests | 790 | 69 | 91.27% |
| Forks per request | 39.50 | 3.45 | 91.27% |
| Incremental CPU busy | 2.93 percentage points | 0.43 percentage points | 85.32% |
| Average response latency | 264.80 ms | 52.57 ms | 80.15% |
| p95 response latency | 267.77 ms | 77.65 ms | 71.00% |
| HTTP body, 20 requests | 197,420 bytes | 6,800 bytes | 96.56% |
| HTTP body per request | 9,871 bytes | 340 bytes | 96.56% |

All 20 requests succeeded in both measurement phases.

## Functional verification

- D810 idle events were observed as `0x4006 DevicePropChanged`.
- A test capture produced `0x4002 ObjectAdded` with an object handle.
- `CaptureComplete` was observed in the same capture-event flow.
- The bridge generated a 160-pixel thumbnail and marked `previewReady=true`.
- A browser page that did not initiate the capture changed to `shot preview ready`.
- The browser displayed the new preview as a blob-backed image with natural width 160.
- No browser warnings or errors were recorded.

The existing program shutter produced the image and event but returned the pre-existing `camera control release failed 0xa003` response. A following `UNLOCK` action succeeded.

## Physical shutter verification boundary

Two 60-second observation windows were opened for a camera-body shutter press, including one after a successful `UNLOCK`. No physical capture input was observed during those windows, so this specific operator action remains unconfirmed. The D810 `ObjectAdded` event and UI preview path itself is verified.

## Recovery

The pre-event bridge is preserved on the Opal at:

`/root/d810-deploy-backups/20260728-before-capture-event`

The active UI and backend files before the final event UI deployment are preserved at:

`/root/d810-deploy-backups/20260728-before-capture-event-ui`

## Interpretation

These are paired measurements from the real Opal. The new path retains short event-queue polling because the browser cannot consume the camera USB event directly, but it no longer polls or transfers preview images. Image work occurs only after a real Nikon capture event.
