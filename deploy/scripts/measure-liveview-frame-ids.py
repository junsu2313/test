#!/usr/bin/env python3
import argparse
import csv
import json
import math
import os
import struct
import time
from pathlib import Path

import websocket


def percentile(values, ratio):
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, math.ceil(len(ordered) * ratio) - 1))
    return ordered[index]


def main():
    parser = argparse.ArgumentParser(description="Measure live-view delivery by frame ID")
    parser.add_argument("--url", default="ws://100.123.59.97:8191/")
    parser.add_argument("--duration", type=float, default=60.0)
    parser.add_argument("--label", default="idle")
    parser.add_argument("--output-dir", default="artifacts/frame-id")
    args = parser.parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    csv_path = output_dir / f"{stamp}-{args.label}.csv"
    summary_path = output_dir / f"{stamp}-{args.label}-summary.json"

    os.environ["NO_PROXY"] = "100.123.59.97,localhost,127.0.0.1"
    ws = websocket.create_connection(args.url, header=["X-D810-Client: pc-frame-id-monitor"],
        timeout=5, http_proxy_host=None, http_proxy_port=None, enable_multithread=False)
    ws.settimeout(2)
    started = time.perf_counter()
    deadline = started + args.duration
    pending = None
    records = []
    timeout_count = 0
    try:
        while time.perf_counter() < deadline:
            try:
                payload = ws.recv()
            except websocket.WebSocketTimeoutException:
                timeout_count += 1
                continue
            if isinstance(payload, str):
                try:
                    meta = json.loads(payload)
                except json.JSONDecodeError:
                    continue
                if meta.get("type") == "meta":
                    meta["transportMode"] = meta.get("transport", "fallback")
                    pending = meta
                continue
            if not isinstance(payload, bytes):
                continue
            if len(payload) == 52 and payload[:4] == b"D8L5":
                fields = struct.unpack(">4sIIQQIIIIII", payload)
                pending = {"frameId": fields[2], "startedAt": fields[3], "captureDoneAt": fields[4],
                    "totalMs": fields[5], "captureMs": fields[6], "bytes": fields[7], "transportMode": "direct"}
                continue
            if pending is None or len(payload) < 4 or payload[:2] != b"\xff\xd8":
                continue
            received_perf_ms = (time.perf_counter() - started) * 1000
            received_epoch_ms = time.time() * 1000
            previous = records[-1] if records else None
            frame_id = int(pending.get("frameId") or 0)
            capture_done = float(pending.get("captureDoneAt") or 0)
            records.append({
                "frameId": frame_id,
                "receivedElapsedMs": round(received_perf_ms, 3),
                "receiveGapMs": round(received_perf_ms - previous["receivedElapsedMs"], 3) if previous else 0,
                "producerGapMs": round(capture_done - previous["captureDoneAt"], 3) if previous else 0,
                "transportAfterCaptureMs": round(received_epoch_ms - capture_done, 3) if capture_done else 0,
                "captureDoneAt": capture_done,
                "captureMs": int(pending.get("captureMs") or 0),
                "bytes": int(pending.get("bytes") or len(payload)),
                "idGap": max(0, frame_id - previous["frameId"] - 1) if previous and frame_id else 0,
                "transportMode": pending.get("transportMode", "unknown"),
            })
            pending = None
    finally:
        elapsed = time.perf_counter() - started
        ws.close()

    fields = list(records[0].keys()) if records else ["frameId"]
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(records)

    usable = records[1:]
    arrival_times = [row["receivedElapsedMs"] for row in records]
    sliding_fps = []
    left = right = 0
    for at in range(2000, max(2000, int(elapsed * 1000) - 250), 250):
        while left < len(arrival_times) and arrival_times[left] <= at - 1000:
            left += 1
        while right < len(arrival_times) and arrival_times[right] <= at:
            right += 1
        sliding_fps.append(right - left)
    slow_events = sorted((row for row in usable if row["receiveGapMs"] >= 33 or
        row["producerGapMs"] >= 33 or row["idGap"]), key=lambda row: row["receiveGapMs"], reverse=True)[:20]
    modes = {}
    for row in records:
        modes[row["transportMode"]] = modes.get(row["transportMode"], 0) + 1
    summary = {
        "label": args.label, "durationSeconds": round(elapsed, 3), "frames": len(records),
        "firstFrameId": records[0]["frameId"] if records else 0,
        "lastFrameId": records[-1]["frameId"] if records else 0,
        "idGaps": sum(row["idGap"] for row in records), "transportModes": modes,
        "receiveGapP50Ms": round(percentile([row["receiveGapMs"] for row in usable], .50), 3),
        "receiveGapP95Ms": round(percentile([row["receiveGapMs"] for row in usable], .95), 3),
        "receiveGapMaxMs": round(percentile([row["receiveGapMs"] for row in usable], 1), 3),
        "producerGapP95Ms": round(percentile([row["producerGapMs"] for row in usable], .95), 3),
        "producerGapMaxMs": round(percentile([row["producerGapMs"] for row in usable], 1), 3),
        "transportP95Ms": round(percentile([row["transportAfterCaptureMs"] for row in records], .95), 3),
        "slidingFpsMin": round(percentile(sliding_fps, 0), 1),
        "slidingFpsP05": round(percentile(sliding_fps, .05), 1),
        "slidingFpsMedian": round(percentile(sliding_fps, .50), 1),
        "receiveTimeouts": timeout_count, "slowEvents": slow_events, "csvPath": str(csv_path.resolve()),
    }
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
