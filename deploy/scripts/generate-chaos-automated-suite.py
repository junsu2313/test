#!/usr/bin/env python3
"""Generate a pipeline suite with only two manual camera interventions."""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import random
from pathlib import Path


SOFTWARE = {
    "ddserver": ("healthy", "term_recover", "restart_during_request"),
    "session_manager": ("stable", "bridge_term_recover", "stale_session_repair", "websocket_reconnect"),
    "s10": ("foreground", "wifi_reconnect", "background_resume", "force_stop_relaunch"),
}
SECONDARY = {
    "d810": ("ready", "standby_wake"),
    "operating_mode": ("remote_idle", "liveview"),
    "log_profile": ("normal", "trace_burst", "rotation_boundary"),
    "delivery_profile": ("normal", "backlog_recovery", "puller_restart"),
}
DOMAINS = {"d810": SECONDARY["d810"], **SOFTWARE, **{k: v for k, v in SECONDARY.items() if k != "d810"}}
NAMES = tuple(DOMAINS)
INDEX = {name: index for index, name in enumerate(NAMES)}


def valid(row):
    return row["session_manager"] != "websocket_reconnect" or row["operating_mode"] == "liveview"


def pair(left, lv, right, rv):
    return (left, lv, right, rv) if INDEX[left] < INDEX[right] else (right, rv, left, lv)


def pairs(row):
    return {pair(a, row[a], b, row[b]) for a, b in itertools.combinations(NAMES, 2)}


def candidates():
    result = []
    for values in itertools.product(*(DOMAINS[name] for name in NAMES)):
        row = dict(zip(NAMES, values))
        if valid(row):
            result.append(row)
    return result


def automated_rows(seed=810):
    pool = candidates()
    requirements = set().union(*(pairs(row) for row in pool))
    uncovered = set(requirements)
    grouped = {}
    for row in pool:
        key = tuple(row[name] for name in SOFTWARE)
        grouped.setdefault(key, []).append(row)
    rng = random.Random(seed)
    baseline_key = tuple(values[0] for values in SOFTWARE.values())
    baseline = {name: values[0] for name, values in DOMAINS.items()}
    selected = [baseline]
    uncovered -= pairs(baseline)
    keys = [key for key in grouped if key != baseline_key]
    rng.shuffle(keys)
    for key in keys:
        scored = [(len(pairs(row) & uncovered), rng.random(), row) for row in grouped[key]]
        row = max(scored, key=lambda item: (item[0], item[1]))[2]
        selected.append(row)
        uncovered -= pairs(row)
    while uncovered:
        row = max(pool, key=lambda item: len(pairs(item) & uncovered))
        gain = pairs(row) & uncovered
        if not gain:
            raise RuntimeError("secondary pair coverage cannot be completed")
        selected.append(row)
        uncovered -= gain
    return selected, requirements


def physical_phase(prefix, first_condition, post_condition):
    rows = []
    sessions = SOFTWARE["session_manager"]
    phones = SOFTWARE["s10"]
    dd_values = SOFTWARE["ddserver"]
    for session_index, session in enumerate(sessions):
        for phone_index, phone in enumerate(phones):
            index = len(rows)
            rows.append({
                "case_id": f"{prefix}-{index + 1:03d}",
                "case_type": "physical_phase" if index == 0 else "post_physical",
                "d810": first_condition if index == 0 else post_condition,
                "ddserver": dd_values[(session_index + phone_index) % len(dd_values)],
                "session_manager": session,
                "s10": phone,
                "operating_mode": "liveview" if session == "websocket_reconnect" or (index % 2) else "remote_idle",
                "log_profile": ("normal", "trace_burst", "rotation_boundary")[index % 3],
                "delivery_profile": ("normal", "backlog_recovery", "puller_restart")[(index // 3) % 3],
                "ordered_events": "d810_boundary_once>ddserver>session_manager>s10>assert",
                "expected_invariant": "physical_epoch_remains_ready_and_pipeline_converges",
            })
    return rows


RACES = (
    ("RACE-01", "request_begin>ddserver_term>detect>ddserver_recover>request_retry"),
    ("RACE-02", "ddserver_term>request_begin>detect>ddserver_recover>request_retry"),
    ("RACE-03", "request_begin>bridge_term>action_guard>bridge_recover>response"),
    ("RACE-04", "bridge_term>guardian_detect>session_health_probe>bridge_recover"),
    ("RACE-05", "bridge_term>session_health_probe>guardian_detect>bridge_recover"),
    ("RACE-06", "bridge_term>guardian_detect+session_health_probe>single_bridge_recover"),
    ("RACE-07", "s10_reconnect>session_recreate>websocket_attach>ready"),
    ("RACE-08", "session_recreate>s10_reconnect>websocket_attach>ready"),
    ("RACE-09", "s10_reconnect+session_recreate>single_websocket_attach>ready"),
    ("RACE-10", "checkpoint_begin>forced_reboot>boot_ready>checkpoint_retry>outbox_ready"),
    ("RACE-11", "transfer_begin>puller_term>stale_lock_recover>transfer_retry>hash_ack"),
    ("RACE-12", "log_rotation+checkpoint_begin>atomic_ready>hash_verify>ack"),
)


def calculate(seed=810, unattended=False):
    auto, requirements = automated_rows(seed)
    output = []
    for index, row in enumerate(auto, 1):
        row = dict(row)
        if unattended and row["s10"] == "wifi_reconnect":
            row["s10"] = "wireless_continuity"
        output.append({
            "case_id": f"AUTO-{index:03d}", "case_type": "automated_pipeline", **row,
            "ordered_events": "d810>ddserver>session_manager>s10>assert",
            "expected_invariant": "pipeline_converges_once_and_trace_is_complete",
        })
    if not unattended:
        output.extend(physical_phase("PWR", "power_cycle_recover", "post_power_cycle_recover"))
        output.extend(physical_phase("USB", "usb_reconnect", "post_usb_reconnect"))
    for case_id, events in RACES:
        output.append({
            "case_id": case_id, "case_type": "ordered_race", "d810": "ready",
            "ddserver": "healthy", "session_manager": "stable", "s10": "foreground",
            "operating_mode": "liveview" if case_id in {"RACE-07", "RACE-08", "RACE-09"} else "remote_idle",
            "log_profile": "rotation_boundary" if case_id == "RACE-12" else "normal",
            "delivery_profile": "puller_restart" if case_id == "RACE-11" else "normal",
            "ordered_events": events,
            "expected_invariant": "pipeline_converges_once_and_trace_is_complete",
        })
    covered = set().union(*(pairs(row) for row in auto))
    result = {
        "automated_software_combinations": 48,
        "automated_rows": len(auto),
        "automated_valid_pairs": len(requirements),
        "automated_covered_pairs": len(covered & requirements),
        "physical_phase_rows": 0 if unattended else 32,
        "manual_interventions": 0 if unattended else 2,
        "ordered_races": len(RACES),
        "total_rows": len(output),
        "physical_shutter_actions": 0,
        "seed": seed,
        "unattended": unattended,
    }
    return result, output


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ("case_id", "case_type", *NAMES, "ordered_events", "expected_invariant")
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=810)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--unattended", action="store_true")
    args = parser.parse_args()
    result, rows = calculate(args.seed, unattended=args.unattended)
    if args.output:
        write_csv(args.output, rows); result["output"] = str(args.output)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for name, value in result.items(): print(f"{name}={value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
