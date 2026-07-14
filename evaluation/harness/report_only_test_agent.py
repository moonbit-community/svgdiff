#!/usr/bin/env python3

import json
import os
import sys
import time


task = json.load(sys.stdin)
if set(task) != {"case_id", "acceptance_version", "prompt", "report"}:
    raise SystemExit("task contains fields outside the report-only protocol")

mode = os.environ.get("SVGDIFF_TEST_AGENT_MODE", "success")
if mode == "fail":
    raise SystemExit("requested test failure")
if mode == "invalid-json":
    print("not-json")
    raise SystemExit(0)
if mode == "timeout":
    time.sleep(0.2)

report = task["report"]
status = report["analysis_status"]
if status != "complete":
    equality = "not_established"
elif report["atomic_differences"]:
    equality = "different"
else:
    equality = "established"

json.dump(
    {
        "case_id": "wrong-case" if mode == "mismatch" else task["case_id"],
        "acceptance_version": task["acceptance_version"],
        "coverage": {
            "analysis_status": status,
            "equality_conclusion": equality,
            "diagnostic_ids": [item["id"] for item in report["diagnostics"]],
        },
        "differences": [],
        "main_changes": [],
        "limitations": ["Protocol test adapter does not perform semantic interpretation."],
    },
    sys.stdout,
)
