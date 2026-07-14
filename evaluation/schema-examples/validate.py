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

    action = "updated" if args.update else "validated"
    print(f"Schema examples: {len(cases)} production reports {action}")


if __name__ == "__main__":
    main()
