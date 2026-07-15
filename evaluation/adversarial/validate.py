#!/usr/bin/env python3

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_MODES = {
    "false_complete",
    "viewport_false_complete",
    "false_equality",
    "structural_false_equality",
    "wrong_alignment",
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
    if report.get("schema_version") != "1.29":
        raise ValueError(f"unexpected report schema for {case['id']}")
    return report, hashlib.sha256(result.stdout.encode()).hexdigest()


def diagnostic_codes(report: dict) -> set[str]:
    return {diagnostic["code"] for diagnostic in report["diagnostics"]}


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
    differences = report["atomic_differences"]
    expected_ids = {
        "diff:alignment:0:d:segment:0:parameter:y",
        "diff:alignment:0:d:segment:1:parameter:y",
    }
    if {difference["id"] for difference in differences} != expected_ids:
        raise ValueError("false-equality path findings are incomplete or unstable")
    if any(
        difference["domain"] != "geometry.path.parameter"
        or difference["computed_relation"]["status"] != "different"
        or difference["magnitude"]["parameter_abs_user_units"] != 14
        or difference["magnitude"]["geometry_displacement_css_px"] <= 0
        for difference in differences
    ):
        raise ValueError("false-equality path findings lost exact or boundary evidence")
    if "unsupported_visual_subject" not in diagnostic_codes(report):
        raise ValueError("false-equality case lost its path Diagnostic")


def validate_wrong_alignment(report: dict) -> None:
    if report["analysis_status"] != "complete" or report["atomic_differences"]:
        raise ValueError("source reorder changed the visual comparison")
    pairs = {
        (alignment["before"][0]["source_index"], alignment["after"][0]["source_index"])
        for alignment in report["subject_alignments"]
        if alignment["relation"] == "correspondence"
        and len(alignment["before"]) == 1
        and len(alignment["after"]) == 1
    }
    if pairs != {(0, 1), (1, 0)}:
        raise ValueError(f"unlabelled subjects aligned by source order: {sorted(pairs)}")


def validate_structural_false_equality(report: dict) -> None:
    if report["analysis_status"] != "complete" or report["diagnostics"]:
        raise ValueError("admitted stacking change did not remain complete")
    differences = report["atomic_differences"]
    if len(differences) != 1:
        raise ValueError("stacking change was lost or fragmented")
    difference = differences[0]
    if (
        difference["domain"] != "document.structure.stacking_order"
        or difference["computed_relation"]["status"] != "different"
        or difference["magnitude"]["raster_changed_pixel_fraction"] <= 0
    ):
        raise ValueError("stacking difference lost semantic or numeric evidence")
    if len(difference["changed_fact_ids"]) != 1:
        raise ValueError("stacking difference lost its relationship fact")
    fact_id = difference["changed_fact_ids"][0]
    if not any(
        fact["id"] == fact_id
        and fact["property"] == "structure.stacking_order"
        and fact["affected_subject_ids"] == ["red", "blue"]
        for fact in report["changed_facts"]
    ):
        raise ValueError("stacking relationship fact is incomplete")
    regions = [
        region
        for event in report["events"]
        for region in event["difference_regions"]
    ]
    if not regions or any(
        region["cause_envelope"]["guarantee"] != "sound_overapproximation"
        or fact_id not in region["cause_envelope"]["candidate_changed_fact_ids"]
        for region in regions
    ):
        raise ValueError("stacking fact is absent from a complete Cause Envelope")


def validate_attribution_leakage(case: dict, report: dict) -> None:
    if report["analysis_status"] != "complete":
        raise ValueError("controlled disjoint paint case is not complete")
    differences = {difference["id"]: difference for difference in report["atomic_differences"]}
    if len(differences) != 2 or len(report["events"]) != 2:
        raise ValueError("disjoint paint case did not produce two outcomes")
    expected_regions = {
        expected["authored_id"]: expected
        for expected in case["expected_subject_regions"]
    }
    if set(expected_regions) != {"left", "right"}:
        raise ValueError("disjoint paint region oracle is incomplete")
    alignments = {alignment["id"]: alignment for alignment in report["subject_alignments"]}
    seen_facts: set[str] = set()
    actual_bounds = []
    for event in report["events"]:
        event_facts = {
            fact_id
            for difference_id in event["atomic_difference_ids"]
            for fact_id in differences[difference_id]["changed_fact_ids"]
        }
        if not event_facts or not event["difference_regions"]:
            raise ValueError(f"event lacks facts or regions: {event['id']}")
        if seen_facts & event_facts:
            raise ValueError("disjoint events share a Changed Fact")
        seen_facts |= event_facts
        alignment = alignments.get(event["primary_subject_id"])
        if alignment is None:
            raise ValueError(f"event does not resolve to an alignment: {event['id']}")
        subject_ids = {
            reference["authored_id"]
            for reference in alignment["before"] + alignment["after"]
        }
        if len(subject_ids) != 1 or None in subject_ids:
            raise ValueError(f"event has ambiguous authored subject: {event['id']}")
        subject_id = next(iter(subject_ids))
        expected = expected_regions.get(subject_id)
        if expected is None or len(event["difference_regions"]) != 1:
            raise ValueError(f"unexpected subject region structure: {event['id']}")
        region = event["difference_regions"][0]
        actual = {
            "x": region["css_x"],
            "y": region["css_y"],
            "width": region["css_width"],
            "height": region["css_height"],
        }
        if actual != expected["css_bounds"]:
            raise ValueError(
                f"{subject_id}: expected bounds {expected['css_bounds']}, got {actual}"
            )
        if region["changed_pixels"] != expected["changed_pixels"]:
            raise ValueError(f"{subject_id}: region absorbed scene-wide pixels")
        if region["viewport_fraction"] != expected["viewport_fraction"]:
            raise ValueError(f"{subject_id}: region viewport fraction changed")
        rendered = event["rendered_outcome"]["magnitude"]
        if rendered["changed_pixels"] != expected["changed_pixels"]:
            raise ValueError(f"{subject_id}: event absorbed scene-wide pixels")
        actual_bounds.append(actual)
        for region in event["difference_regions"]:
            candidates = set(region["cause_envelope"]["candidate_changed_fact_ids"])
            if candidates != event_facts:
                raise ValueError(
                    f"attribution leakage in {region['id']}: "
                    f"expected={sorted(event_facts)}, actual={sorted(candidates)}"
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
        for difference in report["atomic_differences"]
        if difference["domain"] == "geometry.position"
    ]
    magnitudes = [
        difference["magnitude"]["parameter_abs_user_units"]
        for difference in differences
    ]
    if magnitudes != [4, 1]:
        raise ValueError(f"geometry magnitudes are not descending: {magnitudes}")
    if any(
        difference["domain_ordering"]["policy_id"] != "v2_domain_lexicographic"
        for difference in differences
    ):
        raise ValueError("magnitude ordering lost its policy identity")


def validate_reference_cycle(report: dict) -> None:
    if report["analysis_status"] != "failed":
        raise ValueError("cyclic local reference graph was not rejected")
    if diagnostic_codes(report) != {"reference_cycle_detected"}:
        raise ValueError("cyclic reference case lost its stable Diagnostic")
    if report["atomic_differences"] or report["events"]:
        raise ValueError("cyclic reference failure exposed a partial inventory")
    locations = [
        location
        for diagnostic in report["diagnostics"]
        for location in diagnostic["source_locations"]
    ]
    if {location["source_role"] for location in locations} != {"before", "after"}:
        raise ValueError("cyclic reference Diagnostic lost source-role locations")


def validate_reference_expansion(report: dict) -> None:
    if report["analysis_status"] != "failed":
        raise ValueError("explosive acyclic reference graph was not rejected")
    if diagnostic_codes(report) != {"reference_expansion_limit_exceeded"}:
        raise ValueError("reference expansion case lost its stable Diagnostic")
    if report["atomic_differences"] or report["events"]:
        raise ValueError("reference expansion failure exposed a partial inventory")


def validate_use_invalid_reference(report: dict) -> None:
    if report["analysis_status"] != "partial":
        raise ValueError("missing use target produced complete analysis")
    if diagnostic_codes(report) != {
        "analysis_coverage_unproven",
        "use_target_missing",
    }:
        raise ValueError("missing use target lost its stable Diagnostic")
    if report["atomic_differences"] or report["events"]:
        raise ValueError("missing use target invented a visual difference")
    locations = [
        location
        for diagnostic in report["diagnostics"]
        for location in diagnostic["source_locations"]
    ]
    if {location["source_role"] for location in locations} != {"before", "after"}:
        raise ValueError("missing use target Diagnostic lost source-role locations")


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
        "viewport_false_complete": validate_viewport_false_complete,
        "false_equality": lambda case, report: validate_false_equality(case, report),
        "structural_false_equality": lambda _case, report: validate_structural_false_equality(report),
        "wrong_alignment": lambda _case, report: validate_wrong_alignment(report),
        "attribution_leakage": validate_attribution_leakage,
        "magnitude_ordering": lambda _case, report: validate_magnitude_ordering(report),
        "reference_cycle": lambda _case, report: validate_reference_cycle(report),
        "resource_dependency_cycle": lambda _case, report: validate_reference_cycle(report),
        "reference_expansion": lambda _case, report: validate_reference_expansion(report),
        "use_invalid_reference": lambda _case, report: validate_use_invalid_reference(report),
    }
    for case in cases:
        report, report_sha256 = run_case(args.cli, case)
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
