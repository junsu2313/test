#!/usr/bin/env python3
"""Generate a practical hierarchy-aware chaos suite.

The four causal layers are exhaustively crossed. Secondary context factors are
assigned pairwise, and only known order-sensitive races receive explicit event
sequences. Unsafe electrical and storage-destruction faults are absent.
"""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import random
from pathlib import Path
from typing import Mapping, Sequence


PIPELINE_DOMAINS: dict[str, tuple[str, ...]] = {
    "d810": ("ready", "standby_wake", "usb_reconnect", "power_cycle_recover"),
    "ddserver": ("healthy", "term_recover", "restart_during_request"),
    "session_manager": ("stable", "bridge_term_recover", "stale_session_repair", "websocket_reconnect"),
    "s10": ("foreground", "wifi_reconnect", "background_resume", "force_stop_relaunch"),
}

CONTEXT_DOMAINS: dict[str, tuple[str, ...]] = {
    "operating_mode": ("remote_idle", "liveview"),
    "log_profile": ("normal", "trace_burst", "rotation_boundary"),
    "delivery_profile": ("normal", "backlog_recovery", "puller_restart"),
}

DOMAINS = {**PIPELINE_DOMAINS, **CONTEXT_DOMAINS}
FACTOR_NAMES = tuple(DOMAINS)
FACTOR_INDEX = {name: index for index, name in enumerate(FACTOR_NAMES)}


def valid(row: Mapping[str, str]) -> bool:
    return not (
        row["session_manager"] == "websocket_reconnect"
        and row["operating_mode"] != "liveview"
    )


def pair_key(left: str, left_value: str, right: str, right_value: str) -> tuple[str, str, str, str]:
    if FACTOR_INDEX[left] < FACTOR_INDEX[right]:
        return left, left_value, right, right_value
    return right, right_value, left, left_value


def row_pairs(row: Mapping[str, str]) -> set[tuple[str, str, str, str]]:
    return {
        pair_key(left, row[left], right, row[right])
        for left, right in itertools.combinations(FACTOR_NAMES, 2)
    }


def all_candidates() -> list[dict[str, str]]:
    rows = []
    for values in itertools.product(*(DOMAINS[name] for name in FACTOR_NAMES)):
        row = dict(zip(FACTOR_NAMES, values))
        if valid(row):
            rows.append(row)
    return rows


RACE_CASES = (
    ("RACE-01", "request_then_ddserver_term", "request_begin>ddserver_term>detect>ddserver_recover>request_retry"),
    ("RACE-02", "ddserver_term_then_request", "ddserver_term>request_begin>detect>ddserver_recover>request_retry"),
    ("RACE-03", "bridge_term_during_request", "request_begin>bridge_term>action_guard>bridge_recover>response"),
    ("RACE-04", "guardian_first", "bridge_term>guardian_detect>session_health_probe>bridge_recover"),
    ("RACE-05", "session_probe_first", "bridge_term>session_health_probe>guardian_detect>bridge_recover"),
    ("RACE-06", "repair_overlap", "bridge_term>guardian_detect+session_health_probe>single_bridge_recover"),
    ("RACE-07", "client_first", "s10_reconnect>session_recreate>websocket_attach>ready"),
    ("RACE-08", "server_first", "session_recreate>s10_reconnect>websocket_attach>ready"),
    ("RACE-09", "client_server_overlap", "s10_reconnect+session_recreate>single_websocket_attach>ready"),
    ("RACE-10", "checkpoint_reboot", "checkpoint_begin>forced_reboot>boot_ready>checkpoint_retry>outbox_ready"),
    ("RACE-11", "puller_term_transfer", "transfer_begin>puller_term>stale_lock_recover>transfer_retry>hash_ack"),
    ("RACE-12", "rotation_checkpoint_overlap", "log_rotation+checkpoint_begin>atomic_ready>hash_verify>ack"),
)


def generate(seed: int = 810) -> tuple[list[dict[str, str]], set[tuple[str, str, str, str]]]:
    candidates = all_candidates()
    requirements = set().union(*(row_pairs(row) for row in candidates))
    uncovered = set(requirements)
    rng = random.Random(seed)

    grouped: dict[tuple[str, ...], list[dict[str, str]]] = {}
    for row in candidates:
        key = tuple(row[name] for name in PIPELINE_DOMAINS)
        grouped.setdefault(key, []).append(row)

    baseline_key = tuple(values[0] for values in PIPELINE_DOMAINS.values())
    baseline = {name: values[0] for name, values in DOMAINS.items()}
    selected = [baseline]
    uncovered -= row_pairs(baseline)

    keys = [key for key in grouped if key != baseline_key]
    rng.shuffle(keys)
    for key in keys:
        options = grouped[key]
        scored = [(len(row_pairs(row) & uncovered), rng.random(), row) for row in options]
        row = max(scored, key=lambda item: (item[0], item[1]))[2]
        selected.append(row)
        uncovered -= row_pairs(row)

    # A baseline pipeline tuple still needs only one row for exhaustive layer
    # coverage, but another context may be needed to close secondary pairs.
    while uncovered:
        row = max(candidates, key=lambda item: len(row_pairs(item) & uncovered))
        gain = row_pairs(row) & uncovered
        if not gain:
            raise RuntimeError("unable to cover all valid secondary pairs")
        selected.append(row)
        uncovered -= gain

    return selected, requirements


def race_rows() -> list[dict[str, str]]:
    rows = []
    for case_id, name, events in RACE_CASES:
        rows.append(
            {
                "case_id": case_id,
                "case_type": "ordered_race",
                "d810": "ready",
                "ddserver": "healthy",
                "session_manager": "stable",
                "s10": "foreground",
                "operating_mode": "liveview" if "websocket" in events or "client" in name else "remote_idle",
                "log_profile": "rotation_boundary" if "rotation" in name else "normal",
                "delivery_profile": "puller_restart" if "puller" in name else "normal",
                "ordered_events": events,
                "expected_invariant": "pipeline_converges_once_and_trace_is_complete",
            }
        )
    return rows


def calculate(seed: int = 810) -> tuple[dict, list[dict[str, str]]]:
    pipeline_rows, requirements = generate(seed)
    covered = set().union(*(row_pairs(row) for row in pipeline_rows))
    base_count = 1
    for values in PIPELINE_DOMAINS.values():
        base_count *= len(values)

    output_rows = []
    for index, row in enumerate(pipeline_rows, 1):
        output_rows.append(
            {
                "case_id": f"PIPE-{index:03d}",
                "case_type": "pipeline_combination",
                **row,
                "ordered_events": "d810>ddserver>session_manager>s10>assert",
                "expected_invariant": "pipeline_converges_once_and_trace_is_complete",
            }
        )
    output_rows.extend(race_rows())
    result = {
        "pipeline_layers": len(PIPELINE_DOMAINS),
        "pipeline_combinations": base_count,
        "pipeline_rows": len(pipeline_rows),
        "secondary_valid_pairs": len(requirements),
        "secondary_covered_pairs": len(covered & requirements),
        "secondary_pair_coverage_percent": len(covered & requirements) * 100.0 / len(requirements),
        "ordered_race_rows": len(RACE_CASES),
        "total_rows": len(output_rows),
        "physical_shutter_actions": 0,
        "seed": seed,
    }
    return result, output_rows


def write_csv(path: Path, rows: Sequence[Mapping[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = (
        "case_id", "case_type", *FACTOR_NAMES, "ordered_events", "expected_invariant"
    )
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=810)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result, rows = calculate(args.seed)
    if args.output:
        write_csv(args.output, rows)
        result["output"] = str(args.output)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for name, value in result.items():
            print(f"{name}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
