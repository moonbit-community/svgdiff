#!/usr/bin/env python3

import argparse
import copy
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
SCHEMA_PATH = ROOT / "schema/svgdiff-report.schema.json"
MANIFEST_PATH = ROOT / "evaluation/schema-examples/manifest.v1.json"
SCHEMA_KEYWORDS = {
    "$schema",
    "$id",
    "title",
    "$defs",
    "$ref",
    "type",
    "const",
    "enum",
    "minimum",
    "minLength",
    "minItems",
    "required",
    "properties",
    "additionalProperties",
    "items",
    "anyOf",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate and validate canonical Structured Report examples."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--update", action="store_true")
    return parser.parse_args()


def audit_schema(schema: Any, path: str = "#") -> None:
    if not isinstance(schema, dict):
        raise ValueError(f"schema at {path} must be an object")
    unknown = set(schema) - SCHEMA_KEYWORDS
    if unknown:
        raise ValueError(
            f"unsupported schema keywords at {path}: {sorted(unknown)}"
        )
    for group in ("$defs", "properties"):
        for name, child in schema.get(group, {}).items():
            audit_schema(child, f"{path}/{group}/{name}")
    if isinstance(schema.get("items"), dict):
        audit_schema(schema["items"], f"{path}/items")
    if isinstance(schema.get("additionalProperties"), dict):
        audit_schema(schema["additionalProperties"], f"{path}/additionalProperties")
    for index, child in enumerate(schema.get("anyOf", [])):
        audit_schema(child, f"{path}/anyOf/{index}")


def resolve_ref(root: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise ValueError(f"only local JSON pointers are supported: {reference}")
    current: Any = root
    for encoded in reference[2:].split("/"):
        component = encoded.replace("~1", "/").replace("~0", "~")
        if not isinstance(current, dict) or component not in current:
            raise ValueError(f"unresolved schema reference: {reference}")
        current = current[component]
    if not isinstance(current, dict):
        raise ValueError(f"schema reference does not resolve to an object: {reference}")
    return current


def type_matches(value: Any, type_name: str) -> bool:
    if type_name == "null":
        return value is None
    if type_name == "boolean":
        return isinstance(value, bool)
    if type_name == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_name == "string":
        return isinstance(value, str)
    if type_name == "array":
        return isinstance(value, list)
    if type_name == "object":
        return isinstance(value, dict)
    raise ValueError(f"unsupported schema type: {type_name}")


def validate_instance(
    value: Any,
    schema: dict[str, Any],
    root: dict[str, Any],
    path: str = "$",
) -> None:
    if "anyOf" in schema:
        errors = []
        for child in schema["anyOf"]:
            try:
                validate_instance(value, child, root, path)
                return
            except ValueError as error:
                errors.append(str(error))
        raise ValueError(f"{path}: no anyOf branch matched: {errors}")
    if "$ref" in schema:
        validate_instance(value, resolve_ref(root, schema["$ref"]), root, path)
        return
    if "const" in schema and value != schema["const"]:
        raise ValueError(f"{path}: expected constant {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{path}: value {value!r} is not in the declared enum")
    declared_type = schema.get("type")
    if declared_type is not None:
        types = declared_type if isinstance(declared_type, list) else [declared_type]
        if not all(isinstance(item, str) for item in types):
            raise ValueError(f"{path}: invalid schema type declaration")
        if not any(type_matches(value, item) for item in types):
            raise ValueError(f"{path}: expected type {types}, got {type(value).__name__}")

    if isinstance(value, dict) and declared_type == "object":
        required = schema.get("required", [])
        missing = [name for name in required if name not in value]
        if missing:
            raise ValueError(f"{path}: missing required properties {missing}")
        properties = schema.get("properties", {})
        for name, child in properties.items():
            if name in value:
                validate_instance(value[name], child, root, f"{path}.{name}")
        extras = set(value) - set(properties)
        additional = schema.get("additionalProperties", True)
        if additional is False and extras:
            raise ValueError(f"{path}: unexpected properties {sorted(extras)}")
        if isinstance(additional, dict):
            for name in extras:
                validate_instance(value[name], additional, root, f"{path}.{name}")

    if isinstance(value, list) and declared_type == "array":
        if len(value) < schema.get("minItems", 0):
            raise ValueError(f"{path}: array is shorter than minItems")
        if isinstance(schema.get("items"), dict):
            for index, item in enumerate(value):
                validate_instance(item, schema["items"], root, f"{path}[{index}]")

    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        raise ValueError(f"{path}: string is shorter than minLength")
    if (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and "minimum" in schema
        and value < schema["minimum"]
    ):
        raise ValueError(f"{path}: number is below minimum")


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
