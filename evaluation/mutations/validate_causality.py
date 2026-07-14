#!/usr/bin/env python3

import argparse
import copy
import json
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate actual-cause containment across generated mutations."
    )
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--reports", required=True, type=Path)
    return parser.parse_args()


def matching_changed_facts(
    report: dict[str, Any], expected: dict[str, Any]
) -> list[dict[str, Any]]:
    matches = []
    for fact in report["changed_facts"]:
        before = fact.get("before")
        after = fact.get("after")
        if fact["property"] != expected["report_property"]:
            continue
        if before is None or after is None:
            continue
        if before["property"] != expected["source_property"]:
            continue
        if after["property"] != expected["source_property"]:
            continue
        if before["declared_value"] != expected["before_declared_value"]:
            continue
        if after["declared_value"] != expected["after_declared_value"]:
            continue
        if fact["affected_subject_ids"] != expected["affected_subject_ids"]:
            continue
        matches.append(fact)
    return matches


def validate_case(case: dict[str, Any], report: dict[str, Any]) -> int:
    expected_status = case["expected_analysis_status"]
    if report["analysis_status"] != expected_status:
        raise ValueError(
            f"{case['id']}: expected {expected_status}, "
            f"got {report['analysis_status']}"
        )
    matches = matching_changed_facts(report, case["expected_changed_fact"])
    if len(matches) != 1:
        raise ValueError(
            f"{case['id']}: declared actual cause matched {len(matches)} facts"
        )
    actual_id = matches[0]["id"]
    regions = [
        region
        for event in report["events"]
        for region in event["difference_regions"]
    ]
    for region in regions:
        envelope = region["cause_envelope"]
        if expected_status == "complete":
            if envelope["guarantee"] != "sound_overapproximation":
                raise ValueError(
                    f"{case['id']}/{region['id']}: complete region lost guarantee"
                )
            if actual_id not in envelope["candidate_changed_fact_ids"]:
                raise ValueError(
                    f"{case['id']}/{region['id']}: actual cause is absent"
                )
        elif envelope["guarantee"] == "sound_overapproximation":
            raise ValueError(
                f"{case['id']}/{region['id']}: partial case retained guarantee"
            )
    return len(regions)


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-generated-mutations/1":
        raise ValueError("unsupported generated mutation manifest")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("generated mutation manifest has no cases")

    reports = {}
    complete_cases = 0
    complete_regions = 0
    for case in cases:
        report_path = args.reports / f"{case['id']}-report.json"
        if not report_path.is_file():
            raise ValueError(f"{case['id']}: missing production report")
        report = json.loads(report_path.read_text(encoding="utf-8"))
        reports[case["id"]] = report
        region_count = validate_case(case, report)
        if case["expected_analysis_status"] == "complete":
            complete_cases += 1
            complete_regions += region_count

    if complete_cases != 18 or complete_regions == 0:
        raise ValueError(
            "causal property did not cover the complete mutation surface: "
            f"cases={complete_cases}, regions={complete_regions}"
        )

    negative_case = next(
        case
        for case in cases
        if case["expected_analysis_status"] == "complete"
        and any(
            event["difference_regions"] for event in reports[case["id"]]["events"]
        )
    )
    invalid_report = copy.deepcopy(reports[negative_case["id"]])
    actual_id = matching_changed_facts(
        invalid_report, negative_case["expected_changed_fact"]
    )[0]["id"]
    invalid_region = next(
        region
        for event in invalid_report["events"]
        for region in event["difference_regions"]
    )
    invalid_region["cause_envelope"]["candidate_changed_fact_ids"].remove(
        actual_id
    )
    try:
        validate_case(negative_case, invalid_report)
    except ValueError:
        pass
    else:
        raise ValueError("causal property accepted a missing actual cause")

    print(
        "Mutation causal property: "
        f"{complete_cases} complete cases, {complete_regions} complete regions, "
        "missing-cause negative control: ok"
    )


if __name__ == "__main__":
    main()
