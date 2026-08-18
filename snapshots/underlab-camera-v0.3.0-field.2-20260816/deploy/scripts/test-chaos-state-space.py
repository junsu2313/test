#!/usr/bin/env python3

import importlib.util
import math
import sys
from pathlib import Path


script = Path(__file__).with_name("calculate-chaos-state-space.py")
spec = importlib.util.spec_from_file_location("chaos_state_space", script)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = module
spec.loader.exec_module(module)

assert len(module.LAYERS) == 7
assert len(module.DOMAINS) == 26
assert math.prod(len(values) for values in module.DOMAINS.values()) == 187_861_869_527_040

result = module.calculate()
assert result["valid_total"] > 0
assert result["valid_total"] < result["raw_total"]
assert result["raw_total"] == result["valid_total"] + result["removed_total"]
assert math.prod(component["valid"] for component in result["components"]) == result["valid_total"]

print("PASS: exact constrained chaos state-space count")
