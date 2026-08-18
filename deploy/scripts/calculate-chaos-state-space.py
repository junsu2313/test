#!/usr/bin/env python3
"""Count valid D810 chaos-test snapshots under explicit logical constraints.

This is a finite, binned model. It intentionally keeps unhealthy states that
fault injection can create, while rejecting states that cannot coexist in one
instant under the definitions below.
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
from collections import defaultdict
from dataclasses import dataclass
from typing import Callable, Dict, Iterable, Mapping, Sequence


DOMAINS: Dict[str, tuple[str, ...]] = {
    # Layer 1: camera / USB / PTP
    "camera_power": ("off", "standby", "awake"),
    "usb_state": ("absent", "enumerating", "present", "overcurrent_latched"),
    "ptp_state": ("closed", "opening", "ready", "busy", "fault"),
    "camera_mode": ("body", "remote_idle", "liveview"),
    # Layer 2: Opal runtime
    "ddserver_state": ("stopped", "starting", "running"),
    "bridge_process": ("stopped", "starting", "running", "hung"),
    "backend_state": ("idle", "connecting", "ready", "live", "degraded", "recovering"),
    "websocket_state": ("stopped", "connecting", "running", "stale"),
    "session_state": ("absent", "booting", "ready", "recovering"),
    # Layer 3: supervision. Each value describes process/PID-file integrity.
    "runtime_guardian": ("stopped", "running", "stale_pid", "duplicate"),
    "session_health": ("stopped", "running", "stale_pid", "duplicate"),
    "battery_worker": ("stopped", "running", "stale_pid", "duplicate"),
    "boot_watch": ("stopped", "running", "stale_pid", "duplicate"),
    # Layer 4: S10
    "s10_app": ("stopped", "background", "foreground"),
    "s10_link": ("disconnected", "connecting", "connected", "recovering"),
    "s10_power": ("awake", "screen_off", "doze"),
    # Layer 5: network
    "s10_wifi": ("disconnected", "associating", "healthy", "degraded"),
    "opal_ap": ("down", "up"),
    "tailscale": ("down", "up"),
    "pc_reachability": ("offline", "online"),
    # Layer 6: logs / storage
    "event_writer": ("idle", "writing", "rotating", "failed"),
    "checkpoint": ("idle", "running", "contended", "failed"),
    "outbox": ("empty", "normal", "backlogged", "damaged"),
    "storage": ("normal", "low", "exhausted"),
    # Layer 7: PC collection
    "puller": ("stopped", "running", "hung", "stale_lock"),
    "transfer": ("idle", "downloading", "verifying", "retrying"),
}


LAYERS: Dict[str, tuple[str, ...]] = {
    "camera_usb_ptp": ("camera_power", "usb_state", "ptp_state", "camera_mode"),
    "opal_runtime": (
        "ddserver_state",
        "bridge_process",
        "backend_state",
        "websocket_state",
        "session_state",
    ),
    "supervision": ("runtime_guardian", "session_health", "battery_worker", "boot_watch"),
    "s10": ("s10_app", "s10_link", "s10_power"),
    "network": ("s10_wifi", "opal_ap", "tailscale", "pc_reachability"),
    "logs_storage": ("event_writer", "checkpoint", "outbox", "storage"),
    "pc_collection": ("puller", "transfer"),
}


@dataclass(frozen=True)
class Constraint:
    name: str
    scope: tuple[str, ...]
    predicate: Callable[[Mapping[str, str]], bool]


CONSTRAINTS: list[Constraint] = []


def rule(name: str, scope: Sequence[str]):
    def register(predicate: Callable[[Mapping[str, str]], bool]):
        CONSTRAINTS.append(Constraint(name, tuple(scope), predicate))
        return predicate

    return register


@rule("camera_off_has_no_enumerated_usb", ("camera_power", "usb_state"))
def _camera_off_usb(a):
    return a["camera_power"] != "off" or a["usb_state"] in {"absent", "overcurrent_latched"}


@rule("usb_enumeration_requires_powered_camera", ("camera_power", "usb_state"))
def _usb_needs_power(a):
    return a["usb_state"] not in {"enumerating", "present"} or a["camera_power"] != "off"


@rule("absent_or_latched_usb_cannot_have_open_ptp", ("usb_state", "ptp_state"))
def _usb_ptp(a):
    return a["usb_state"] not in {"absent", "overcurrent_latched"} or a["ptp_state"] in {"closed", "fault"}


@rule("ptp_opening_requires_enumerated_usb", ("usb_state", "ptp_state"))
def _ptp_opening_usb(a):
    return a["ptp_state"] != "opening" or a["usb_state"] in {"enumerating", "present"}


@rule("ready_or_busy_ptp_requires_present_usb", ("usb_state", "ptp_state"))
def _ptp_ready_usb(a):
    return a["ptp_state"] not in {"ready", "busy"} or a["usb_state"] == "present"


@rule("ready_or_busy_ptp_requires_awake_camera", ("camera_power", "ptp_state"))
def _ptp_ready_power(a):
    return a["ptp_state"] not in {"ready", "busy"} or a["camera_power"] == "awake"


@rule("remote_camera_mode_requires_ptp", ("camera_power", "ptp_state", "camera_mode"))
def _remote_mode(a):
    return a["camera_mode"] == "body" or (
        a["camera_power"] == "awake" and a["ptp_state"] in {"ready", "busy"}
    )


@rule("ptp_opening_requires_ddserver", ("ptp_state", "ddserver_state"))
def _opening_ddserver(a):
    return a["ptp_state"] != "opening" or a["ddserver_state"] in {"starting", "running"}


@rule("ready_or_busy_ptp_requires_running_ddserver", ("ptp_state", "ddserver_state"))
def _ready_ddserver(a):
    return a["ptp_state"] not in {"ready", "busy"} or a["ddserver_state"] == "running"


@rule("stopped_ddserver_has_no_active_ptp", ("ptp_state", "ddserver_state"))
def _stopped_ddserver(a):
    return a["ddserver_state"] != "stopped" or a["ptp_state"] in {"closed", "fault"}


@rule("starting_ddserver_has_no_ready_ptp", ("ptp_state", "ddserver_state"))
def _starting_ddserver(a):
    return a["ddserver_state"] != "starting" or a["ptp_state"] in {"closed", "opening", "fault"}


@rule("stopped_bridge_has_idle_backend", ("bridge_process", "backend_state"))
def _stopped_bridge(a):
    return a["bridge_process"] != "stopped" or a["backend_state"] == "idle"


@rule("starting_bridge_has_transitional_backend", ("bridge_process", "backend_state"))
def _starting_bridge(a):
    return a["bridge_process"] != "starting" or a["backend_state"] in {"idle", "connecting", "recovering"}


@rule("ready_backend_requirements", ("bridge_process", "backend_state", "session_state", "ptp_state", "camera_mode"))
def _ready_backend(a):
    if a["backend_state"] != "ready":
        return True
    return (
        a["bridge_process"] in {"running", "hung"}
        and a["session_state"] == "ready"
        and a["ptp_state"] in {"ready", "busy"}
        and a["camera_mode"] != "liveview"
    )


@rule("live_backend_requirements", ("bridge_process", "backend_state", "session_state", "ptp_state", "camera_mode"))
def _live_backend(a):
    if a["backend_state"] != "live":
        return True
    return (
        a["bridge_process"] in {"running", "hung"}
        and a["session_state"] == "ready"
        and a["ptp_state"] in {"ready", "busy"}
        and a["camera_mode"] == "liveview"
    )


@rule("connecting_backend_requirements", ("bridge_process", "backend_state", "session_state"))
def _connecting_backend(a):
    return a["backend_state"] != "connecting" or (
        a["bridge_process"] in {"starting", "running", "hung"}
        and a["session_state"] in {"booting", "recovering"}
    )


@rule("recovering_backend_requirements", ("bridge_process", "backend_state", "session_state"))
def _recovering_backend(a):
    return a["backend_state"] != "recovering" or (
        a["bridge_process"] in {"starting", "running", "hung"}
        and a["session_state"] in {"booting", "ready", "recovering"}
    )


@rule("session_absence_limits_backend", ("session_state", "backend_state"))
def _absent_session(a):
    return a["session_state"] != "absent" or a["backend_state"] in {"idle", "degraded"}


@rule("recovering_session_limits_backend", ("session_state", "backend_state"))
def _recovering_session(a):
    return a["session_state"] != "recovering" or a["backend_state"] in {"connecting", "degraded", "recovering", "idle"}


@rule("stopped_s10_app_is_disconnected", ("s10_app", "s10_link"))
def _stopped_app(a):
    return a["s10_app"] != "stopped" or a["s10_link"] == "disconnected"


@rule("active_s10_link_requires_running_app", ("s10_app", "s10_link"))
def _active_link_app(a):
    return a["s10_link"] == "disconnected" or a["s10_app"] != "stopped"


@rule("doze_has_no_foreground_app", ("s10_app", "s10_power"))
def _doze_app(a):
    return a["s10_power"] != "doze" or a["s10_app"] != "foreground"


@rule("s10_wifi_requires_opal_ap", ("s10_wifi", "opal_ap"))
def _wifi_ap(a):
    return a["s10_wifi"] == "disconnected" or a["opal_ap"] == "up"


@rule("connected_s10_link_requires_wifi", ("s10_link", "s10_wifi"))
def _connected_link_wifi(a):
    return a["s10_link"] != "connected" or a["s10_wifi"] in {"healthy", "degraded"}


@rule("connecting_s10_link_requires_available_wifi", ("s10_link", "s10_wifi"))
def _connecting_link_wifi(a):
    return a["s10_link"] != "connecting" or a["s10_wifi"] in {"associating", "healthy", "degraded"}


@rule("online_pc_requires_a_route", ("opal_ap", "tailscale", "pc_reachability"))
def _pc_route(a):
    return a["pc_reachability"] != "online" or a["opal_ap"] == "up" or a["tailscale"] == "up"


@rule("exhausted_storage_blocks_event_writes", ("storage", "event_writer"))
def _storage_writer(a):
    return a["storage"] != "exhausted" or a["event_writer"] in {"idle", "failed"}


@rule("exhausted_storage_blocks_checkpoint_work", ("storage", "checkpoint"))
def _storage_checkpoint(a):
    return a["storage"] != "exhausted" or a["checkpoint"] in {"idle", "failed"}


@rule("nonidle_transfer_requires_active_puller", ("puller", "transfer"))
def _transfer_puller(a):
    return a["transfer"] == "idle" or a["puller"] in {"running", "hung"}


@rule("stopped_or_locked_puller_is_idle", ("puller", "transfer"))
def _inactive_puller(a):
    return a["puller"] not in {"stopped", "stale_lock"} or a["transfer"] == "idle"


@rule("active_transfer_requires_online_pc", ("transfer", "pc_reachability"))
def _transfer_network(a):
    return a["transfer"] not in {"downloading", "verifying"} or a["pc_reachability"] == "online"


@rule("active_transfer_requires_remote_payload", ("transfer", "outbox"))
def _transfer_outbox(a):
    return a["transfer"] not in {"downloading", "verifying"} or a["outbox"] != "empty"


@rule("retrying_transfer_has_a_reason", ("transfer", "pc_reachability", "outbox"))
def _retry_reason(a):
    return a["transfer"] != "retrying" or a["pc_reachability"] == "offline" or a["outbox"] == "damaged"


def connected_components() -> list[tuple[str, ...]]:
    graph: dict[str, set[str]] = {name: set() for name in DOMAINS}
    for constraint in CONSTRAINTS:
        for left in constraint.scope:
            graph[left].update(right for right in constraint.scope if right != left)
    components: list[tuple[str, ...]] = []
    unseen = set(DOMAINS)
    while unseen:
        root = next(iter(unseen))
        stack = [root]
        found: list[str] = []
        unseen.remove(root)
        while stack:
            node = stack.pop()
            found.append(node)
            for neighbor in graph[node]:
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    stack.append(neighbor)
        components.append(tuple(found))
    return components


def choose_order(component: Iterable[str], constraints: Sequence[Constraint]) -> tuple[str, ...]:
    # Put highly constrained variables first. Domain size breaks ties so that
    # impossible branches are rejected before wide domains are expanded.
    degree = defaultdict(int)
    for constraint in constraints:
        for name in constraint.scope:
            degree[name] += len(constraint.scope) - 1
    return tuple(sorted(component, key=lambda name: (-degree[name], len(DOMAINS[name]), name)))


def count_component(component: tuple[str, ...]) -> tuple[int, int, tuple[str, ...]]:
    local_constraints = [c for c in CONSTRAINTS if set(c.scope).issubset(component)]
    by_variable: dict[str, list[Constraint]] = defaultdict(list)
    for constraint in local_constraints:
        for name in constraint.scope:
            by_variable[name].append(constraint)
    order = choose_order(component, local_constraints)
    assignment: dict[str, str] = {}

    def visit(index: int) -> int:
        if index == len(order):
            return 1
        name = order[index]
        total = 0
        for value in DOMAINS[name]:
            assignment[name] = value
            valid = True
            for constraint in by_variable[name]:
                if all(field in assignment for field in constraint.scope) and not constraint.predicate(assignment):
                    valid = False
                    break
            if valid:
                total += visit(index + 1)
            del assignment[name]
        return total

    raw = math.prod(len(DOMAINS[name]) for name in component)
    return raw, visit(0), order


def calculate() -> dict:
    layer_raw = {
        layer: math.prod(len(DOMAINS[name]) for name in factors)
        for layer, factors in LAYERS.items()
    }
    raw_total = math.prod(len(values) for values in DOMAINS.values())
    component_rows = []
    valid_total = 1
    for component in connected_components():
        raw, valid, order = count_component(component)
        valid_total *= valid
        component_rows.append(
            {
                "factors": list(component),
                "raw": raw,
                "valid": valid,
                "removed": raw - valid,
                "order": list(order),
            }
        )
    return {
        "layers": len(LAYERS),
        "factors": len(DOMAINS),
        "constraints": len(CONSTRAINTS),
        "layer_raw": layer_raw,
        "raw_total": raw_total,
        "valid_total": valid_total,
        "removed_total": raw_total - valid_total,
        "valid_percent": valid_total * 100.0 / raw_total,
        "components": component_rows,
        "constraint_names": [constraint.name for constraint in CONSTRAINTS],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true", help="emit machine-readable JSON")
    args = parser.parse_args()
    result = calculate()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    print(f"layers={result['layers']} factors={result['factors']} constraints={result['constraints']}")
    print(f"raw_total={result['raw_total']}")
    print(f"valid_total={result['valid_total']}")
    print(f"removed_total={result['removed_total']}")
    print(f"valid_percent={result['valid_percent']:.9f}")
    for index, component in enumerate(result["components"], 1):
        names = ",".join(component["factors"])
        print(
            f"component_{index}=raw:{component['raw']} valid:{component['valid']} "
            f"removed:{component['removed']} factors:{names}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
