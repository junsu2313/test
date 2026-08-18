#!/usr/bin/env python3

import importlib.util
import math
import sys
from pathlib import Path


script = Path(__file__).with_name("generate-chaos-pairwise.py")
spec = importlib.util.spec_from_file_location("chaos_pairwise", script)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)

assert len(module.DOMAINS) == 14
assert "overcurrent" not in repr(module.DOMAINS).lower()
assert "exhausted" not in repr(module.DOMAINS).lower()
assert math.prod(len(values) for values in module.DOMAINS.values()) == 55_987_200

result, rows = module.calculate(seed=810, candidate_count=48)
requirements = module.valid_pairs()
covered = set().union(*(module.row_pairs(row) for row in rows))

assert all(module.row_valid(row) for row in rows)
assert requirements <= covered
assert result["covered_pairs"] == result["valid_pairs"]
assert result["coverage_percent"] == 100.0
assert rows[0] == module.BASELINE

result_again, rows_again = module.calculate(seed=810, candidate_count=48)
assert result == result_again
assert rows == rows_again

print(
    "PASS: constrained executable pairwise suite "
    f"rows={len(rows)} pairs={len(requirements)}"
)
