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

from evaluation.report_causes import cause_candidate_difference_ids
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


def checked_path(relative_path: str) -> Path:
    path = (ROOT / relative_path).resolve()
    if ROOT not in path.parents:
        raise ValueError(f"path escapes repository: {relative_path}")
    return path


def generate(cli: Path, case: dict[str, Any]) -> bytes:
    result = subprocess.run(
        [
            str(cli),
            str(checked_path(case["before"])),
            str(checked_path(case["after"])),
            *case.get("cli_args", []),
        ],
        check=False,
        capture_output=True,
    )
    expected_status = case.get("expected_exit_status", 0)
    if result.returncode != expected_status or result.stderr:
        raise ValueError(
            f"{case['id']}: CLI returned status {result.returncode}, "
            f"expected {expected_status}: "
            f"{result.stderr.decode(errors='replace')!r}"
        )
    return result.stdout


def differences(report: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        item
        for group in report["difference_groups"]
        for item in group["items"]
    ]


def nested_value(value: Any, path: str) -> Any:
    current = value
    for component in path.split("."):
        if not isinstance(current, dict) or component not in current:
            raise KeyError(path)
        current = current[component]
    return current


def event_for_difference(
    report: dict[str, Any], difference_id: str
) -> dict[str, Any]:
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


def public_magnitude_value(
    report: dict[str, Any],
    difference: dict[str, Any],
    path: str,
) -> Any:
    event = event_for_difference(report, difference["id"])
    if path == "magnitude.raster_changed_fraction":
        return event["outcome"]["changed_fraction"]
    if path == "magnitude.raster_linear_rgba_rmse":
        return event["outcome"]["linear_rgba_rmse"]
    for prefix in (
        "magnitude.painted_boundary_displacement.",
        "magnitude.painted_coverage_difference.",
    ):
        if path.startswith(prefix):
            try:
                return nested_value(difference, path)
            except KeyError:
                return nested_value(
                    event["outcome"]["isolated_subject"],
                    path.removeprefix("magnitude."),
                )
    return nested_value(difference, path)


def public_magnitude_path(path: str) -> str | None:
    removed = {
        "magnitude.painted_boundary_displacement.before_sample_count",
        "magnitude.painted_boundary_displacement.after_sample_count",
    }
    if path in removed:
        return None
    replacements = {
        "magnitude.raster_changed_pixel_fraction": "magnitude.raster_changed_fraction",
        "magnitude.raster_linear_premultiplied_rgba_rmse": "magnitude.raster_linear_rgba_rmse",
        "magnitude.transform_effect.": "magnitude.transform.",
        "magnitude.intrinsic_raster.changed_pixel_fraction": "magnitude.intrinsic_raster.changed_fraction",
        "magnitude.intrinsic_raster.linear_premultiplied_rgba_rmse": "magnitude.intrinsic_raster.linear_rgba_rmse",
        "magnitude.painted_coverage_difference.before_coverage_css_px2": "magnitude.painted_coverage_difference.before_css_px2",
        "magnitude.painted_coverage_difference.after_coverage_css_px2": "magnitude.painted_coverage_difference.after_css_px2",
        "magnitude.painted_coverage_difference.union_coverage_css_px2": "magnitude.painted_coverage_difference.union_css_px2",
    }
    for old, new in replacements.items():
        if old in path:
            return path.replace(old, new)
    return path


def assert_semantics(case: dict[str, Any], report: dict[str, Any]) -> None:
    expected = case["expected"]
    items = differences(report)
    actual = {
        "analysis_status": report["analysis_status"],
        "domains": [item["kind"] for item in items],
        "computed_relations": [item["effective"]["relation"] for item in items],
        "diagnostic_codes": [item["code"] for item in report["limitations"]],
    }
    for field, value in actual.items():
        if value != expected[field]:
            raise ValueError(
                f"{case['id']}: expected {field}={expected[field]!r}, got {value!r}"
            )

    comparison = report["comparison"]
    if comparison.get("perceptual_background") != expected.get(
        "perceptual_background"
    ):
        raise ValueError(f"{case['id']}: Perceptual Background drifted")
    expected_viewing = expected.get("flip_viewing_conditions")
    if comparison.get("flip_pixels_per_degree") != (
        expected_viewing or {}
    ).get("pixels_per_degree"):
        raise ValueError(f"{case['id']}: FLIP viewing conditions drifted")
    expected_threshold = expected.get("flip_error_threshold")
    if comparison.get("flip_error_threshold") != (expected_threshold or {}).get(
        "value"
    ):
        raise ValueError(f"{case['id']}: FLIP threshold drifted")

    by_kind = {item["kind"]: item for item in items}
    for check in expected["magnitude_checks"]:
        item = by_kind.get(check["domain"])
        if item is None:
            raise ValueError(f"{case['id']}: missing kind {check['domain']}")
        path = public_magnitude_path(check["field"])
        if path is None:
            continue
        try:
            actual_value = public_magnitude_value(report, item, path)
        except KeyError as error:
            raise ValueError(f"{case['id']}: missing public magnitude {path}") from error
        expected_value = check["value"]
        if check["op"] == "eq":
            matches = actual_value == expected_value
        elif check["op"] == "gt":
            matches = isinstance(actual_value, (int, float)) and actual_value > expected_value
        elif check["op"] == "lt":
            matches = isinstance(actual_value, (int, float)) and actual_value < expected_value
        else:
            matches = False
        if not matches:
            raise ValueError(
                f"{case['id']}: {path}={actual_value!r} does not "
                f"satisfy {check['op']} {expected_value!r}"
            )

    expected_color = expected.get("perceptual_color")
    if expected_color is not None:
        event = next(
            item for item in report["events"] if item["id"] == expected_color["event_id"]
        )
        actual_color = event["outcome"].get("perceptual_color")
        if actual_color != {
            "sample_count": expected_color["sample_count"],
            "mean_delta_e_ok": expected_color["mean_delta_e_ok"],
        }:
            raise ValueError(f"{case['id']}: perceptual color drifted")

    expected_flip = expected.get("perceptual_flip")
    if expected_flip is not None:
        event = next(
            item for item in report["events"] if item["id"] == expected_flip["event_id"]
        )
        actual_flip = event["outcome"].get("perceptual_difference")
        expected_statistics = expected_flip["statistics"]
        expected_public = {
            key: expected_statistics[key]
            for key in (
                "canvas_mean",
                "event_region_mean",
                "response_p95",
                "response_maximum",
                "area_above_threshold",
            )
        }
        if actual_flip != expected_public:
            raise ValueError(f"{case['id']}: perceptual difference drifted")


def assert_report_links(case: dict[str, Any], report: dict[str, Any]) -> None:
    items = differences(report)
    difference_ids = {item["id"] for item in items}
    limitation_ids = {item["id"] for item in report["limitations"]}
    if len(difference_ids) != len(items):
        raise ValueError(f"{case['id']}: duplicate Atomic Difference ID")
    for item in items:
        if not set(item["effective"].get("limitation_ids", [])) <= limitation_ids:
            raise ValueError(f"{case['id']}: unknown difference limitation link")
    for event in report["events"]:
        if not set(event["difference_ids"]) <= difference_ids:
            raise ValueError(f"{case['id']}: unknown event difference link")
        for region in event["regions"]:
            causes = region["possible_causes"]
            try:
                cause_candidate_difference_ids(causes, difference_ids)
            except ValueError as error:
                raise ValueError(f"{case['id']}: {error}") from error
            if not set(causes.get("limitation_ids", [])) <= limitation_ids:
                raise ValueError(f"{case['id']}: unknown region limitation link")
    scene = report["scene"]
    before_object_ids = {item["id"] for item in scene["before_objects"]}
    after_object_ids = {item["id"] for item in scene["after_objects"]}
    alignment_ids = {item["id"] for item in scene["alignments"]}
    evidence_event_ids = {item["id"] for item in report["events"]}
    summary = scene["summary"]
    if summary["before_object_count"] != len(before_object_ids):
        raise ValueError(f"{case['id']}: before object count mismatch")
    if summary["after_object_count"] != len(after_object_ids):
        raise ValueError(f"{case['id']}: after object count mismatch")
    if summary["before_relation_count"] != len(scene["before_relations"]):
        raise ValueError(f"{case['id']}: before relation count mismatch")
    if summary["after_relation_count"] != len(scene["after_relations"]):
        raise ValueError(f"{case['id']}: after relation count mismatch")
    for alignment in scene["alignments"]:
        if not set(alignment["before"]) <= before_object_ids:
            raise ValueError(f"{case['id']}: unknown before object alignment link")
        if not set(alignment["after"]) <= after_object_ids:
            raise ValueError(f"{case['id']}: unknown after object alignment link")
    for relation in scene["before_relations"]:
        if not set(relation["endpoints"]) <= before_object_ids:
            raise ValueError(f"{case['id']}: unknown before relation endpoint")
    for relation in scene["after_relations"]:
        if not set(relation["endpoints"]) <= after_object_ids:
            raise ValueError(f"{case['id']}: unknown after relation endpoint")
    if summary["object_set"] == "preserved" and (
        summary["before_object_count"] != summary["after_object_count"]
        or any(
            item["relation"] in {"insertion", "deletion"}
            for item in scene["alignments"]
        )
    ):
        raise ValueError(f"{case['id']}: invalid preserved object set")
    event_axes = {
        "content.change": "content",
        "object.presence": "object_set",
        "relation.change": "relation_graph",
        "layout.reflow": "layout",
        "layout.global_affine": "layout",
        "style.change": "style",
        "representation.change": "representation",
    }
    for event in scene["events"]:
        if summary[event_axes[event["kind"]]] != "changed":
            raise ValueError(f"{case['id']}: scene event contradicts its axis")
        if not set(event["object_alignment_ids"]) <= alignment_ids:
            raise ValueError(f"{case['id']}: unknown scene alignment link")
        if not set(event["difference_ids"]) <= difference_ids:
            raise ValueError(f"{case['id']}: unknown scene difference link")
        if not set(event["evidence_event_ids"]) <= evidence_event_ids:
            raise ValueError(f"{case['id']}: unknown scene evidence event link")
        if event["evidence_difference_count"] != sum(
            item["count"] for item in event["evidence_domains"]
        ):
            raise ValueError(f"{case['id']}: scene evidence count mismatch")


def assert_representative_states(reports: dict[str, dict[str, Any]]) -> None:
    equivalent = differences(reports["equivalent-color-spelling"])[0]
    event = event_for_difference(
        reports["equivalent-color-spelling"], equivalent["id"]
    )
    if not (
        equivalent["effective"]["relation"] == "equivalent"
        and event["outcome"]["changed_fraction"] == 0
        and event["outcome"]["linear_rgba_rmse"] == 0
    ):
        raise ValueError("effective-equivalent measured zero is not explicit")
    rendered_change = reports["salient-fill-change"]
    if not any(event["outcome"].get("changed_pixels", 0) > 0 for event in rendered_change["events"]):
        raise ValueError("rendered-nonzero outcome is not explicit")
    partial = reports["unsupported-partial-coverage"]
    if partial["analysis_status"] != "partial" or not partial["limitations"]:
        raise ValueError("partial outcome lacks limitations")
    failed = reports["reference-cycle-failure"]
    if failed["analysis_status"] != "failed" or not failed["limitations"]:
        raise ValueError("failed outcome lacks limitations")


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
    cases = manifest.get("cases")
    if manifest.get("schema_version") != "svgdiff-schema-examples/1" or not cases:
        raise ValueError("unsupported or empty schema-example manifest")

    reports: dict[str, dict[str, Any]] = {}
    for case in cases:
        encoded = generate(args.cli.resolve(), case)
        report = json.loads(encoded)
        reports[case["id"]] = report
        validate_instance(report, schema, schema)
        assert_semantics(case, report)
        assert_report_links(case, report)
        output = checked_path(case["output"])
        if args.update:
            output.parent.mkdir(parents=True, exist_ok=True)
            output.write_bytes(encoded)
        elif not output.is_file() or output.read_bytes() != encoded:
            raise ValueError(
                f"{case['id']}: checked-in example drifted; run the update command"
            )

    assert_representative_states(reports)

    missing_required = copy.deepcopy(reports["equivalent-color-spelling"])
    del missing_required["analysis_status"]
    expect_schema_rejection(missing_required, schema, "missing required property")
    unexpected_internal = copy.deepcopy(reports["equivalent-color-spelling"])
    unexpected_internal["coverage_matrix"] = []
    expect_schema_rejection(unexpected_internal, schema, "internal field leaked")
    invalid_fraction = copy.deepcopy(reports["salient-fill-change"])
    invalid_fraction["canvas"]["changed_fraction"] = 2
    expect_schema_rejection(invalid_fraction, schema, "out-of-range canvas fraction")
    invalid_background = copy.deepcopy(reports["salient-fill-change"])
    invalid_background["comparison"]["perceptual_background"]["red"] = 256
    expect_schema_rejection(invalid_background, schema, "invalid background")

    print(f"validated {len(cases)} schema examples")


if __name__ == "__main__":
    main()
