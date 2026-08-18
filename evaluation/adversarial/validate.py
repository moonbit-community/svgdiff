#!/usr/bin/env python3

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from evaluation.report_causes import report_differences
EXPECTED_MODES = {
    "false_complete",
    "false_pair_identity",
    "viewport_false_complete",
    "false_equality",
    "structural_false_equality",
    "wrong_alignment",
    "wrong_alignment_transform",
    "attribution_leakage",
    "magnitude_ordering",
    "reference_cycle",
    "resource_dependency_cycle",
    "reference_expansion",
    "use_invalid_reference",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate adversarial SVG pairs through the production CLI."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "evaluation/adversarial/manifest.v1.json",
    )
    return parser.parse_args()


def checked_source(relative_path: str) -> Path:
    source = (ROOT / relative_path).resolve()
    if ROOT not in source.parents or not source.is_file():
        raise ValueError(f"unsafe or missing adversarial source: {relative_path}")
    return source


def run_case(cli: Path, case: dict) -> tuple[dict, str]:
    before = checked_source(case["before"])
    after = checked_source(case["after"])
    result = subprocess.run(
        [
            str(cli),
            str(before),
            str(after),
            "--width",
            str(case["viewport"]["width"]),
            "--height",
            str(case["viewport"]["height"]),
            "--agent-json",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    expected_exit_status = case.get("expected_exit_status", 0)
    if result.returncode != expected_exit_status or result.stderr:
        raise ValueError(
            f"CLI failed for {case['id']}: "
            f"status={result.returncode}, stderr={result.stderr!r}"
        )
    report = json.loads(result.stdout)
    if report.get("schema_version") != "3.0":
        raise ValueError(f"unexpected report schema for {case['id']}")
    comparison = report["comparison"]
    if (
        comparison.get("flip_pixels_per_degree") is not None
        or comparison.get("flip_error_threshold") is not None
        or any("perceptual_difference" in event["outcome"] for event in report["events"])
    ):
        raise ValueError(f"unexpected unrequested FLIP state for {case['id']}")
    return report, hashlib.sha256(result.stdout.encode()).hexdigest()


def diagnostic_codes(report: dict) -> set[str]:
    return {diagnostic["code"] for diagnostic in report["limitations"]}


def event_for_difference(report: dict, difference_id: str) -> dict:
    matches = [
        event
        for event in report["events"]
        if difference_id in event["difference_ids"]
    ]
    if len(matches) != 1:
        raise ValueError(
            f"{difference_id}: expected one owning Visual Event, got {len(matches)}"
        )
    return matches[0]


def validate_subject_roles(report: dict) -> None:
    if any(
        difference.get("subject_role") not in {"entity", "resource"}
        for difference in report_differences(report)
    ):
        raise ValueError("Atomic Difference lost its entity/resource role")


def source_set_hash(cases: list[dict]) -> str:
    sources = []
    for case in cases:
        for side in ("before", "after"):
            source = checked_source(case[side])
            sources.append(
                {
                    "case": case["id"],
                    "side": side,
                    "path": case[side],
                    "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                }
            )
    encoded = json.dumps(sources, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def validate_false_complete(case: dict, report: dict) -> None:
    before = checked_source(case["before"])
    after = checked_source(case["after"])
    if before.read_bytes() != after.read_bytes():
        raise ValueError("false-complete case must be an exact self-comparison")
    if report["analysis_status"] != "partial":
        raise ValueError("unchanged malformed transform produced complete analysis")
    if "transform_syntax_unsupported" not in diagnostic_codes(report):
        raise ValueError("false-complete case lost its transform-syntax Diagnostic")


def validate_viewport_false_complete(case: dict, report: dict) -> None:
    before = checked_source(case["before"])
    after = checked_source(case["after"])
    if before.read_bytes() != after.read_bytes():
        raise ValueError("viewport false-complete case must be an exact self-comparison")
    if report["analysis_status"] != "partial":
        raise ValueError("unchanged invalid viewBox produced complete analysis")
    if "viewport_semantics_unsupported" not in diagnostic_codes(report):
        raise ValueError("viewport false-complete case lost its viewport Diagnostic")


def validate_false_equality(case: dict, report: dict) -> None:
    before = checked_source(case["before"])
    after = checked_source(case["after"])
    if before.read_bytes() == after.read_bytes():
        raise ValueError("false-equality case inputs must differ")
    if report["analysis_status"] != "partial":
        raise ValueError("unsupported path change produced complete equality")
    differences = report_differences(report)
    expected_ids = {
        "diff:alignment:0:d:segment:0:parameter:y",
        "diff:alignment:0:d:segment:1:parameter:y",
    }
    if {difference["id"] for difference in differences} != expected_ids:
        raise ValueError("false-equality path findings are incomplete or unstable")
    event = event_for_difference(report, differences[0]["id"])
    if any(event_for_difference(report, item["id"])["id"] != event["id"] for item in differences):
        raise ValueError("false-equality path findings lost their shared Visual Event")
    isolated = event["outcome"].get("isolated_subject", {})
    boundary = isolated.get("painted_boundary_displacement")
    coverage = isolated.get("painted_coverage_difference")
    if any(
        difference["kind"] != "geometry.path.parameter"
        or difference["effective"]["relation"] != "different"
        or difference["magnitude"]["parameter_abs_user_units"] != 14
        or difference["magnitude"]["parameter_abs_css_px"] != 14
        or difference["magnitude"]["parameter_viewport_fraction"] is None
        or difference["magnitude"]["parameter_entity_fraction"] is None
        for difference in differences
    ) or (
        boundary is None
        or boundary["max_css_px"] <= 0
        or not 0 <= boundary["mean_css_px"] <= boundary["max_css_px"]
        or not 0 <= boundary["p95_css_px"] <= boundary["max_css_px"]
        or coverage is None
        or coverage["absolute_difference_css_px2"] > coverage["union_css_px2"]
        or not 0 <= coverage["fraction"] <= 1
    ):
        raise ValueError("false-equality path findings lost exact or boundary evidence")
    if "unsupported_visual_subject" not in diagnostic_codes(report):
        raise ValueError("false-equality case lost its path Diagnostic")


def validate_wrong_alignment(report: dict) -> None:
    if report["analysis_status"] != "complete" or report_differences(report):
        raise ValueError("source reorder changed the visual comparison")


def validate_false_pair_identity(report: dict) -> None:
    if report["analysis_status"] != "complete" or report_differences(report):
        raise ValueError("repeated equivalent subjects changed visual equality")


def validate_structural_false_equality(report: dict) -> None:
    if report["analysis_status"] != "complete" or report["limitations"]:
        raise ValueError("admitted stacking change did not remain complete")
    differences = report_differences(report)
    if len(differences) != 1:
        raise ValueError("stacking change was lost or fragmented")
    difference = differences[0]
    event = event_for_difference(report, difference["id"])
    if (
        difference["kind"] != "document.structure.stacking_order"
        or difference["effective"]["relation"] != "different"
        or event["outcome"]["changed_fraction"] <= 0
    ):
        raise ValueError("stacking difference lost semantic or numeric evidence")
    regions = [
        region
        for event in report["events"]
        for region in event["regions"]
    ]
    if not regions or any(
        region["possible_causes"]["guarantee"] != "sound_overapproximation"
        or region["possible_causes"]["scope"] != "event_region"
        or difference["id"]
        not in region["possible_causes"]["candidate_difference_ids"]
        for region in regions
    ):
        raise ValueError("stacking difference is absent from a complete Cause Envelope")


def validate_attribution_leakage(case: dict, report: dict) -> None:
    if report["analysis_status"] != "complete":
        raise ValueError("controlled disjoint paint case is not complete")
    differences = {
        difference["id"]: difference for difference in report_differences(report)
    }
    if len(differences) != 2 or len(report["events"]) != 2:
        raise ValueError("disjoint paint case did not produce two outcomes")
    expected_regions = {
        expected["authored_id"]: expected
        for expected in case["expected_subject_regions"]
    }
    if set(expected_regions) != {"left", "right"}:
        raise ValueError("disjoint paint region oracle is incomplete")
    seen_differences: set[str] = set()
    actual_bounds = []
    for event in report["events"]:
        event_differences = set(event["difference_ids"])
        if (
            not event_differences
            or not event["regions"]
            or not event_differences <= set(differences)
        ):
            raise ValueError(f"event lacks differences or regions: {event['id']}")
        if seen_differences & event_differences:
            raise ValueError("disjoint events share an Atomic Difference")
        seen_differences |= event_differences
        if len(event["regions"]) != 1:
            raise ValueError(f"unexpected subject region structure: {event['id']}")
        region = event["regions"][0]
        actual = region["bounds"]
        matches = [
            (subject_id, expected)
            for subject_id, expected in expected_regions.items()
            if expected["css_bounds"] == actual
        ]
        if len(matches) != 1:
            raise ValueError(f"unexpected subject region structure: {event['id']}")
        subject_id, expected = matches[0]
        if actual != expected["css_bounds"]:
            raise ValueError(
                f"{subject_id}: expected bounds {expected['css_bounds']}, got {actual}"
            )
        if region["changed_pixels"] != expected["changed_pixels"]:
            raise ValueError(f"{subject_id}: region absorbed scene-wide pixels")
        if region["viewport_fraction"] != expected["viewport_fraction"]:
            raise ValueError(f"{subject_id}: region viewport fraction changed")
        rendered = event["outcome"]
        if rendered["changed_pixels"] != expected["changed_pixels"]:
            raise ValueError(f"{subject_id}: event absorbed scene-wide pixels")
        actual_bounds.append(actual)
        for region in event["regions"]:
            causes = region["possible_causes"]
            if causes["scope"] != "event_region":
                raise ValueError(f"{region['id']}: lost event-local cause scope")
            candidates = set(causes["candidate_difference_ids"])
            if candidates != event_differences:
                raise ValueError(
                    f"attribution leakage in {region['id']}: "
                    f"expected={sorted(event_differences)}, actual={sorted(candidates)}"
                )
    left, right = sorted(actual_bounds, key=lambda bounds: bounds["x"])
    if left["x"] + left["width"] > right["x"]:
        raise ValueError("controlled subject regions overlap")
    if sum(expected["changed_pixels"] for expected in expected_regions.values()) != 50:
        raise ValueError("disjoint paint scene oracle lost changed pixels")


def validate_magnitude_ordering(report: dict) -> None:
    if report["analysis_status"] != "complete":
        raise ValueError("controlled magnitude-ordering case is not complete")
    differences = [
        difference
        for difference in report_differences(report)
        if difference["kind"] == "geometry.position"
    ]
    magnitudes = [
        difference["magnitude"]["parameter_abs_user_units"]
        for difference in differences
    ]
    if magnitudes != [4, 1]:
        raise ValueError(f"geometry magnitudes are not descending: {magnitudes}")
    if [
        difference["magnitude"]["parameter_abs_css_px"]
        for difference in differences
    ] != [4, 1]:
        raise ValueError("geometry parameter CSS magnitudes were lost")
    if any(
        difference["magnitude"]["parameter_viewport_fraction"] is None
        or difference["magnitude"]["parameter_entity_fraction"] is None
        for difference in differences
    ):
        raise ValueError("geometry normalized parameter magnitudes were lost")
def validate_reference_cycle(report: dict) -> None:
    if report["analysis_status"] != "failed":
        raise ValueError("cyclic local reference graph was not rejected")
    if diagnostic_codes(report) != {"reference_cycle_detected"}:
        raise ValueError("cyclic reference case lost its stable Diagnostic")
    if report_differences(report) or report["events"]:
        raise ValueError("cyclic reference failure exposed a partial inventory")


def validate_reference_expansion(report: dict) -> None:
    if report["analysis_status"] != "failed":
        raise ValueError("explosive acyclic reference graph was not rejected")
    if diagnostic_codes(report) != {"reference_expansion_limit_exceeded"}:
        raise ValueError("reference expansion case lost its stable Diagnostic")
    if report_differences(report) or report["events"]:
        raise ValueError("reference expansion failure exposed a partial inventory")


def validate_use_invalid_reference(report: dict) -> None:
    if report["analysis_status"] != "partial":
        raise ValueError("missing use target produced complete analysis")
    if diagnostic_codes(report) != {
        "analysis_coverage_unproven",
        "use_target_missing",
    }:
        raise ValueError("missing use target lost its stable Diagnostic")
    if report_differences(report) or report["events"]:
        raise ValueError("missing use target invented a visual difference")


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-adversarial-corpus/1":
        raise ValueError("unsupported adversarial manifest schema")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or len(cases) != len(EXPECTED_MODES):
        raise ValueError("adversarial manifest must contain one case per failure mode")
    ids = [case.get("id") for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("adversarial case IDs must be unique")
    modes = [case.get("failure_mode") for case in cases]
    if set(modes) != EXPECTED_MODES or len(modes) != len(set(modes)):
        raise ValueError("adversarial failure modes must be unique and complete")
    paths = [case.get(side) for case in cases for side in ("before", "after")]
    if len(paths) != len(set(paths)):
        raise ValueError("adversarial source paths must be unique")
    if any(
        not isinstance(case.get("viewport", {}).get(dimension), int)
        or case["viewport"][dimension] <= 0
        for case in cases
        for dimension in ("width", "height")
    ):
        raise ValueError("adversarial viewports must be positive integers")

    results = []
    validators = {
        "false_complete": lambda case, report: validate_false_complete(case, report),
        "false_pair_identity": lambda _case, report: validate_false_pair_identity(report),
        "viewport_false_complete": validate_viewport_false_complete,
        "false_equality": lambda case, report: validate_false_equality(case, report),
        "structural_false_equality": lambda _case, report: validate_structural_false_equality(report),
        "wrong_alignment": lambda _case, report: validate_wrong_alignment(report),
        "wrong_alignment_transform": lambda _case, report: validate_wrong_alignment(report),
        "attribution_leakage": validate_attribution_leakage,
        "magnitude_ordering": lambda _case, report: validate_magnitude_ordering(report),
        "reference_cycle": lambda _case, report: validate_reference_cycle(report),
        "resource_dependency_cycle": lambda _case, report: validate_reference_cycle(report),
        "reference_expansion": lambda _case, report: validate_reference_expansion(report),
        "use_invalid_reference": lambda _case, report: validate_use_invalid_reference(report),
    }
    for case in cases:
        report, report_sha256 = run_case(args.cli, case)
        validate_subject_roles(report)
        validators[case["failure_mode"]](case, report)
        results.append(
            {
                "id": case["id"],
                "failure_mode": case["failure_mode"],
                "status": "passed",
                "report_sha256": report_sha256,
            }
        )

    output = {
        "schema_version": "svgdiff-adversarial-results/1",
        "input_schema_version": manifest["schema_version"],
        "fixture_source_set_sha256": source_set_hash(cases),
        "cases": results,
    }
    args.output.write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Adversarial corpus: {len(results)} failure modes passed")


if __name__ == "__main__":
    main()
