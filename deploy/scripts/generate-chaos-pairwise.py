#!/usr/bin/env python3
"""Generate a deterministic constrained pairwise fault-injection suite.

The 26-factor snapshot model describes observed system states. This model uses
only controllable test inputs. Unsafe conditions such as USB overcurrent and a
fully exhausted filesystem are deliberately absent.
"""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import math
import random
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Callable, Mapping, Sequence


DOMAINS: dict[str, tuple[str, ...]] = {
    "operating_mode": ("body_ready", "remote_idle", "liveview"),
    "camera_power_cycle": ("stable", "standby_wake", "off_on"),
    "ddserver_fault": ("none", "term", "service_restart"),
    "bridge_fault": ("none", "term", "hang", "service_restart"),
    "websocket_fault": ("none", "term", "stale_connection"),
    "supervisor_fault": (
        "none",
        "runtime_guardian_term",
        "session_health_term",
        "battery_worker_term",
        "boot_watch_term",
    ),
    "s10_lifecycle": ("foreground", "background", "force_stopped", "doze_resume"),
    "s10_network": ("healthy", "disconnect_reconnect", "degraded"),
    "pc_path": ("both_available", "local_only", "tailscale_only", "offline_then_return"),
    "log_pressure": ("normal", "trace_burst", "rotation_boundary"),
    "checkpoint_mode": ("normal", "concurrent", "process_term", "interrupted_by_reboot"),
    "outbox_mode": ("normal", "backlog_recovery", "puller_term_during_download", "stale_lock_recovery"),
    "opal_power_event": ("stable", "graceful_reboot", "forced_reboot_no_sync"),
    "fault_timing": ("steady", "during_request", "during_recovery", "during_transfer", "during_checkpoint"),
}

BASELINE = {name: values[0] for name, values in DOMAINS.items()}
FACTOR_NAMES = tuple(DOMAINS)
FACTOR_INDEX = {name: index for index, name in enumerate(FACTOR_NAMES)}


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


PROCESS_FAULTS = ("ddserver_fault", "bridge_fault", "websocket_fault", "supervisor_fault")


@rule("reboot_replaces_explicit_process_faults", ("opal_power_event",) + PROCESS_FAULTS)
def _reboot_process_faults(a):
    if a["opal_power_event"] == "stable":
        return True
    return all(a[name] == "none" for name in PROCESS_FAULTS)


@rule("interrupted_checkpoint_requires_forced_reboot", ("checkpoint_mode", "opal_power_event", "fault_timing"))
def _interrupted_checkpoint(a):
    if a["checkpoint_mode"] != "interrupted_by_reboot":
        return True
    return a["opal_power_event"] == "forced_reboot_no_sync" and a["fault_timing"] == "during_checkpoint"


@rule("forced_checkpoint_timing_requires_checkpoint_work", ("checkpoint_mode", "fault_timing"))
def _checkpoint_timing(a):
    return a["fault_timing"] != "during_checkpoint" or a["checkpoint_mode"] != "normal"


@rule("checkpoint_process_term_occurs_during_checkpoint", ("checkpoint_mode", "fault_timing"))
def _checkpoint_term_timing(a):
    return a["checkpoint_mode"] != "process_term" or a["fault_timing"] == "during_checkpoint"


@rule("graceful_reboot_does_not_interrupt_checkpoint", ("checkpoint_mode", "opal_power_event"))
def _graceful_checkpoint(a):
    return not (
        a["opal_power_event"] == "graceful_reboot"
        and a["checkpoint_mode"] == "interrupted_by_reboot"
    )


@rule("download_termination_occurs_during_transfer", ("outbox_mode", "fault_timing"))
def _puller_term_timing(a):
    return a["outbox_mode"] != "puller_term_during_download" or a["fault_timing"] == "during_transfer"


@rule("transfer_timing_requires_active_transfer", ("outbox_mode", "fault_timing"))
def _transfer_timing(a):
    return a["fault_timing"] != "during_transfer" or a["outbox_mode"] in {
        "backlog_recovery",
        "puller_term_during_download",
    }


@rule("stale_websocket_requires_client_disruption", ("websocket_fault", "s10_lifecycle", "s10_network"))
def _stale_websocket(a):
    return a["websocket_fault"] != "stale_connection" or (
        a["s10_lifecycle"] != "foreground" or a["s10_network"] != "healthy"
    )


@rule(
    "recovery_timing_requires_a_prior_fault",
    (
        "fault_timing",
        "camera_power_cycle",
        "ddserver_fault",
        "bridge_fault",
        "websocket_fault",
        "supervisor_fault",
        "s10_lifecycle",
        "s10_network",
        "pc_path",
        "checkpoint_mode",
        "outbox_mode",
        "opal_power_event",
    ),
)
def _recovery_needs_fault(a):
    if a["fault_timing"] != "during_recovery":
        return True
    return any(
        (
            a["camera_power_cycle"] != "stable",
            a["ddserver_fault"] != "none",
            a["bridge_fault"] != "none",
            a["websocket_fault"] != "none",
            a["supervisor_fault"] != "none",
            a["s10_lifecycle"] in {"force_stopped", "doze_resume"},
            a["s10_network"] != "healthy",
            a["pc_path"] == "offline_then_return",
            a["checkpoint_mode"] != "normal",
            a["outbox_mode"] != "normal",
            a["opal_power_event"] != "stable",
        )
    )


CONSTRAINTS_BY_VARIABLE: dict[str, list[Constraint]] = {name: [] for name in DOMAINS}
for constraint in CONSTRAINTS:
    for name in constraint.scope:
        CONSTRAINTS_BY_VARIABLE[name].append(constraint)


def partial_valid(assignment: Mapping[str, str], changed: str | None = None) -> bool:
    constraints = CONSTRAINTS if changed is None else CONSTRAINTS_BY_VARIABLE[changed]
    for constraint in constraints:
        if all(name in assignment for name in constraint.scope) and not constraint.predicate(assignment):
            return False
    return True


def row_valid(row: Mapping[str, str]) -> bool:
    return set(row) == set(DOMAINS) and partial_valid(row)


def assignment_key(assignment: Mapping[str, str]) -> tuple[tuple[str, str], ...]:
    return tuple(sorted(assignment.items(), key=lambda item: FACTOR_INDEX[item[0]]))


@lru_cache(maxsize=None)
def deterministic_completion(key: tuple[tuple[str, str], ...]) -> tuple[tuple[str, str], ...] | None:
    assignment = dict(key)
    if not partial_valid(assignment):
        return None
    if len(assignment) == len(DOMAINS):
        return assignment_key(assignment)
    unassigned = [name for name in FACTOR_NAMES if name not in assignment]
    name = max(
        unassigned,
        key=lambda field: (len(CONSTRAINTS_BY_VARIABLE[field]), -len(DOMAINS[field]), -FACTOR_INDEX[field]),
    )
    values = sorted(DOMAINS[name], key=lambda value: value != BASELINE[name])
    for value in values:
        assignment[name] = value
        if partial_valid(assignment, name):
            result = deterministic_completion(assignment_key(assignment))
            if result is not None:
                return result
        del assignment[name]
    return None


Pair = tuple[str, str, str, str]


def pair_key(left: str, left_value: str, right: str, right_value: str) -> Pair:
    if FACTOR_INDEX[left] < FACTOR_INDEX[right]:
        return left, left_value, right, right_value
    return right, right_value, left, left_value


def row_pairs(row: Mapping[str, str]) -> set[Pair]:
    return {
        pair_key(left, row[left], right, row[right])
        for left, right in itertools.combinations(FACTOR_NAMES, 2)
    }


def valid_pairs() -> set[Pair]:
    pairs: set[Pair] = set()
    for left, right in itertools.combinations(FACTOR_NAMES, 2):
        for left_value in DOMAINS[left]:
            for right_value in DOMAINS[right]:
                partial = {left: left_value, right: right_value}
                if deterministic_completion(assignment_key(partial)) is not None:
                    pairs.add(pair_key(left, left_value, right, right_value))
    return pairs


def randomized_completion(
    partial: Mapping[str, str], uncovered: set[Pair], rng: random.Random
) -> dict[str, str] | None:
    assignment = dict(partial)
    if not partial_valid(assignment):
        return None

    def visit() -> bool:
        if len(assignment) == len(DOMAINS):
            return True
        unassigned = [name for name in FACTOR_NAMES if name not in assignment]
        # Variables participating in more still-uncovered pairs are filled first.
        def variable_score(name: str) -> tuple[int, int, float]:
            opportunities = 0
            for other, other_value in assignment.items():
                for value in DOMAINS[name]:
                    if pair_key(name, value, other, other_value) in uncovered:
                        opportunities += 1
            return opportunities, len(CONSTRAINTS_BY_VARIABLE[name]), rng.random()

        name = max(unassigned, key=variable_score)
        scored_values = []
        for value in DOMAINS[name]:
            score = sum(
                pair_key(name, value, other, other_value) in uncovered
                for other, other_value in assignment.items()
            )
            baseline_bonus = 0.05 if value == BASELINE[name] else 0.0
            scored_values.append((score + baseline_bonus, rng.random(), value))
        scored_values.sort(reverse=True)
        for _, _, value in scored_values:
            assignment[name] = value
            if partial_valid(assignment, name) and visit():
                return True
            del assignment[name]
        return False

    return assignment if visit() else None


def generate(seed: int, candidate_count: int = 48) -> tuple[list[dict[str, str]], set[Pair]]:
    requirements = valid_pairs()
    baseline_completion = deterministic_completion(assignment_key(BASELINE))
    if baseline_completion is None:
        raise RuntimeError("baseline is invalid")
    baseline_row = dict(baseline_completion)
    rng = random.Random(seed)

    # A deterministic completion for every valid pair guarantees that the
    # candidate pool can cover 100%. Random valid rows improve packing quality.
    candidates: dict[tuple[tuple[str, str], ...], dict[str, str]] = {
        assignment_key(baseline_row): baseline_row
    }
    for target in sorted(requirements):
        partial = {target[0]: target[1], target[2]: target[3]}
        completion = deterministic_completion(assignment_key(partial))
        if completion is None:
            raise RuntimeError(f"valid pair has no completion: {target}")
        candidates.setdefault(completion, dict(completion))

    random_target = max(1000, candidate_count * 100)
    accepted = 0
    attempts = 0
    while accepted < random_target and attempts < random_target * 30:
        attempts += 1
        row = {name: rng.choice(DOMAINS[name]) for name in FACTOR_NAMES}
        if not row_valid(row):
            continue
        key = assignment_key(row)
        if key not in candidates:
            candidates[key] = row
            accepted += 1

    pair_list = sorted(requirements)
    pair_index = {pair: index for index, pair in enumerate(pair_list)}
    full_mask = (1 << len(pair_list)) - 1

    def mask_for(row: Mapping[str, str]) -> int:
        mask = 0
        for pair in row_pairs(row) & requirements:
            mask |= 1 << pair_index[pair]
        return mask

    baseline_mask = mask_for(baseline_row)
    pool = [
        (row, mask_for(row))
        for key, row in candidates.items()
        if key != assignment_key(baseline_row)
    ]
    rows = [baseline_row]
    masks = [baseline_mask]
    uncovered_mask = full_mask & ~baseline_mask
    while uncovered_mask:
        best_index = -1
        best_score = 0
        for index, (_, mask) in enumerate(pool):
            score = (mask & uncovered_mask).bit_count()
            if score > best_score:
                best_index = index
                best_score = score
        if best_index < 0:
            raise RuntimeError("candidate pool cannot complete pairwise coverage")
        row, mask = pool.pop(best_index)
        rows.append(row)
        masks.append(mask)
        uncovered_mask &= ~mask

    # Remove redundant rows while preserving the explicit baseline row.
    changed = True
    while changed:
        changed = False
        for index in range(len(rows) - 1, 0, -1):
            combined = 0
            for other_index, mask in enumerate(masks):
                if other_index != index:
                    combined |= mask
            if combined == full_mask:
                rows.pop(index)
                masks.pop(index)
                changed = True
    return rows, requirements


def exact_valid_control_count() -> int:
    # The recovery predicate spans twelve factors but rejects only the case
    # "during_recovery with no preceding fault". Count the smaller graph made
    # by every other rule, then subtract that predicate's 18 invalid rows.
    recovery_name = "recovery_timing_requires_a_prior_fault"
    local_constraints = [c for c in CONSTRAINTS if c.name != recovery_name]

    graph: dict[str, set[str]] = {name: set() for name in FACTOR_NAMES}
    for constraint in local_constraints:
        for left in constraint.scope:
            graph[left].update(right for right in constraint.scope if right != left)

    unseen = set(FACTOR_NAMES)
    components: list[tuple[str, ...]] = []
    while unseen:
        root = unseen.pop()
        stack = [root]
        found = []
        while stack:
            node = stack.pop()
            found.append(node)
            for neighbor in graph[node]:
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    stack.append(neighbor)
        components.append(tuple(found))

    def count_component(component: tuple[str, ...]) -> int:
        relevant = [c for c in local_constraints if set(c.scope).issubset(component)]
        by_variable = {name: [] for name in component}
        for constraint in relevant:
            for name in constraint.scope:
                by_variable[name].append(constraint)
        order = sorted(
            component,
            key=lambda name: (-len(by_variable[name]), len(DOMAINS[name]), FACTOR_INDEX[name]),
        )
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

        return visit(0)

    without_recovery_rule = math.prod(count_component(component) for component in components)

    no_prior_fault_domains = {name: values for name, values in DOMAINS.items()}
    no_prior_fault_domains.update(
        {
            "camera_power_cycle": ("stable",),
            "ddserver_fault": ("none",),
            "bridge_fault": ("none",),
            "websocket_fault": ("none",),
            "supervisor_fault": ("none",),
            "s10_lifecycle": ("foreground", "background"),
            "s10_network": ("healthy",),
            "pc_path": ("both_available", "local_only", "tailscale_only"),
            "checkpoint_mode": ("normal",),
            "outbox_mode": ("normal",),
            "opal_power_event": ("stable",),
            "fault_timing": ("during_recovery",),
        }
    )
    invalid_recovery_rows = 0
    for values in itertools.product(*(no_prior_fault_domains[name] for name in FACTOR_NAMES)):
        row = dict(zip(FACTOR_NAMES, values))
        if all(constraint.predicate(row) for constraint in local_constraints):
            invalid_recovery_rows += 1
    return without_recovery_rule - invalid_recovery_rows


def write_csv(path: Path, rows: Sequence[Mapping[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=("case_id",) + FACTOR_NAMES)
        writer.writeheader()
        for index, row in enumerate(rows, 1):
            writer.writerow({"case_id": f"PW-{index:03d}", **row})


def calculate(seed: int, candidate_count: int = 48) -> tuple[dict, list[dict[str, str]]]:
    rows, requirements = generate(seed, candidate_count)
    covered = set().union(*(row_pairs(row) for row in rows)) if rows else set()
    raw = math.prod(len(values) for values in DOMAINS.values())
    valid = exact_valid_control_count()
    result = {
        "factors": len(DOMAINS),
        "constraints": len(CONSTRAINTS),
        "raw_control_combinations": raw,
        "valid_control_combinations": valid,
        "valid_pairs": len(requirements),
        "pairwise_rows": len(rows),
        "covered_pairs": len(covered & requirements),
        "coverage_percent": len(covered & requirements) * 100.0 / len(requirements),
        "seed": seed,
    }
    return result, rows


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=810)
    parser.add_argument("--candidates", type=int, default=48)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result, rows = calculate(args.seed, args.candidates)
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
