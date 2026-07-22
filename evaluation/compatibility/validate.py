#!/usr/bin/env python3

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.schema_validation import audit_schema, schema_accepts


MANIFEST_PATH = ROOT / "evaluation/compatibility/manifest.v1.json"
REGISTRY_PATH = ROOT / "schema/registry.v1.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def checked_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if ROOT not in path.parents:
        raise ValueError(f"path escapes repository: {relative}")
    return path


def load_json(relative: str) -> dict[str, Any]:
    return json.loads(checked_path(relative).read_text(encoding="utf-8"))


def validate_registry(policy: dict[str, Any], case_ids: set[str]) -> dict[str, dict]:
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    if registry.get("schema_version") != "svgdiff-schema-registry/1":
        raise ValueError("unsupported schema registry")
    entries = registry.get("released_schemas")
    versions = [entry["report_schema_version"] for entry in entries]
    if versions != policy["accepted_schema_versions"]:
        raise ValueError("consumer policy and schema registry versions differ")
    if len(versions) != len(set(versions)):
        raise ValueError("duplicate released schema version")

    schemas: dict[str, dict] = {}
    for entry in entries:
        version = entry["report_schema_version"]
        schema = load_json(entry["schema"])
        audit_schema(schema)
        if schema.get("properties", {}).get("schema_version", {}).get("const") != version:
            raise ValueError(f"Schema file does not declare {version}")
        if not set(entry["compatibility_case_ids"]) <= case_ids:
            raise ValueError(f"Schema {version} references an unknown case")
        manifest = load_json(entry["canonical_examples"])
        examples = manifest.get("cases")
        if not examples:
            raise ValueError(f"Schema {version} has no canonical examples")
        for example in examples:
            report = load_json(example["output"])
            if report.get("schema_version") != version or not schema_accepts(
                report, schema
            ):
                raise ValueError(
                    f"Schema {version} rejects canonical example {example['output']}"
                )
        schemas[version] = schema
    return schemas


def generate_current(cli: Path) -> dict[str, Any]:
    result = subprocess.run(
        [
            str(cli),
            str(ROOT / "testdata/before.svg"),
            str(ROOT / "testdata/after.svg"),
            "--agent-json",
        ],
        check=True,
        capture_output=True,
    )
    if result.stderr:
        raise ValueError(f"current producer wrote stderr: {result.stderr!r}")
    return json.loads(result.stdout)


def main() -> None:
    args = parse_args()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-compatibility-corpus/1":
        raise ValueError("unsupported compatibility manifest")
    policy = manifest["consumer_policy"]
    cases = manifest["cases"]
    case_ids = {case["id"] for case in cases}
    schemas = validate_registry(policy, case_ids)

    current = generate_current(args.cli.resolve())
    current_version = policy["current_schema_version"]
    if current.get("schema_version") != current_version or not schema_accepts(
        current, schemas[current_version]
    ):
        raise ValueError("current producer does not satisfy current schema")

    results = []
    for case in cases:
        version = case["schema_version"]
        if version not in schemas:
            decision = "rejected"
            reason = "unknown_schema_version"
        else:
            decision = "accepted"
            reason = "accepted_current"
        if decision != (
            "rejected" if case["expected_decision"] == "rejected" else "accepted"
        ):
            raise ValueError(f"{case['id']}: compatibility decision drifted")
        results.append({"id": case["id"], "decision": decision, "reason": reason})

    output = {
        "schema_version": "svgdiff-compatibility-results/1",
        "consumer_policy_id": policy["policy_id"],
        "current_schema_version": current_version,
        "cases": results,
    }
    args.output.write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
