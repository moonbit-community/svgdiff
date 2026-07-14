#!/usr/bin/env python3

import argparse
import copy
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SUITE_PATH = ROOT / "evaluation/performance/suite.v1.json"
NUMERIC_FIELDS = {
    "sum",
    "min",
    "max",
    "mean",
    "median",
    "variance",
    "std_dev",
    "std_dev_pct",
    "median_abs_dev",
    "median_abs_dev_pct",
    "iqr",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate a pipeline-stage benchmark artifact."
    )
    parser.add_argument("--input", type=Path)
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def validate(document: dict, suite: dict) -> None:
    if document.get("schema_version") != "svgdiff-stage-benchmark-results/1":
        raise ValueError("unsupported stage benchmark result schema")
    if document.get("suite_version") != suite.get("schema_version"):
        raise ValueError("stage benchmark suite identity mismatch")
    for field in ("target", "build_profile", "time_unit", "workload"):
        if document.get(field) != suite.get(field):
            raise ValueError(f"stage benchmark {field} mismatch")
    stages = document.get("stages")
    if not isinstance(stages, list):
        raise ValueError("stage benchmark summaries must be an array")
    expected = [stage["id"] for stage in suite["stages"]]
    names = [stage.get("name") for stage in stages]
    if names != expected or len(names) != len(set(names)):
        raise ValueError("stage benchmark IDs are missing, duplicated, or reordered")
    for stage in stages:
        for field in NUMERIC_FIELDS:
            value = stage.get(field)
            if type(value) not in {int, float} or not math.isfinite(value):
                raise ValueError(f"{stage['name']}: invalid {field}")
            if value < 0:
                raise ValueError(f"{stage['name']}: negative {field}")
        for field in ("batch_size", "runs"):
            value = stage.get(field)
            if type(value) is not int or value <= 0:
                raise ValueError(f"{stage['name']}: invalid {field}")
        if stage["min"] <= 0 or stage["mean"] <= 0 or stage["max"] <= 0:
            raise ValueError(f"{stage['name']}: nonpositive elapsed time")
        if not stage["min"] <= stage["median"] <= stage["max"]:
            raise ValueError(f"{stage['name']}: median outside sample range")
        if not stage["min"] <= stage["mean"] <= stage["max"]:
            raise ValueError(f"{stage['name']}: mean outside sample range")
        quartiles = stage.get("quartiles")
        if (
            not isinstance(quartiles, list)
            or len(quartiles) != 3
            or any(type(value) not in {int, float} for value in quartiles)
            or not stage["min"] <= quartiles[0] <= quartiles[1] <= quartiles[2] <= stage["max"]
        ):
            raise ValueError(f"{stage['name']}: invalid quartiles")


def expect_rejection(document: dict, suite: dict) -> None:
    try:
        validate(document, suite)
    except ValueError:
        return
    raise AssertionError("invalid stage benchmark artifact was accepted")


def self_test(document: dict, suite: dict) -> None:
    missing = copy.deepcopy(document)
    missing["stages"].pop()
    expect_rejection(missing, suite)
    duplicate = copy.deepcopy(document)
    duplicate["stages"][-1] = copy.deepcopy(duplicate["stages"][0])
    expect_rejection(duplicate, suite)
    nonpositive = copy.deepcopy(document)
    nonpositive["stages"][0]["mean"] = 0
    expect_rejection(nonpositive, suite)
    malformed = copy.deepcopy(document)
    malformed["stages"][0]["runs"] = "ten"
    expect_rejection(malformed, suite)


def main() -> None:
    args = parse_args()
    if args.input is None:
        raise SystemExit("--input is required")
    suite = json.loads(SUITE_PATH.read_text(encoding="utf-8"))
    document = json.loads(args.input.read_text(encoding="utf-8"))
    validate(document, suite)
    if args.self_test:
        self_test(document, suite)
    print(f"Pipeline stage benchmarks: {len(document['stages'])} summaries valid")


if __name__ == "__main__":
    main()
