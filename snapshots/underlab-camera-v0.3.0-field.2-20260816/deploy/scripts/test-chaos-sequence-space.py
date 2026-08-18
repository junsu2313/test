#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


SCRIPT = Path(__file__).with_name("calculate-chaos-sequence-space.py")
spec = importlib.util.spec_from_file_location("chaos_sequence", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)


analyses = {profile.name: module.analyze(profile) for profile in module.PROFILES}
for profile in module.PROFILES:
    result, trace = analyses[profile.name]
    assert result["valid_event_orders_per_context"] > 0
    assert result["events_per_complete_trace"] == len(trace)
    assert result["maximum_simultaneous_faults"] == len(profile.faults)
    assert result["max_overlap_orders_per_context"] > 0
    assert 0 < result["equivalence_classes_per_context"] < result["valid_event_orders_per_context"]
    progress, code, peak = module.replay(profile, trace)
    assert progress == len(profile.workflow)
    assert module.all_recovered(code, len(profile.faults))
    assert peak == len(profile.faults)
    workflow_events = [event for event in trace if event in {step.name for step in profile.workflow}]
    assert workflow_events == [step.name for step in profile.workflow]

runtime_result, _ = analyses[module.RUNTIME_DENSE.name]
reboot_result, _ = analyses[module.REBOOT_CHECKPOINT.name]
assert runtime_result["fault_episodes"] == 10
assert reboot_result["fault_episodes"] == 5
assert runtime_result["valid_event_orders_per_context"] == 429109931102476032
assert reboot_result["valid_event_orders_per_context"] == 20436736
assert runtime_result["equivalence_classes_per_context"] == 1578585911760
assert reboot_result["equivalence_classes_per_context"] == 976144
assert "opal_power" not in {fault.name for fault in module.RUNTIME_DENSE.faults}
assert "opal_power" in {fault.name for fault in module.REBOOT_CHECKPOINT.faults}

for profile in module.PROFILES:
    _, trace = analyses[profile.name]
    buckets = module.canonical_buckets(profile, trace)
    assert [bucket["before_step"] for bucket in buckets] == [step.name for step in profile.workflow]
    assert len(buckets) == len(profile.workflow)

print(
    "PASS: constrained sequence model "
    f"runtime={runtime_result['valid_event_orders_per_context']} "
    f"reboot={reboot_result['valid_event_orders_per_context']}"
)
