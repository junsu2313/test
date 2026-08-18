#!/usr/bin/env python3
"""Capture and compare 60 D810 live-view frames without storing images on Android."""

from __future__ import annotations

import argparse
import asyncio
import csv
import json
import math
import struct
import time
from dataclasses import dataclass
from pathlib import Path

import cv2
import numpy as np
import websockets


@dataclass
class SourceFrame:
    index: int
    jpeg: bytes
    image: np.ndarray
    metadata: dict[str, int]
    received_ns: int


def parse_metadata(payload: bytes) -> dict[str, int]:
    if len(payload) != 52 or payload[:4] != b"D8L5":
        raise ValueError("invalid D8L5 metadata")
    values = struct.unpack(">4sIIQQIIIIII", payload)
    return {
        "length": values[1],
        "frameId": values[2],
        "startedAt": values[3],
        "captureDoneAt": values[4],
        "totalMs": values[5],
        "captureMs": values[6],
        "bytes": values[7],
        "wireTotalUs": values[8],
        "firstPacketUs": values[9],
        "parseUs": values[10],
    }


async def capture_frames(uri: str, count: int) -> list[SourceFrame]:
    frames: list[SourceFrame] = []
    pending_meta: dict[str, int] | None = None
    async with websockets.connect(uri, max_size=4 * 1024 * 1024, proxy=None) as socket:
        while len(frames) < count:
            payload = await asyncio.wait_for(socket.recv(), timeout=10)
            if not isinstance(payload, bytes):
                continue
            if len(payload) == 52 and payload[:4] == b"D8L5":
                pending_meta = parse_metadata(payload)
                continue
            received_ns = time.time_ns()
            image = cv2.imdecode(np.frombuffer(payload, np.uint8), cv2.IMREAD_COLOR)
            if image is None:
                continue
            frames.append(SourceFrame(len(frames) + 1, payload, image, pending_meta or {}, received_ns))
            pending_meta = None
            print(f"capture {len(frames):02d}/{count} frameId={frames[-1].metadata.get('frameId', 0)}", flush=True)
    return frames


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    t = np.clip((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


class Processor:
    def __init__(self, name: str, target_size: tuple[int, int]):
        self.name = name
        self.target_size = target_size
        self.history: np.ndarray | None = None
        self.frame_history: list[np.ndarray] = []
        self.hanning: np.ndarray | None = None

    def process(self, source: np.ndarray) -> np.ndarray:
        if self.name == "bilinear":
            return cv2.resize(source, self.target_size, interpolation=cv2.INTER_LINEAR)
        if self.name == "bicubic":
            return cv2.resize(source, self.target_size, interpolation=cv2.INTER_CUBIC)
        if self.name == "lanczos4":
            return cv2.resize(source, self.target_size, interpolation=cv2.INTER_LANCZOS4)
        if self.name == "bilateral_lanczos":
            # Edge-preserving spatial denoise before enlargement.  Working at
            # source resolution is both cheaper and less likely to blur edges.
            clean = cv2.bilateralFilter(source, 5, 14.0, 2.0)
            return cv2.resize(clean, self.target_size, interpolation=cv2.INTER_LANCZOS4)
        if self.name == "nlmeans_lanczos":
            # OpenCV's classical non-local means implementation; deliberately
            # conservative chroma strength to avoid waxy colour transitions.
            clean = cv2.fastNlMeansDenoisingColored(source, None, 3.5, 2.5, 7, 15)
            return cv2.resize(clean, self.target_size, interpolation=cv2.INTER_LANCZOS4)
        if self.name == "temporal_bilateral":
            current = source.astype(np.float32) / 255.0
            if self.history is None:
                temporal = current
            else:
                difference = np.max(np.abs(current - self.history), axis=2, keepdims=True)
                stable = 1.0 - smoothstep(0.018, 0.085, difference)
                temporal = current * (1.0 - stable * 0.42) + self.history * (stable * 0.42)
            self.history = temporal
            clean = cv2.bilateralFilter(
                np.clip(temporal * 255.0, 0, 255).astype(np.uint8), 5, 11.0, 2.0
            )
            return cv2.resize(clean, self.target_size, interpolation=cv2.INTER_LANCZOS4)
        if self.name in ("multiframe_sr_4", "multiframe_sr_8"):
            count = 4 if self.name.endswith("_4") else 8
            return self._multiframe_sr(source, count)
        if self.name == "current_evf":
            current = source.astype(np.float32) / 255.0
            if self.history is None:
                temporal = current
            else:
                difference = np.max(np.abs(current - self.history), axis=2, keepdims=True)
                stable = 1.0 - smoothstep(0.025, 0.115, difference)
                temporal = current * (1.0 - stable * 0.34) + self.history * (stable * 0.34)
            self.history = temporal
            enlarged = cv2.resize(temporal, self.target_size, interpolation=cv2.INTER_LINEAR)
            north = np.roll(enlarged, 1, axis=0)
            south = np.roll(enlarged, -1, axis=0)
            west = np.roll(enlarged, 1, axis=1)
            east = np.roll(enlarged, -1, axis=1)
            blur = (north + south + west + east) * 0.25
            return np.clip((enlarged + (enlarged - blur) * 0.18) * 255.0, 0, 255).astype(np.uint8)
        raise ValueError(f"unknown processor: {self.name}")

    def _multiframe_sr(self, source: np.ndarray, count: int) -> np.ndarray:
        """Translation-aligned robust burst reconstruction at 3x resolution.

        Sub-pixel camera motion provides differently positioned samples.  Each
        previous frame is aligned to the current frame and accumulated directly
        on the high-resolution grid. Pixels that disagree after alignment are
        rejected to prevent moving objects from producing trails.
        """
        current = source.astype(np.float32) / 255.0
        self.frame_history.append(current)
        self.frame_history = self.frame_history[-count:]
        if len(self.frame_history) == 1:
            return cv2.resize(source, self.target_size, interpolation=cv2.INTER_LANCZOS4)

        height, width = source.shape[:2]
        scale_x = self.target_size[0] / width
        scale_y = self.target_size[1] / height
        if self.hanning is None or self.hanning.shape != (height, width):
            self.hanning = cv2.createHanningWindow((width, height), cv2.CV_32F)
        reference_gray = cv2.cvtColor(current, cv2.COLOR_BGR2GRAY)

        base = cv2.resize(current, self.target_size, interpolation=cv2.INTER_LANCZOS4)
        accumulator = base.copy()
        weights = np.ones((*base.shape[:2], 1), dtype=np.float32)

        for previous in self.frame_history[:-1]:
            previous_gray = cv2.cvtColor(previous, cv2.COLOR_BGR2GRAY)
            shift, response = cv2.phaseCorrelate(previous_gray, reference_gray, self.hanning)
            dx, dy = shift
            if response < 0.08 or abs(dx) > 4.0 or abs(dy) > 4.0:
                continue

            source_matrix = np.array([[1.0, 0.0, dx], [0.0, 1.0, dy]], dtype=np.float32)
            aligned_low = cv2.warpAffine(
                previous, source_matrix, (width, height), flags=cv2.INTER_LINEAR,
                borderMode=cv2.BORDER_REFLECT101,
            )
            disagreement = np.max(np.abs(aligned_low - current), axis=2)
            stable = np.exp(-((disagreement / 0.055) ** 2)).astype(np.float32)
            stable[disagreement > 0.14] = 0.0

            high_matrix = np.array(
                [[scale_x, 0.0, dx * scale_x], [0.0, scale_y, dy * scale_y]],
                dtype=np.float32,
            )
            aligned_high = cv2.warpAffine(
                previous, high_matrix, self.target_size, flags=cv2.INTER_LANCZOS4,
                borderMode=cv2.BORDER_REFLECT101,
            )
            high_weight = cv2.resize(stable, self.target_size, interpolation=cv2.INTER_LINEAR)[..., None]
            # Correlation confidence prevents weak global alignments dominating.
            high_weight *= float(np.clip(response, 0.0, 1.0))
            accumulator += aligned_high * high_weight
            weights += high_weight

        reconstructed = accumulator / np.maximum(weights, 1e-6)
        return np.clip(reconstructed * 255.0, 0, 255).astype(np.uint8)


def noise_sigma(gray: np.ndarray) -> float:
    kernel = np.array([[1, -2, 1], [-2, 4, -2], [1, -2, 1]], dtype=np.float32)
    response = cv2.filter2D(gray.astype(np.float32), -1, kernel)
    denominator = max(1, 6 * (gray.shape[0] - 2) * (gray.shape[1] - 2))
    return float(math.sqrt(math.pi / 2.0) * np.sum(np.abs(response[1:-1, 1:-1])) / denominator)


def blockiness(gray: np.ndarray, scale: int = 3) -> float:
    step = 8 * scale
    x = np.arange(step, gray.shape[1], step)
    y = np.arange(step, gray.shape[0], step)
    vertical = np.mean(np.abs(gray[:, x].astype(np.float32) - gray[:, x - 1].astype(np.float32)))
    horizontal = np.mean(np.abs(gray[y, :].astype(np.float32) - gray[y - 1, :].astype(np.float32)))
    return float((vertical + horizontal) * 0.5)


def chroma_noise(image: np.ndarray) -> float:
    chroma = cv2.cvtColor(image, cv2.COLOR_BGR2YCrCb)[:, :, 1:].astype(np.float32)
    residual = chroma - cv2.GaussianBlur(chroma, (0, 0), 1.2)
    return float(np.sqrt(np.mean(residual * residual)))


def psnr(reference: np.ndarray, image: np.ndarray) -> float:
    error = np.mean((reference.astype(np.float32) - image.astype(np.float32)) ** 2)
    return 99.0 if error <= 1e-9 else float(10.0 * math.log10((255.0 * 255.0) / error))


def metrics(image: np.ndarray, previous: np.ndarray | None, baseline: np.ndarray) -> dict[str, float]:
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    laplacian = cv2.Laplacian(gray, cv2.CV_32F)
    gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
    gradient = cv2.magnitude(gx, gy)
    temporal_mad = 0.0 if previous is None else float(np.mean(np.abs(image.astype(np.float32) - previous.astype(np.float32))))
    return {
        "noiseSigma": noise_sigma(gray),
        "chromaNoise": chroma_noise(image),
        "laplacianVariance": float(np.var(laplacian)),
        "edgeP95": float(np.percentile(gradient, 95)),
        "blockiness": blockiness(gray),
        "temporalMad": temporal_mad,
        "psnrVsBilinear": psnr(baseline, image),
    }


def make_comparison_video(
    frames: list[SourceFrame], output: Path, labels: list[str], fps: float = 15.0
) -> None:
    if len(labels) != 4:
        raise ValueError("comparison video requires exactly four algorithms")
    target_size = (frames[0].image.shape[1] * 3, frames[0].image.shape[0] * 3)
    processors = {name: Processor(name, target_size) for name in labels}
    writer = cv2.VideoWriter(str(output), cv2.VideoWriter_fourcc(*"mp4v"), fps, (1920, 1080))
    if not writer.isOpened():
        raise RuntimeError("OpenCV could not create MP4 video")
    positions = [(0, 0), (960, 0), (0, 540), (960, 540)]
    for frame in frames:
        canvas = np.zeros((1080, 1920, 3), dtype=np.uint8)
        for label, (x, y) in zip(labels, positions):
            rendered = processors[label].process(frame.image)
            view_width = 810
            view_height = min(540, round(view_width * rendered.shape[0] / rendered.shape[1]))
            view = cv2.resize(rendered, (view_width, view_height), interpolation=cv2.INTER_AREA)
            left = x + (960 - view_width) // 2
            top = y + (540 - view_height) // 2
            canvas[top:top + view_height, left:left + view_width] = view
            cv2.rectangle(canvas, (left, y), (left + 300, y + 45), (0, 0, 0), -1)
            cv2.putText(canvas, label, (left + 12, y + 32), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2, cv2.LINE_AA)
        writer.write(canvas)
    writer.release()


def summarize(rows: list[dict[str, object]], algorithms: list[str]) -> dict[str, object]:
    summary: dict[str, object] = {}
    fields = ["processMs", "noiseSigma", "chromaNoise", "laplacianVariance", "edgeP95", "blockiness", "temporalMad", "psnrVsBilinear"]
    for algorithm in algorithms:
        selected = [row for row in rows if row["algorithm"] == algorithm]
        summary[algorithm] = {
            field: {
                "mean": round(float(np.mean([row[field] for row in selected])), 4),
                "p50": round(float(np.percentile([row[field] for row in selected], 50)), 4),
                "p95": round(float(np.percentile([row[field] for row in selected], 95)), 4),
            }
            for field in fields
        }
    return summary


def run_analysis(
    frames: list[SourceFrame], output_dir: Path, algorithm_names: list[str]
) -> tuple[Path, Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    source_dir = output_dir / "source"
    source_dir.mkdir(exist_ok=True)
    for frame in frames:
        (source_dir / f"frame-{frame.index:03d}.jpg").write_bytes(frame.jpeg)

    target_size = (frames[0].image.shape[1] * 3, frames[0].image.shape[0] * 3)
    processors = {name: Processor(name, target_size) for name in algorithm_names}
    rows: list[dict[str, object]] = []
    previous: dict[str, np.ndarray | None] = {name: None for name in algorithm_names}

    for frame in frames:
        rendered: dict[str, np.ndarray] = {}
        process_times: dict[str, float] = {}
        for name in algorithm_names:
            started = time.perf_counter_ns()
            rendered[name] = processors[name].process(frame.image)
            process_times[name] = (time.perf_counter_ns() - started) / 1_000_000.0
        baseline = rendered.get("bilinear", rendered.get("lanczos4", next(iter(rendered.values()))))
        for name in algorithm_names:
            measured = metrics(rendered[name], previous[name], baseline)
            previous[name] = rendered[name]
            rows.append({
                "sourceFrame": frame.index,
                "frameId": frame.metadata.get("frameId", 0),
                "algorithm": name,
                "processMs": process_times[name],
                **measured,
            })

    csv_path = output_dir / "frame-metrics.csv"
    with csv_path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    source_intervals = [
        (frames[index].received_ns - frames[index - 1].received_ns) / 1_000_000.0
        for index in range(1, len(frames))
    ]
    report = {
        "sampleFrames": len(frames),
        "sourceWidth": int(frames[0].image.shape[1]),
        "sourceHeight": int(frames[0].image.shape[0]),
        "evaluationWidth": target_size[0],
        "evaluationHeight": target_size[1],
        "sourceFps": round(1000.0 / float(np.mean(source_intervals)), 4),
        "sourceIntervalMs": {
            "mean": round(float(np.mean(source_intervals)), 4),
            "p50": round(float(np.percentile(source_intervals, 50)), 4),
            "p95": round(float(np.percentile(source_intervals, 95)), 4),
        },
        "algorithms": summarize(rows, algorithm_names),
        "metricNotes": {
            "noiseSigma": "Lower is smoother; edges can influence this no-reference estimate.",
            "chromaNoise": "Lower is less chroma speckle.",
            "laplacianVariance": "Higher is sharper but can also mean amplified noise.",
            "edgeP95": "Higher means stronger high-percentile edges.",
            "blockiness": "Lower means weaker scaled JPEG 8x8 boundaries.",
            "temporalMad": "Lower means more temporal stability, but scene motion also contributes.",
        },
    }
    report_path = output_dir / "summary.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    video_path = output_dir / "evf-algorithm-comparison.mp4"
    make_comparison_video(frames, video_path, algorithm_names)
    return report_path, csv_path, video_path


def load_frames(source_dir: Path, interval_ms: float) -> list[SourceFrame]:
    frames: list[SourceFrame] = []
    base_ns = time.time_ns()
    for index, path in enumerate(sorted(source_dir.glob("frame-*.jpg")), start=1):
        jpeg = path.read_bytes()
        image = cv2.imdecode(np.frombuffer(jpeg, np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            continue
        frames.append(SourceFrame(index, jpeg, image, {"frameId": index}, base_ns + round((index - 1) * interval_ms * 1_000_000)))
    if not frames:
        raise RuntimeError(f"no JPEG frames found in {source_dir}")
    return frames


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", default="ws://192.168.8.1:8191/")
    parser.add_argument("--frames", type=int, default=60)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--source-interval-ms", type=float, default=15.5677)
    parser.add_argument(
        "--algorithms",
        nargs=4,
        default=["bilinear", "bicubic", "lanczos4", "current_evf"],
        help="exactly four processor names, also used as the video quadrants",
    )
    args = parser.parse_args()
    frames = load_frames(args.input, args.source_interval_ms) if args.input else asyncio.run(capture_frames(args.uri, args.frames))
    report, csv_path, video = run_analysis(frames, args.output, args.algorithms)
    print(json.dumps({"report": str(report), "csv": str(csv_path), "video": str(video)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
