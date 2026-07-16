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
        if expected.get("fact_form") == "structural_relationship":
            if before is not None or after is not None:
                continue
            if fact["affected_subject_ids"] != expected["affected_subject_ids"]:
                continue
            matches.append(fact)
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


def validate_boundary_distribution(difference: dict[str, Any]) -> bool:
    boundary = difference["magnitude"]["painted_boundary_displacement"]
    if boundary is None:
        return False
    before_count = boundary["before_sample_count"]
    after_count = boundary["after_sample_count"]
    mean = boundary["mean_css_px"]
    p95 = boundary["p95_css_px"]
    maximum = boundary["max_css_px"]
    if (
        boundary["method_id"] != "symmetric_nearest_boundary_pixels/v1"
        or before_count < 0
        or after_count < 0
        or (before_count == 0) != (after_count == 0)
        or not 0 <= mean <= maximum
        or not 0 <= p95 <= maximum
        or difference["subject_role"] != "entity"
        or not difference["domain"].startswith("geometry.")
        or (
            maximum > 0
            and "rendered_evidence" not in difference["evidence_layers"]
        )
    ):
        raise ValueError(
            f"{difference['id']}: invalid painted-boundary distribution"
        )
    return True


def validate_coverage_difference(difference: dict[str, Any]) -> bool:
    coverage = difference["magnitude"]["painted_coverage_difference"]
    if coverage is None:
        return False
    before = coverage["before_coverage_css_px2"]
    after = coverage["after_coverage_css_px2"]
    absolute = coverage["absolute_difference_css_px2"]
    union = coverage["union_coverage_css_px2"]
    fraction = coverage["fraction"]
    expected_fraction = 0 if union == 0 else absolute / union
    if (
        coverage["method_id"]
        != "symmetric_alpha_coverage_l1_over_union/v1"
        or min(before, after, absolute, union, fraction) < 0
        or absolute > union
        or fraction > 1
        or abs(fraction - expected_fraction) > 1e-12
        or difference["subject_role"] != "entity"
        or difference["computed_relation"]["status"] != "different"
        or difference["domain"].startswith("presence.")
        or difference["domain"] == "presence"
        or (
            fraction > 0
            and "rendered_evidence" not in difference["evidence_layers"]
        )
    ):
        raise ValueError(f"{difference['id']}: invalid painted coverage")
    return True


def validate_perceptual_color(report: dict[str, Any]) -> list[dict[str, Any]]:
    computed = []
    for event in report["events"]:
        rendered = event["rendered_outcome"]
        evidence = rendered["perceptual_color"]
        if rendered["status"] != "computed":
            if evidence != {
                "status": "not_computed",
                "reason_code": "rendered_evidence_unavailable",
            }:
                raise ValueError(
                    f"{event['id']}: invalid unavailable perceptual evidence"
                )
            continue
        magnitude = evidence.get("magnitude")
        rendered_magnitude = rendered.get("magnitude")
        if (
            evidence.get("status") != "computed"
            or magnitude is None
            or rendered_magnitude is None
            or magnitude["method_id"]
            != "delta_e_ok_changed_pixels_after_linear_srgb_background/v1"
            or magnitude["sample_count"]
            != rendered_magnitude["changed_pixels"]
            or magnitude["sample_count"] < 0
            or magnitude["mean_delta_e_ok"] < 0
        ):
            raise ValueError(f"{event['id']}: invalid perceptual color evidence")
        computed.append(event)
    return computed


SPATIAL_SCALAR_PROPERTIES = {
    "x", "y", "width", "height", "rx", "ry", "cx", "cy", "r",
    "x1", "y1", "x2", "y2", "stroke-width", "stroke-dashoffset",
}


def validate_parameter_magnitude(
    case: dict[str, Any], report: dict[str, Any], fact_id: str
) -> None:
    expected = case["expected_changed_fact"]
    if expected.get("source_property") not in SPATIAL_SCALAR_PROPERTIES:
        return
    differences = [
        difference
        for difference in report["atomic_differences"]
        if fact_id in difference["changed_fact_ids"]
        and difference["magnitude"]["parameter_abs_user_units"] is not None
    ]
    if len(differences) != 1:
        raise ValueError(f"{case['id']}: spatial scalar has no unique magnitude")
    magnitude = differences[0]["magnitude"]
    try:
        before = float(expected["before_declared_value"])
        after = float(expected["after_declared_value"])
    except ValueError:
        pass
    else:
        if (
            abs(magnitude["parameter_abs_user_units"] - abs(after - before))
            > 1e-12
        ):
            raise ValueError(f"{case['id']}: local parameter magnitude changed")
    if (
        magnitude["parameter_abs_css_px"] is None
        or magnitude["parameter_viewport_fraction"] is None
        or magnitude["parameter_entity_fraction"] is None
    ):
        raise ValueError(f"{case['id']}: spatial parameter scales are incomplete")


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
    validate_parameter_magnitude(case, report, actual_id)
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


def reversed_case(case: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(case)
    result["id"] = f"{case['id']}:reverse"
    expected = result["expected_changed_fact"]
    if expected.get("fact_form") == "structural_relationship":
        expected["affected_subject_ids"].reverse()
    else:
        expected["before_declared_value"], expected["after_declared_value"] = (
            expected["after_declared_value"],
            expected["before_declared_value"],
        )
    return result


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-generated-mutations/1":
        raise ValueError("unsupported generated mutation manifest")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("generated mutation manifest has no cases")

    reports = {}
    complete_comparisons = 0
    complete_regions = 0
    for case in cases:
        directions = (
            (case, args.reports / f"{case['id']}-report.json"),
            (reversed_case(case), args.reports / f"{case['id']}-reverse-report.json"),
        )
        for directional_case, report_path in directions:
            if not report_path.is_file():
                raise ValueError(
                    f"{directional_case['id']}: missing production report"
                )
            report = json.loads(report_path.read_text(encoding="utf-8"))
            reports[directional_case["id"]] = report
            region_count = validate_case(directional_case, report)
            if directional_case["expected_analysis_status"] == "complete":
                complete_comparisons += 1
                complete_regions += region_count

    expected_complete_comparisons = 2 * sum(
        case["expected_analysis_status"] == "complete" for case in cases
    )
    if (
        complete_comparisons != expected_complete_comparisons
        or complete_regions == 0
    ):
        raise ValueError(
            "causal property did not cover the complete mutation surface: "
            f"comparisons={complete_comparisons}, regions={complete_regions}"
        )

    boundary_differences = [
        difference
        for report in reports.values()
        for difference in report["atomic_differences"]
        if validate_boundary_distribution(difference)
    ]
    if not boundary_differences:
        raise ValueError("mutation surface produced no boundary distributions")
    coverage_differences = [
        difference
        for report in reports.values()
        for difference in report["atomic_differences"]
        if validate_coverage_difference(difference)
    ]
    if not coverage_differences:
        raise ValueError("mutation surface produced no coverage observations")
    perceptual_events = [
        event
        for report in reports.values()
        for event in validate_perceptual_color(report)
    ]
    if not perceptual_events:
        raise ValueError("mutation surface produced no perceptual observations")
    for case in cases:
        forward = {
            event["id"]: event
            for event in validate_perceptual_color(reports[case["id"]])
        }
        reverse = {
            event["id"]: event
            for event in validate_perceptual_color(
                reports[f"{case['id']}:reverse"]
            )
        }
        for event_id in forward.keys() & reverse.keys():
            left = forward[event_id]["rendered_outcome"]["perceptual_color"][
                "magnitude"
            ]
            right = reverse[event_id]["rendered_outcome"]["perceptual_color"][
                "magnitude"
            ]
            if (
                left["sample_count"] != right["sample_count"]
                or abs(left["mean_delta_e_ok"] - right["mean_delta_e_ok"])
                > 1e-12
            ):
                raise ValueError(
                    f"{case['id']}/{event_id}: perceptual reversal changed"
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

    parameter_case = next(
        case
        for case in cases
        if case["expected_changed_fact"].get("source_property")
        in SPATIAL_SCALAR_PROPERTIES
    )
    invalid_magnitude_report = copy.deepcopy(reports[parameter_case["id"]])
    parameter_fact_id = matching_changed_facts(
        invalid_magnitude_report, parameter_case["expected_changed_fact"]
    )[0]["id"]
    parameter_difference = next(
        difference
        for difference in invalid_magnitude_report["atomic_differences"]
        if parameter_fact_id in difference["changed_fact_ids"]
        and difference["magnitude"]["parameter_abs_user_units"] is not None
    )
    parameter_difference["magnitude"]["parameter_abs_css_px"] = None
    try:
        validate_case(parameter_case, invalid_magnitude_report)
    except ValueError:
        pass
    else:
        raise ValueError("mutation property accepted a missing parameter scale")

    invalid_boundary_report = copy.deepcopy(
        next(
            report
            for report in reports.values()
            if any(
                difference["magnitude"]["painted_boundary_displacement"]
                is not None
                for difference in report["atomic_differences"]
            )
        )
    )
    invalid_boundary = next(
        difference
        for difference in invalid_boundary_report["atomic_differences"]
        if difference["magnitude"]["painted_boundary_displacement"] is not None
    )
    invalid_boundary["magnitude"]["painted_boundary_displacement"][
        "p95_css_px"
    ] = (
        invalid_boundary["magnitude"]["painted_boundary_displacement"][
            "max_css_px"
        ]
        + 1
    )
    try:
        validate_boundary_distribution(invalid_boundary)
    except ValueError:
        pass
    else:
        raise ValueError("mutation property accepted an invalid boundary distribution")

    invalid_coverage_report = copy.deepcopy(
        next(
            report
            for report in reports.values()
            if any(
                difference["magnitude"]["painted_coverage_difference"]
                is not None
                for difference in report["atomic_differences"]
            )
        )
    )
    invalid_coverage = next(
        difference
        for difference in invalid_coverage_report["atomic_differences"]
        if difference["magnitude"]["painted_coverage_difference"] is not None
    )
    invalid_coverage["magnitude"]["painted_coverage_difference"]["fraction"] = 2
    try:
        validate_coverage_difference(invalid_coverage)
    except ValueError:
        pass
    else:
        raise ValueError("mutation property accepted invalid painted coverage")

    invalid_perceptual_report = copy.deepcopy(
        next(
            report
            for report in reports.values()
            if validate_perceptual_color(report)
        )
    )
    invalid_perceptual = validate_perceptual_color(invalid_perceptual_report)[0]
    invalid_perceptual["rendered_outcome"]["perceptual_color"]["magnitude"][
        "mean_delta_e_ok"
    ] = -1
    try:
        validate_perceptual_color(invalid_perceptual_report)
    except ValueError:
        pass
    else:
        raise ValueError("mutation property accepted invalid perceptual color")

    print(
        "Mutation causal property: "
        f"{complete_comparisons} complete directional comparisons, "
        f"{complete_regions} complete regions, "
        f"{len(boundary_differences)} boundary observations, "
        f"{len(coverage_differences)} coverage observations, "
        f"{len(perceptual_events)} perceptual observations, "
        "missing-cause, missing-parameter-scale, invalid-boundary, invalid-coverage, and invalid-perceptual negative controls: ok"
    )


if __name__ == "__main__":
    main()
