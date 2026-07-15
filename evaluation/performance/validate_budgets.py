#!/usr/bin/env python3

import argparse
import copy
import json
import math
import statistics
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "evaluation/performance/budgets.v2.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate svgdiff end-to-end performance results."
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def finite_positive(value: object) -> bool:
    return type(value) in {int, float} and math.isfinite(value) and value > 0


def validate(document: dict, manifest: dict) -> None:
    if document.get("schema_version") != manifest.get("result_schema_version"):
        raise ValueError("performance result schema mismatch")
    if document.get("budget_version") != manifest.get("schema_version"):
        raise ValueError("performance budget identity mismatch")
    for field in ("target", "build_profile", "samples_per_workload"):
        if document.get(field) != manifest.get(field):
            raise ValueError(f"performance result {field} mismatch")
    environment = document.get("environment")
    if not isinstance(environment, dict) or any(
        not environment.get(field)
        for field in (
            "operating_system",
            "architecture",
            "python_version",
            "product_version",
        )
    ):
        raise ValueError("performance environment identity is incomplete")
    expected = manifest["workloads"]
    workloads = document.get("workloads")
    if not isinstance(workloads, list):
        raise ValueError("performance workloads must be an array")
    if [item.get("id") for item in workloads] != [item["id"] for item in expected]:
        raise ValueError("performance workload IDs are missing or reordered")
    for result, budget in zip(workloads, expected, strict=True):
        for field in (
            "size",
            "subjects_per_input",
            "viewport_width",
            "viewport_height",
        ):
            if result.get(field) != budget.get(field):
                raise ValueError(f"{result['id']}: workload metadata mismatch")
        samples = result.get("samples")
        if not isinstance(samples, list) or len(samples) != manifest["samples_per_workload"]:
            raise ValueError(f"{result['id']}: invalid sample count")
        for sample in samples:
            if not finite_positive(sample.get("elapsed_ms")):
                raise ValueError(f"{result['id']}: invalid elapsed sample")
            if not finite_positive(sample.get("peak_rss_mib")):
                raise ValueError(f"{result['id']}: invalid RSS sample")
        median_elapsed = statistics.median(
            sample["elapsed_ms"] for sample in samples
        )
        maximum_rss = max(sample["peak_rss_mib"] for sample in samples)
        if result.get("median_wall_time_ms") != median_elapsed:
            raise ValueError(f"{result['id']}: median does not match samples")
        if result.get("maximum_peak_rss_mib") != maximum_rss:
            raise ValueError(f"{result['id']}: peak RSS does not match samples")
        expected_checks = [
            (
                "median_wall_time_ms",
                median_elapsed,
                budget["median_wall_time_ms_max"],
            ),
            ("peak_rss_mib", maximum_rss, budget["peak_rss_mib_max"]),
        ]
        checks = result.get("checks")
        if not isinstance(checks, list) or len(checks) != 2:
            raise ValueError(f"{result['id']}: invalid checks")
        for check, (metric, actual, maximum) in zip(
            checks, expected_checks, strict=True
        ):
            passed = actual <= maximum
            if check != {
                "metric": metric,
                "actual": actual,
                "maximum": maximum,
                "passed": passed,
            }:
                raise ValueError(f"{result['id']}: inconsistent {metric} decision")
        if result.get("passed") is not all(check["passed"] for check in checks):
            raise ValueError(f"{result['id']}: inconsistent workload decision")
    if document.get("passed") is not all(item["passed"] for item in workloads):
        raise ValueError("inconsistent overall performance decision")


def set_failed_metric(document: dict, workload_index: int, metric: str) -> None:
    workload = document["workloads"][workload_index]
    check_index = 0 if metric == "median_wall_time_ms" else 1
    check = workload["checks"][check_index]
    value = check["maximum"] + 1
    sample_field = "elapsed_ms" if check_index == 0 else "peak_rss_mib"
    for sample in workload["samples"]:
        sample[sample_field] = value
    if check_index == 0:
        workload["median_wall_time_ms"] = value
    else:
        workload["maximum_peak_rss_mib"] = value
    check["actual"] = value
    check["passed"] = False
    workload["passed"] = False
    document["passed"] = False


def self_test(document: dict, manifest: dict) -> None:
    time_failure = copy.deepcopy(document)
    set_failed_metric(time_failure, 0, "median_wall_time_ms")
    validate(time_failure, manifest)
    if time_failure["workloads"][0]["checks"][1]["passed"] is not True:
        raise AssertionError("time negative control contaminated memory decision")
    memory_failure = copy.deepcopy(document)
    set_failed_metric(memory_failure, 1, "peak_rss_mib")
    validate(memory_failure, manifest)
    if memory_failure["workloads"][1]["checks"][0]["passed"] is not True:
        raise AssertionError("memory negative control contaminated time decision")
    malformed = copy.deepcopy(document)
    malformed["workloads"][0]["samples"][0]["elapsed_ms"] = 0
    try:
        validate(malformed, manifest)
    except ValueError:
        return
    raise AssertionError("malformed performance sample was accepted")


def main() -> None:
    args = parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    document = json.loads(args.input.read_text(encoding="utf-8"))
    validate(document, manifest)
    if args.self_test:
        self_test(document, manifest)
    passed = sum(1 for workload in document["workloads"] if workload["passed"])
    print(
        f"Performance budgets: {passed}/{len(document['workloads'])} workloads passed"
    )


if __name__ == "__main__":
    main()
