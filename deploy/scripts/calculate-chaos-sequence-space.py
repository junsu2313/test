#!/usr/bin/env python3
"""Count valid high-order fault traces around the camera workflow.

This is a constrained permutation model, not a snapshot combination model.
The program workflow keeps its real order while fault injection/recovery events
may interleave only inside their meaningful windows.
"""

from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class Step:
    name: str
    blocked_by: tuple[str, ...] = ()
    final: bool = False


@dataclass(frozen=True)
class Fault:
    name: str
    inject_event: str
    recover_event: str
    inject_after: str
    inject_before: str


@dataclass(frozen=True)
class Profile:
    name: str
    workflow: tuple[Step, ...]
    faults: tuple[Fault, ...]
    contexts: int
    description: str


WORKFLOW = (
    Step("baseline_observe"),
    Step("session_open", ("camera_power", "ddserver", "bridge", "s10_lifecycle", "s10_network")),
    Step("request_begin", ("camera_power", "ddserver", "bridge", "websocket", "s10_lifecycle", "s10_network")),
    Step("camera_command", ("camera_power", "ddserver", "bridge")),
    Step("response_recorded", ("camera_power", "ddserver", "bridge")),
    Step("checkpoint_begin"),
    Step("checkpoint_commit", ("checkpoint_worker", "opal_power")),
    Step("outbox_ready", ("opal_power",)),
    Step("transfer_begin", ("pc_path", "puller", "opal_power")),
    Step("transfer_verify", ("pc_path", "puller", "opal_power")),
    Step("transfer_ack", ("pc_path", "puller", "opal_power")),
    Step("final_assert", final=True),
)


def fault(name: str, after: str, before: str) -> Fault:
    return Fault(name, f"inject:{name}", f"recover:{name}", after, before)


RUNTIME_DENSE = Profile(
    name="runtime_dense",
    workflow=WORKFLOW,
    faults=(
        fault("camera_power", "baseline_observe", "checkpoint_begin"),
        fault("ddserver", "baseline_observe", "checkpoint_begin"),
        fault("bridge", "baseline_observe", "checkpoint_begin"),
        fault("websocket", "baseline_observe", "checkpoint_begin"),
        fault("supervisor", "baseline_observe", "checkpoint_begin"),
        fault("s10_lifecycle", "baseline_observe", "checkpoint_begin"),
        fault("s10_network", "baseline_observe", "checkpoint_begin"),
        fault("pc_path", "baseline_observe", "transfer_ack"),
        fault("puller", "baseline_observe", "transfer_ack"),
        fault("checkpoint_worker", "checkpoint_begin", "checkpoint_commit"),
    ),
    # operating_mode(3) x log_pressure(3). These alter the environment but not
    # the event precedence relation, so they are counted as trace contexts.
    contexts=9,
    description="All safe non-reboot fault episodes across runtime, client, logging, and collection layers.",
)


REBOOT_CHECKPOINT = Profile(
    name="reboot_checkpoint",
    workflow=WORKFLOW,
    faults=(
        fault("opal_power", "checkpoint_begin", "checkpoint_commit"),
        fault("s10_lifecycle", "baseline_observe", "checkpoint_begin"),
        fault("s10_network", "baseline_observe", "checkpoint_begin"),
        fault("pc_path", "baseline_observe", "transfer_ack"),
        fault("puller", "baseline_observe", "transfer_ack"),
    ),
    contexts=9,
    description="Forced reboot during checkpoint, with client and collector faults allowed to overlap.",
)


PROFILES = (RUNTIME_DENSE, REBOOT_CHECKPOINT)


def stage(code: int, index: int) -> int:
    return (code // (3**index)) % 3


def set_stage(code: int, index: int, value: int) -> int:
    old = stage(code, index)
    return code + (value - old) * (3**index)


def all_recovered(code: int, count: int) -> bool:
    return code == 3**count - 1


def active_names(profile: Profile, code: int) -> set[str]:
    return {item.name for index, item in enumerate(profile.faults) if stage(code, index) == 1}


def transitions(profile: Profile, progress: int, code: int) -> list[tuple[str, int, int]]:
    result: list[tuple[str, int, int]] = []
    indexes = {item.name: index for index, item in enumerate(profile.workflow)}
    active = active_names(profile, code)

    if progress < len(profile.workflow):
        current = profile.workflow[progress]
        if not (active & set(current.blocked_by)):
            if not current.final or all_recovered(code, len(profile.faults)):
                result.append((current.name, progress + 1, code))

    for index, item in enumerate(profile.faults):
        current_stage = stage(code, index)
        if current_stage == 0:
            after_complete = progress > indexes[item.inject_after]
            before_incomplete = progress <= indexes[item.inject_before]
            if after_complete and before_incomplete:
                result.append((item.inject_event, progress, set_stage(code, index, 1)))
        elif current_stage == 1:
            result.append((item.recover_event, progress, set_stage(code, index, 2)))
    return result


def count_peak_distribution(profile: Profile) -> tuple[int, ...]:
    """Return exact trace counts indexed by maximum simultaneous faults."""

    @lru_cache(maxsize=None)
    def visit(progress: int, code: int) -> tuple[int, ...]:
        active_count = len(active_names(profile, code))
        if progress == len(profile.workflow) and all_recovered(code, len(profile.faults)):
            terminal = [0] * (len(profile.faults) + 1)
            terminal[active_count] = 1
            return tuple(terminal)

        totals = [0] * (len(profile.faults) + 1)
        for _, next_progress, next_code in transitions(profile, progress, code):
            for child_peak, count in enumerate(visit(next_progress, next_code)):
                if count:
                    totals[max(active_count, child_peak)] += count
        return tuple(totals)

    return visit(0, 0)


def count_equivalence_classes(profile: Profile) -> int:
    """Count macro-order traces after quotienting internal event order.

    Between two workflow steps, independent fault changes form one unordered
    batch. A fault may stay unchanged, become active, recover, or be injected
    and recovered as one pulse in that batch. Different macro boundaries stay
    distinct, while permutations inside a boundary collapse to one class.
    """

    indexes = {item.name: index for index, item in enumerate(profile.workflow)}
    counts: dict[int, int] = {0: 1}

    for progress, workflow_step in enumerate(profile.workflow):
        # Apply one unordered batch in the gap immediately before this fixed
        # workflow step. Processing factors separately is a dynamic-programming
        # implementation; it does not assign an order to the resulting batch.
        for fault_index, item in enumerate(profile.faults):
            eligible = (
                progress > indexes[item.inject_after]
                and progress <= indexes[item.inject_before]
            )
            next_counts: dict[int, int] = {}
            for code, count in counts.items():
                current = stage(code, fault_index)
                if current == 0 and eligible:
                    targets = (0, 1, 2)
                elif current == 1:
                    targets = (1, 2)
                else:
                    targets = (current,)
                for target in targets:
                    next_code = set_stage(code, fault_index, target)
                    next_counts[next_code] = next_counts.get(next_code, 0) + count
            counts = next_counts

        filtered: dict[int, int] = {}
        for code, count in counts.items():
            active = active_names(profile, code)
            if active & set(workflow_step.blocked_by):
                continue
            if workflow_step.final and not all_recovered(code, len(profile.faults)):
                continue
            filtered[code] = filtered.get(code, 0) + count
        counts = filtered

    return counts.get(3 ** len(profile.faults) - 1, 0)


def find_trace(profile: Profile, target_peak: int) -> list[str]:
    """Find one deterministic valid trace whose peak equals target_peak."""

    dead: set[tuple[int, int, int]] = set()

    def visit(progress: int, code: int, peak: int) -> list[str] | None:
        key = (progress, code, peak)
        if key in dead:
            return None
        if progress == len(profile.workflow) and all_recovered(code, len(profile.faults)):
            return [] if peak == target_peak else None

        options = transitions(profile, progress, code)
        options.sort(key=lambda item: (not item[0].startswith("inject:"), item[0]))
        for event, next_progress, next_code in options:
            next_peak = max(peak, len(active_names(profile, next_code)))
            if next_peak > target_peak:
                continue
            suffix = visit(next_progress, next_code, next_peak)
            if suffix is not None:
                return [event, *suffix]
        dead.add(key)
        return None

    found = visit(0, 0, 0)
    if found is None:
        raise RuntimeError(f"no trace reaches peak={target_peak} for {profile.name}")
    return found


def replay(profile: Profile, events: Iterable[str]) -> tuple[int, int, int]:
    progress = 0
    code = 0
    peak = 0
    for event in events:
        options = {name: (next_progress, next_code) for name, next_progress, next_code in transitions(profile, progress, code)}
        if event not in options:
            raise ValueError(f"invalid event {event!r} at progress={progress}, code={code}")
        progress, code = options[event]
        peak = max(peak, len(active_names(profile, code)))
    return progress, code, peak


def analyze(profile: Profile) -> tuple[dict, list[str]]:
    distribution = count_peak_distribution(profile)
    total = sum(distribution)
    max_peak = max(index for index, count in enumerate(distribution) if count)
    trace = find_trace(profile, max_peak)
    equivalence_classes = count_equivalence_classes(profile)
    result = {
        "profile": profile.name,
        "workflow_steps": len(profile.workflow),
        "fault_episodes": len(profile.faults),
        "events_per_complete_trace": len(profile.workflow) + 2 * len(profile.faults),
        "trace_contexts": profile.contexts,
        "valid_event_orders_per_context": total,
        "valid_event_orders_all_contexts": total * profile.contexts,
        "equivalence_classes_per_context": equivalence_classes,
        "equivalence_classes_all_contexts": equivalence_classes * profile.contexts,
        "ordered_to_equivalence_ratio": total / equivalence_classes,
        "maximum_simultaneous_faults": max_peak,
        "max_overlap_orders_per_context": distribution[max_peak],
        "peak_distribution": {str(index): count for index, count in enumerate(distribution) if count},
    }
    return result, trace


def write_samples(path: Path, analyses: list[tuple[dict, list[str]]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.writer(stream)
        writer.writerow(("profile", "event_index", "event"))
        for result, trace in analyses:
            for index, event in enumerate(trace, 1):
                writer.writerow((result["profile"], index, event))


def write_buckets(path: Path, analyses: list[tuple[dict, list[str]]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=("profile", "before_step", "inject_set", "recover_set"))
        writer.writeheader()
        for result, trace in analyses:
            for bucket in canonical_buckets(next(item for item in PROFILES if item.name == result["profile"]), trace):
                writer.writerow({"profile": result["profile"], **bucket})


def canonical_buckets(profile: Profile, trace: Iterable[str]) -> list[dict[str, str]]:
    """Collapse one linear trace into unordered fault batches at macro boundaries."""

    workflow_names = {item.name for item in profile.workflow}
    injections: list[str] = []
    recoveries: list[str] = []
    buckets: list[dict[str, str]] = []
    for event in trace:
        if event.startswith("inject:"):
            injections.append(event.removeprefix("inject:"))
        elif event.startswith("recover:"):
            recoveries.append(event.removeprefix("recover:"))
        elif event in workflow_names:
            buckets.append(
                {
                    "before_step": event,
                    "inject_set": "+".join(sorted(injections)) or "none",
                    "recover_set": "+".join(sorted(recoveries)) or "none",
                }
            )
            injections.clear()
            recoveries.clear()
    return buckets


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", choices=("all", *(item.name for item in PROFILES)), default="all")
    parser.add_argument("--samples", type=Path)
    parser.add_argument("--buckets", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    selected = PROFILES if args.profile == "all" else tuple(item for item in PROFILES if item.name == args.profile)
    analyses = [analyze(profile) for profile in selected]
    if args.samples:
        write_samples(args.samples, analyses)
    if args.buckets:
        write_buckets(args.buckets, analyses)
    payload = {"profiles": [result for result, _ in analyses]}
    payload["valid_event_orders_all_profiles_and_contexts"] = sum(
        result["valid_event_orders_all_contexts"] for result, _ in analyses
    )
    payload["equivalence_classes_all_profiles_and_contexts"] = sum(
        result["equivalence_classes_all_contexts"] for result, _ in analyses
    )
    if args.samples:
        payload["samples"] = str(args.samples)
    if args.buckets:
        payload["buckets"] = str(args.buckets)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        for result, _ in analyses:
            print(
                f"{result['profile']}: orders={result['valid_event_orders_per_context']} "
                f"classes={result['equivalence_classes_per_context']} "
                f"contexts={result['trace_contexts']} max_overlap={result['maximum_simultaneous_faults']}"
            )
        print(f"all_context_orders={payload['valid_event_orders_all_profiles_and_contexts']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
