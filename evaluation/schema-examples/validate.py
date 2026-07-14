#!/usr/bin/env python3

import argparse
import copy
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.schema_validation import audit_schema, validate_instance


SCHEMA_PATH = ROOT / "schema/svgdiff-report.schema.json"
MANIFEST_PATH = ROOT / "evaluation/schema-examples/manifest.v1.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate and validate canonical Structured Report examples."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--update", action="store_true")
    return parser.parse_args()


def nested_value(value: Any, path: str) -> Any:
    current = value
    for component in path.split("."):
        if not isinstance(current, dict) or component not in current:
            raise ValueError(f"missing semantic assertion path: {path}")
        current = current[component]
    return current


def assert_semantics(case: dict[str, Any], report: dict[str, Any]) -> None:
    expected = case["expected"]
    differences = report["atomic_differences"]
    actual = {
        "analysis_status": report["analysis_status"],
        "domains": [item["domain"] for item in differences],
        "computed_relations": [
            item["computed_relation"]["status"] for item in differences
        ],
        "diagnostic_codes": [item["code"] for item in report["diagnostics"]],
    }
    for field in actual:
        if actual[field] != expected[field]:
            raise ValueError(
                f"{case['id']}: expected {field}={expected[field]!r}, "
                f"got {actual[field]!r}"
            )
    by_domain = {item["domain"]: item for item in differences}
    for check in expected["magnitude_checks"]:
        if check["domain"] not in by_domain:
            raise ValueError(f"{case['id']}: missing domain {check['domain']}")
        actual_value = nested_value(by_domain[check["domain"]], check["field"])
        expected_value = check["value"]
        operators = {
            "eq": actual_value == expected_value,
            "gt": actual_value > expected_value,
            "lt": actual_value < expected_value,
        }
        if check["op"] not in operators or not operators[check["op"]]:
            raise ValueError(
                f"{case['id']}: {check['field']}={actual_value!r} does not "
                f"satisfy {check['op']} {expected_value!r}"
            )


def assert_coverage_summary(case: dict[str, Any], report: dict[str, Any]) -> None:
    rows = report.get("coverage_matrix")
    if not isinstance(rows, list) or not rows:
        raise ValueError(f"{case['id']}: report has no explicit coverage summary")
    diagnostics = {
        diagnostic["id"]: diagnostic for diagnostic in report["diagnostics"]
    }
    keys = []
    strongest = "complete"
    valid_states = {"covered", "limited", "not_applicable", "failed"}
    layers = ("source_semantics", "computed_appearance", "rendered_evidence")
    for index, row in enumerate(rows):
        feature_id = row.get("feature_id")
        subject_id = row.get("subject_id")
        if not isinstance(feature_id, str) or not feature_id:
            raise ValueError(f"{case['id']}: coverage row {index} lacks feature ID")
        if not isinstance(subject_id, str) or not subject_id:
            raise ValueError(f"{case['id']}: coverage row {index} lacks subject ID")
        keys.append((feature_id, subject_id))
        row_diagnostics = row.get("diagnostic_ids")
        if not isinstance(row_diagnostics, list) or len(row_diagnostics) != len(
            set(row_diagnostics)
        ):
            raise ValueError(
                f"{case['id']}: coverage row {feature_id}/{subject_id} "
                "has invalid Diagnostic references"
            )
        for layer in layers:
            state = row.get(layer)
            if state not in valid_states:
                raise ValueError(
                    f"{case['id']}: coverage row {feature_id}/{subject_id} "
                    f"has invalid {layer} state {state!r}"
                )
            if state in {"limited", "failed"}:
                establishing = [
                    identifier
                    for identifier in row_diagnostics
                    if identifier in diagnostics
                    and layer in diagnostics[identifier]["affected_evidence_layers"]
                ]
                if not establishing:
                    raise ValueError(
                        f"{case['id']}: {feature_id}/{subject_id}/{layer} "
                        "has no establishing Diagnostic"
                    )
            if state == "failed":
                strongest = "failed"
            elif state == "limited" and strongest != "failed":
                strongest = "partial"
    if len(keys) != len(set(keys)):
        raise ValueError(f"{case['id']}: duplicate coverage feature/subject row")
    def shortlex(value: str) -> tuple[int, tuple[int, ...]]:
        return len(value), tuple(ord(character) for character in value)

    expected_keys = sorted(
        keys, key=lambda key: (shortlex(key[0]), shortlex(key[1]))
    )
    if keys != expected_keys:
        raise ValueError(f"{case['id']}: coverage rows are not deterministic")
    if report["analysis_status"] != strongest:
        raise ValueError(
            f"{case['id']}: coverage summary implies {strongest}, "
            f"report says {report['analysis_status']}"
        )


def assert_raw_magnitude_authority(case: dict[str, Any], report: dict[str, Any]) -> None:
    magnitude_fields = (
        "parameter_abs_user_units",
        "parameter_signed_user_units",
        "symmetric_relative",
        "geometry_displacement_css_px",
        "geometry_viewport_fraction",
        "presence_painted_viewport_fraction",
        "raster_changed_pixel_fraction",
        "raster_rgba8_rmse",
        "raster_linear_premultiplied_rgba_rmse",
    )
    for difference in report["atomic_differences"]:
        magnitude = difference.get("magnitude")
        if not isinstance(magnitude, dict) or set(magnitude) != set(magnitude_fields):
            raise ValueError(
                f"{case['id']}: {difference['id']} lost the raw magnitude vector"
            )
        if any(
            value is not None and type(value) not in {int, float}
            for value in magnitude.values()
        ):
            raise ValueError(
                f"{case['id']}: {difference['id']} has a nonnumeric raw magnitude"
            )
        domain = difference["domain"]
        if domain.startswith("geometry."):
            source_fields = (
                "geometry_displacement_css_px",
                "geometry_viewport_fraction",
                "raster_changed_pixel_fraction",
            )
        elif domain.startswith("paint."):
            source_fields = (
                "raster_linear_premultiplied_rgba_rmse",
                "raster_rgba8_rmse",
                "raster_changed_pixel_fraction",
            )
        elif domain.startswith("presence.") or domain == "presence":
            source_fields = (
                "presence_painted_viewport_fraction",
                "raster_changed_pixel_fraction",
            )
        else:
            source_fields = (
                "raster_changed_pixel_fraction",
                "raster_linear_premultiplied_rgba_rmse",
                "raster_rgba8_rmse",
            )
        expected_components = [
            magnitude[field] for field in source_fields if magnitude[field] is not None
        ]
        ordering = difference["domain_ordering"]
        if ordering["policy_id"] != "v1_domain_lexicographic":
            raise ValueError(f"{case['id']}: unknown ordering policy")
        if ordering["components"] != expected_components:
            raise ValueError(
                f"{case['id']}: {difference['id']} ordering is not derived "
                "from retained raw magnitudes"
            )


def assert_alignment_evidence(case: dict[str, Any], report: dict[str, Any]) -> None:
    required = {
        "score_kind",
        "selected_score",
        "candidate_count",
        "equal_score_candidate_count",
        "ambiguity",
        "confidence",
        "confidence_status",
    }
    assessed_score_kinds = {"exact_visual_signature", "property_distance"}
    unassessed_score_kinds = {
        "structural_rule",
        "unmatched",
        "group_identity_or_singleton",
    }
    for index, alignment in enumerate(report["subject_alignments"]):
        evidence = alignment.get("evidence")
        if not isinstance(evidence, dict) or not required <= set(evidence):
            raise ValueError(
                f"{case['id']}: alignment {index} lacks complete selection evidence"
            )
        candidate_count = evidence["candidate_count"]
        equal_count = evidence["equal_score_candidate_count"]
        if (
            not isinstance(candidate_count, int)
            or isinstance(candidate_count, bool)
            or not isinstance(equal_count, int)
            or isinstance(equal_count, bool)
            or candidate_count < 0
            or equal_count < 0
            or equal_count > candidate_count
        ):
            raise ValueError(f"{case['id']}: alignment {index} has invalid counts")
        if evidence["confidence"] is not None or evidence["confidence_status"] != (
            "not_calibrated"
        ):
            raise ValueError(
                f"{case['id']}: alignment {index} invents calibrated confidence"
            )
        score_kind = evidence["score_kind"]
        ambiguity = evidence["ambiguity"]
        if score_kind in assessed_score_kinds:
            if evidence["selected_score"] is None:
                raise ValueError(
                    f"{case['id']}: alignment {index} lacks its selected score"
                )
            if ambiguity == "unique" and equal_count != 1:
                raise ValueError(
                    f"{case['id']}: alignment {index} has inconsistent uniqueness"
                )
            if ambiguity == "tied" and equal_count < 2:
                raise ValueError(
                    f"{case['id']}: alignment {index} has inconsistent tie evidence"
                )
            if ambiguity not in {"unique", "tied"}:
                raise ValueError(
                    f"{case['id']}: alignment {index} lost assessed ambiguity"
                )
        elif score_kind in unassessed_score_kinds:
            if (
                evidence["selected_score"] is not None
                or candidate_count != 0
                or equal_count != 0
                or ambiguity != "not_assessed"
            ):
                raise ValueError(
                    f"{case['id']}: alignment {index} overstates unassessed evidence"
                )
        else:
            raise ValueError(
                f"{case['id']}: alignment {index} has unknown score kind {score_kind!r}"
            )


def assert_diagnostic_locations(case: dict[str, Any], report: dict[str, Any]) -> None:
    sources = {
        "before": checked_path(case["before"]).read_text(encoding="utf-8"),
        "after": checked_path(case["after"]).read_text(encoding="utf-8"),
    }
    required_locations = {
        "unsupported_visual_subject",
        "renderer_fractional_geometry_unproven",
        "renderer_gradient_raster_unproven",
    }
    for index, diagnostic in enumerate(report["diagnostics"]):
        locations = diagnostic.get("source_locations")
        if not isinstance(locations, list):
            raise ValueError(
                f"{case['id']}: Diagnostic {index} has no current source_locations"
            )
        if diagnostic["code"] in required_locations and not locations:
            raise ValueError(
                f"{case['id']}: {diagnostic['code']} lost its source location"
            )
        keys = []
        for location in locations:
            role = location.get("source_role")
            span = location.get("source_span")
            if role not in sources or not isinstance(span, dict):
                raise ValueError(
                    f"{case['id']}: Diagnostic {index} has an invalid source role"
                )
            start = span.get("start_offset")
            end = span.get("end_offset")
            source_length = len(sources[role].encode("utf-16-le")) // 2
            if (
                type(start) is not int
                or type(end) is not int
                or start < 0
                or end < start
                or end > source_length
            ):
                raise ValueError(
                    f"{case['id']}: Diagnostic {index} has an invalid UTF-16 span"
                )
            keys.append((role, start, end))
        if len(keys) != len(set(keys)):
            raise ValueError(
                f"{case['id']}: Diagnostic {index} repeats a source location"
            )


def checked_path(relative_path: str) -> Path:
    path = (ROOT / relative_path).resolve()
    if ROOT not in path.parents:
        raise ValueError(f"path escapes repository: {relative_path}")
    return path


def generate(cli: Path, case: dict[str, Any]) -> bytes:
    result = subprocess.run(
        [str(cli), str(checked_path(case["before"])), str(checked_path(case["after"]))],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0 or result.stderr:
        raise ValueError(
            f"{case['id']}: CLI failed with status {result.returncode}: "
            f"{result.stderr.decode(errors='replace')!r}"
        )
    return result.stdout


def expect_schema_rejection(
    report: dict[str, Any], schema: dict[str, Any], label: str
) -> None:
    try:
        validate_instance(report, schema, schema)
    except ValueError:
        return
    raise ValueError(f"validator negative control unexpectedly accepted: {label}")


def main() -> None:
    args = parse_args()
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    audit_schema(schema)
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-schema-examples/1":
        raise ValueError("unsupported schema-example manifest version")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("schema-example manifest has no cases")
    ids = [case.get("id") for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("schema-example IDs must be unique")

    reports = {}
    for case in cases:
        encoded = generate(args.cli.resolve(), case)
        report = json.loads(encoded)
        reports[case["id"]] = report
        validate_instance(report, schema, schema)
        assert_semantics(case, report)
        assert_coverage_summary(case, report)
        assert_raw_magnitude_authority(case, report)
        assert_alignment_evidence(case, report)
        assert_diagnostic_locations(case, report)
        output = checked_path(case["output"])
        if args.update:
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(encoded)
        elif not output.is_file() or output.read_bytes() != encoded:
            raise ValueError(
                f"{case['id']}: checked-in example drifted; run the update command"
            )

    missing_required = copy.deepcopy(reports["equivalent-color-spelling"])
    del missing_required["analysis_status"]
    expect_schema_rejection(missing_required, schema, "missing required property")
    wrong_nullable_type = copy.deepcopy(reports["equivalent-color-spelling"])
    wrong_nullable_type["atomic_differences"][0]["magnitude"][
        "parameter_abs_user_units"
    ] = "not-a-number"
    expect_schema_rejection(wrong_nullable_type, schema, "wrong nullable type")
    wrong_nullable_fact = copy.deepcopy(reports["subject-insertion"])
    wrong_nullable_fact["changed_facts"][0]["before"] = 7
    expect_schema_rejection(wrong_nullable_fact, schema, "wrong nullable fact")
    incomplete_alignment_evidence = copy.deepcopy(
        reports["equivalent-color-spelling"]
    )
    del incomplete_alignment_evidence["subject_alignments"][0]["evidence"][
        "confidence_status"
    ]
    expect_schema_rejection(
        incomplete_alignment_evidence, schema, "incomplete alignment evidence"
    )
    invalid_diagnostic_role = copy.deepcopy(reports["tiny-numeric-geometry"])
    invalid_diagnostic_role["diagnostics"][0]["source_locations"][0][
        "source_role"
    ] = "left"
    expect_schema_rejection(
        invalid_diagnostic_role, schema, "invalid Diagnostic source role"
    )
    incomplete_diagnostic_location = copy.deepcopy(
        reports["tiny-numeric-geometry"]
    )
    del incomplete_diagnostic_location["diagnostics"][0]["source_locations"][0][
        "source_span"
    ]
    expect_schema_rejection(
        incomplete_diagnostic_location, schema, "incomplete Diagnostic location"
    )

    action = "updated" if args.update else "validated"
    print(f"Schema examples: {len(cases)} production reports {action}")


if __name__ == "__main__":
    main()
