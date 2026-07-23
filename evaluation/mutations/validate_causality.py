#!/usr/bin/env python3

import argparse
import copy
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from evaluation.report_causes import (
    cause_candidate_difference_ids,
    report_differences,
    report_difference_ids,
)

KIND_ALIASES = {
    "--paint": {"paint.fill"},
    "color": {"paint.fill"},
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate generated mutations against the public report."
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--reports", type=Path, required=True)
    return parser.parse_args()


def normalized_source(value: object) -> object:
    if not isinstance(value, str):
        return value
    return " ".join(value.replace(",", " ").split())


def matching_differences(report: dict, expected: dict) -> list[dict]:
    matches = []
    for difference in report_differences(report):
        source = difference["source"]
        if expected.get("fact_form") == "structural_relationship":
            if not difference["kind"].endswith(expected["report_property"]):
                continue
        else:
            exact_values = (
                normalized_source(source.get("before"))
                == normalized_source(expected["before_declared_value"])
                and normalized_source(source.get("after"))
                == normalized_source(expected["after_declared_value"])
            )
            token = expected["source_property"].replace("-", "_").lower()
            identity = (
                difference["id"].replace("-", "_").lower()
                + " "
                + difference["kind"].replace("-", "_").lower()
            )
            aliases = KIND_ALIASES.get(expected["report_property"], set())
            if (
                not exact_values
                and token not in identity
                and difference["kind"] not in aliases
            ):
                continue
            if source.get("before") == source.get("after"):
                if difference["kind"] not in aliases:
                    continue
        matches.append(difference)
    return matches


def validate_event(report: dict, difference_id: str, viewport_pixels: int) -> None:
    events = [
        event
        for event in report["events"]
        if difference_id in event["difference_ids"]
    ]
    if not events:
        raise ValueError(f"{difference_id}: no owning Visual Event")
    all_difference_ids = report_difference_ids(report)
    for event in events:
        outcome = event["outcome"]
        if outcome["status"] == "computed":
            expected_fraction = outcome["changed_pixels"] / viewport_pixels
            if abs(outcome["changed_fraction"] - expected_fraction) > 1e-12:
                raise ValueError(f"{event['id']}: inconsistent changed fraction")
        for region in event["regions"]:
            candidates = cause_candidate_difference_ids(
                region["possible_causes"],
                all_difference_ids,
            )
            if difference_id not in candidates:
                raise ValueError(
                    f"{region['id']}: cause scope omitted {difference_id}"
                )


def validate_case(case: dict, report: dict, reverse: dict) -> None:
    if report["analysis_status"] != case["expected_analysis_status"]:
        raise ValueError(
            f"{case['id']}: expected {case['expected_analysis_status']}, "
            f"got {report['analysis_status']}"
        )
    expected = case["expected_changed_fact"]
    matches = matching_differences(report, expected)
    if not matches:
        raise ValueError(f"{case['id']}: expected Atomic Difference is absent")

    reverse_expected = dict(expected)
    if expected.get("fact_form") != "structural_relationship":
        reverse_expected["before_declared_value"] = expected["after_declared_value"]
        reverse_expected["after_declared_value"] = expected["before_declared_value"]
    reverse_matches = matching_differences(reverse, reverse_expected)
    if not reverse_matches:
        raise ValueError(f"{case['id']}: reverse Atomic Difference is absent")

    viewport_pixels = case["viewport"]["width"] * case["viewport"]["height"]
    for difference in matches:
        validate_event(report, difference["id"], viewport_pixels)
    for difference in reverse_matches:
        validate_event(reverse, difference["id"], viewport_pixels)


def validate_negative_controls(report: dict) -> None:
    difference_ids = report_difference_ids(report)
    comparison = {"scope": "comparison"}
    if cause_candidate_difference_ids(comparison, difference_ids) != difference_ids:
        raise ValueError("comparison cause scope did not expand to the full inventory")

    invalid = copy.deepcopy(comparison)
    invalid["candidate_difference_ids"] = sorted(difference_ids)
    try:
        cause_candidate_difference_ids(invalid, difference_ids)
    except ValueError:
        pass
    else:
        raise ValueError("comparison cause scope accepted repeated candidates")

    for invalid in (
        {"scope": "event_region"},
        {"scope": "event_region", "candidate_difference_ids": ["diff:missing"]},
        {
            "scope": "event_region",
            "candidate_difference_ids": ["diff:duplicate", "diff:duplicate"],
        },
    ):
        try:
            cause_candidate_difference_ids(invalid, difference_ids)
        except ValueError:
            continue
        raise ValueError(f"invalid event-region causes accepted: {invalid}")


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    reports = {}
    for case in manifest["cases"]:
        report = json.loads(
            (args.reports / f"{case['id']}-report.json").read_text(encoding="utf-8")
        )
        reverse = json.loads(
            (args.reports / f"{case['id']}-reverse-report.json").read_text(
                encoding="utf-8"
            )
        )
        validate_case(case, report, reverse)
        reports[case["id"]] = report

    representative = next(
        report for report in reports.values() if report_difference_ids(report)
    )
    validate_negative_controls(representative)
    print(
        f"Mutation causality: {len(reports)} reports preserve public "
        "difference, event, magnitude, and cause-scope invariants"
    )


if __name__ == "__main__":
    main()
