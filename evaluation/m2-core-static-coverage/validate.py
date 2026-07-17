#!/usr/bin/env python3

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ARTIFACT = Path(__file__).with_name("gate.v1.json")
COVERAGE = ROOT / "docs" / "feature-coverage.md"

EXPECTED_IDS = {
    "paths",
    "transforms",
    "viewports",
    "css_cascade",
    "reuse",
    "gradients",
    "clipping",
    "masking",
    "group_compositing",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate(document: object) -> None:
    require(isinstance(document, dict), "gate must be an object")
    require(document.get("schema_version") == "svgdiff-m2-core-static-coverage-gate/1", "gate identity drifted")
    require(document.get("milestone") == "M2", "milestone drifted")
    require(document.get("claim") == "every_named_core_static_capability_has_explicit_complete_or_partial_behavior", "claim drifted")
    capabilities = document.get("capabilities")
    require(isinstance(capabilities, list), "capabilities must be an array")

    coverage_text = COVERAGE.read_text(encoding="utf-8")
    actual_ids: set[str] = set()
    for capability in capabilities:
        require(isinstance(capability, dict), "capability must be an object")
        capability_id = capability.get("id")
        require(isinstance(capability_id, str) and capability_id, "bad capability id")
        require(capability_id not in actual_ids, "duplicate capability id")
        actual_ids.add(capability_id)
        status = capability.get("admitted_status")
        require(isinstance(status, str) and ("complete" in status or status == "partial"), f"{capability_id}: no explicit status")
        admitted_slice = capability.get("admitted_slice")
        require(isinstance(admitted_slice, str) and admitted_slice, f"{capability_id}: no admitted slice")
        marker = capability.get("coverage_marker")
        require(isinstance(marker, str) and marker in coverage_text, f"{capability_id}: stale coverage marker")
        diagnostics = capability.get("limiting_diagnostics")
        require(isinstance(diagnostics, list), f"{capability_id}: diagnostics must be an array")
        require(all(isinstance(code, str) and code for code in diagnostics), f"{capability_id}: bad Diagnostic")
        require(len(diagnostics) == len(set(diagnostics)), f"{capability_id}: duplicate Diagnostic")
        if status != "complete":
            require(diagnostics, f"{capability_id}: bounded slice has no limiting Diagnostic")
        for code in diagnostics:
            require(f"`{code}`" in coverage_text, f"{capability_id}: Diagnostic absent from coverage contract")
        tests = capability.get("tests")
        require(isinstance(tests, list) and tests, f"{capability_id}: no tests")
        require(len(tests) == len(set(tests)), f"{capability_id}: duplicate tests")
        for relative in tests:
            require(isinstance(relative, str), f"{capability_id}: bad test path")
            path = ROOT / relative
            require(path.is_file(), f"{capability_id}: missing {relative}")
            require('test "' in path.read_text(encoding="utf-8"), f"{capability_id}: {relative} has no tests")

    require(actual_ids == EXPECTED_IDS, "core static capability inventory drifted")


def negative_controls(document: dict) -> None:
    missing = copy.deepcopy(document)
    missing["capabilities"].pop()
    unguarded = copy.deepcopy(document)
    unguarded["capabilities"][0]["limiting_diagnostics"] = []
    stale = copy.deepcopy(document)
    stale["capabilities"][1]["coverage_marker"] = "missing coverage row"
    for index, mutation in enumerate([missing, unguarded, stale]):
        try:
            validate(mutation)
        except ValueError:
            continue
        raise AssertionError(f"negative control {index} was accepted")


def main() -> None:
    document = json.loads(ARTIFACT.read_text(encoding="utf-8"))
    validate(document)
    negative_controls(document)
    print("M2 core static coverage: 9 explicit complete-or-partial capability contracts validated")


if __name__ == "__main__":
    main()
