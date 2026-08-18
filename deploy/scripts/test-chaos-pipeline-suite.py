#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import itertools
import sys
from pathlib import Path


SCRIPT = Path(__file__).with_name("generate-chaos-pipeline-suite.py")
spec = importlib.util.spec_from_file_location("chaos_pipeline", SCRIPT)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)


result, rows = module.calculate(seed=810)
pipeline_rows = [row for row in rows if row["case_type"] == "pipeline_combination"]
race_rows = [row for row in rows if row["case_type"] == "ordered_race"]

expected_pipeline = set(itertools.product(*(values for values in module.PIPELINE_DOMAINS.values())))
actual_pipeline = {
    tuple(row[name] for name in module.PIPELINE_DOMAINS)
    for row in pipeline_rows
}
assert actual_pipeline == expected_pipeline
assert result["pipeline_combinations"] == 192
assert result["secondary_pair_coverage_percent"] == 100.0
assert result["physical_shutter_actions"] == 0
assert len(race_rows) == 12
assert len({row["case_id"] for row in rows}) == len(rows)
assert rows[0]["case_id"] == "PIPE-001"
assert all(module.valid(row) for row in pipeline_rows)
assert all(row["ordered_events"] for row in race_rows)
assert "overcurrent" not in repr(rows).lower()
assert "exhausted" not in repr(rows).lower()
assert "shutter" not in repr(rows).lower()
assert "capture" not in repr(rows).lower()

result_again, rows_again = module.calculate(seed=810)
assert result_again == result
assert rows_again == rows

print(
    "PASS: hierarchy-aware pipeline suite "
    f"pipeline={result['pipeline_rows']} races={result['ordered_race_rows']} total={result['total_rows']}"
)
