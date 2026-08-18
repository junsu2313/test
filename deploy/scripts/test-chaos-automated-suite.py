#!/usr/bin/env python3
import importlib.util
import itertools
import sys
from pathlib import Path

path = Path(__file__).with_name("generate-chaos-automated-suite.py")
spec = importlib.util.spec_from_file_location("automated_suite", path)
module = importlib.util.module_from_spec(spec); sys.modules[spec.name] = module
assert spec.loader is not None; spec.loader.exec_module(module)

result, rows = module.calculate(810)
auto = [row for row in rows if row["case_type"] == "automated_pipeline"]
software = {tuple(row[name] for name in module.SOFTWARE) for row in auto}
expected = set(itertools.product(*(values for values in module.SOFTWARE.values())))
assert software == expected
assert result["automated_valid_pairs"] == result["automated_covered_pairs"]
assert len([row for row in rows if row["case_type"] == "physical_phase"]) == 2
assert len([row for row in rows if row["case_type"] == "post_physical"]) == 30
assert result["manual_interventions"] == 2
assert result["physical_shutter_actions"] == 0
assert len({row["case_id"] for row in rows}) == len(rows)
assert "shutter" not in repr(rows).lower() and "capture" not in repr(rows).lower()

again_result, again_rows = module.calculate(810)
assert again_result == result and again_rows == rows
unattended_result, unattended_rows = module.calculate(810, unattended=True)
assert unattended_result["total_rows"] == 60
assert unattended_result["manual_interventions"] == 0
assert unattended_result["physical_phase_rows"] == 0
assert not any(row["case_id"].startswith(("PWR-", "USB-")) for row in unattended_rows)
assert not any(row["s10"] == "wifi_reconnect" for row in unattended_rows)
assert sum(row["s10"] == "wireless_continuity" for row in unattended_rows) == 12
print(f"PASS: automated suite rows={result['total_rows']} manual={result['manual_interventions']}")
