#!/usr/bin/env python3

import argparse
import copy
import hashlib
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.schema_validation import audit_schema, schema_accepts


REGISTRY_PATH = ROOT / "schema/registry.v1.json"
REQUIRED_TOP_LEVEL = {
    "schema_version",
    "analysis_status",
    "profile",
    "subject_alignments",
    "changed_facts",
    "source_resolutions",
    "atomic_differences",
    "events",
    "diagnostics",
}
KNOWN_TOP_LEVEL = REQUIRED_TOP_LEVEL | {
    "coverage_matrix",
    "impact_assessment",
    "renderer_capability_gaps",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate schema and ordering-policy compatibility cases."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "evaluation/compatibility/manifest.v1.json",
    )
    return parser.parse_args()


def checked_source(relative_path: str) -> Path:
    source = (ROOT / relative_path).resolve()
    if ROOT not in source.parents or not source.is_file():
        raise ValueError(f"unsafe or missing compatibility source: {relative_path}")
    return source


def generate_base_report(cli: Path, config: dict) -> dict:
    before = checked_source(config["before"])
    after = checked_source(config["after"])
    result = subprocess.run(
        [
            str(cli),
            str(before),
            str(after),
            "--width",
            str(config["viewport"]["width"]),
            "--height",
            str(config["viewport"]["height"]),
            "--agent-json",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or result.stderr:
        raise ValueError(
            f"base report failed: status={result.returncode}, "
            f"stderr={result.stderr!r}"
        )
    return json.loads(result.stdout)


def descend(document: object, path: list[object]) -> tuple[object, object]:
    if not path:
        raise ValueError("mutation path cannot be empty")
    current = document
    for component in path[:-1]:
        if isinstance(current, dict) and isinstance(component, str):
            current = current[component]
        elif isinstance(current, list) and isinstance(component, int):
            current = current[component]
        else:
            raise ValueError(f"invalid mutation path: {path}")
    return current, path[-1]


def apply_mutation(document: dict, mutation: dict) -> None:
    parent, key = descend(document, mutation["path"])
    operation = mutation.get("op")
    if operation == "remove" and isinstance(parent, dict) and isinstance(key, str):
        if key not in parent:
            raise ValueError(f"remove target does not exist: {mutation['path']}")
        del parent[key]
    elif operation == "set":
        if isinstance(parent, dict) and isinstance(key, str):
            parent[key] = mutation["value"]
        elif isinstance(parent, list) and isinstance(key, int):
            parent[key] = mutation["value"]
        else:
            raise ValueError(f"invalid set target: {mutation['path']}")
    else:
        raise ValueError(f"unsupported mutation: {mutation}")


def path_exists(document: object, path: list[object]) -> bool:
    current = document
    for component in path:
        if isinstance(current, dict) and isinstance(component, str):
            if component not in current:
                return False
            current = current[component]
        elif isinstance(current, list) and isinstance(component, int):
            if component < 0 or component >= len(current):
                return False
            current = current[component]
        else:
            return False
    return True


def classify(report: dict, policy: dict) -> tuple[str, str]:
    if not REQUIRED_TOP_LEVEL <= set(report):
        return "rejected", "malformed_report"
    if report["schema_version"] not in policy["accepted_schema_versions"]:
        return "rejected", "unknown_schema_version"
    if report["schema_version"] == policy["current_schema_version"]:
        impact_assessment = report.get("impact_assessment")
        if not isinstance(impact_assessment, dict) or not isinstance(
            impact_assessment.get("policy_id"), str
        ):
            return "rejected", "malformed_report"
        if impact_assessment["policy_id"] not in policy[
            "accepted_impact_policy_ids"
        ]:
            return "rejected", "unknown_impact_policy"
    profile = report.get("profile")
    if not isinstance(profile, dict):
        return "rejected", "malformed_report"
    renderer_id = profile.get("renderer_id")
    if not isinstance(renderer_id, str):
        return "rejected", "malformed_report"
    if renderer_id not in policy["accepted_renderer_ids"]:
        return "rejected", "unknown_renderer_id"
    conformance_profile_id = profile.get("renderer_conformance_profile_id")
    if conformance_profile_id is not None:
        if not isinstance(conformance_profile_id, str):
            return "rejected", "malformed_report"
        if conformance_profile_id not in policy[
            "accepted_renderer_conformance_profile_ids"
        ]:
            return "rejected", "unknown_renderer_conformance_profile"
    differences = report.get("atomic_differences")
    if not isinstance(differences, list):
        return "rejected", "malformed_report"
    for difference in differences:
        ordering = difference.get("domain_ordering")
        if not isinstance(ordering, dict) or not isinstance(
            ordering.get("policy_id"), str
        ):
            return "rejected", "malformed_report"
        if ordering["policy_id"] not in policy["accepted_ordering_policy_ids"]:
            return "rejected", "unknown_ordering_policy"
    if any(not path_exists(report, path) for path in policy["legacy_optional_paths"]):
        return "accepted", "accepted_legacy_optional_fields"
    if report["schema_version"] != policy["current_schema_version"]:
        return "accepted", "accepted_legacy_schema"
    if set(report) - KNOWN_TOP_LEVEL:
        return "accepted", "accepted_additive_fields"
    return "accepted", "accepted_current"


def load_released_schemas(
    policy: dict, case_ids: set[str]
) -> tuple[dict, dict[str, dict]]:
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    if registry.get("schema_version") != "svgdiff-schema-registry/1":
        raise ValueError("unsupported released-schema registry")
    entries = registry.get("released_schemas")
    if not isinstance(entries, list) or not entries:
        raise ValueError("released-schema registry is empty")
    versions = [entry.get("report_schema_version") for entry in entries]
    if len(versions) != len(set(versions)):
        raise ValueError("released report Schema versions must be unique")
    if set(versions) != set(policy["accepted_schema_versions"]):
        raise ValueError(
            "consumer accepted Schema versions and released registry differ"
        )

    schemas = {}
    for entry in entries:
        version = entry["report_schema_version"]
        schema_path = checked_source(entry["schema"])
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        audit_schema(schema)
        if schema.get("properties", {}).get("schema_version", {}).get("const") != version:
            raise ValueError(f"Schema file does not declare registry version {version}")
        if not set(entry["accepted_ordering_policy_ids"]) <= set(
            policy["accepted_ordering_policy_ids"]
        ):
            raise ValueError(f"Schema {version} registers an unaccepted ordering policy")
        registered_impact_policies = entry.get("accepted_impact_policy_ids", [])
        if not isinstance(registered_impact_policies, list) or not set(
            registered_impact_policies
        ) <= set(policy["accepted_impact_policy_ids"]):
            raise ValueError(f"Schema {version} registers an unaccepted Impact policy")
        if version in ("1.43", "1.44") and registered_impact_policies != [
            "event_rendered_pareto/v1"
        ]:
            raise ValueError("Impact-era Schema does not register its Impact policy")
        if version not in ("1.43", "1.44") and registered_impact_policies:
            raise ValueError(f"legacy Schema {version} unexpectedly registers Impact")
        registered_cases = entry.get("compatibility_case_ids")
        if not isinstance(registered_cases, list) or not registered_cases:
            raise ValueError(f"Schema {version} has no compatibility cases")
        if not set(registered_cases) <= case_ids:
            raise ValueError(f"Schema {version} references an unknown compatibility case")
        example_manifest = json.loads(
            checked_source(entry["canonical_examples"]).read_text(encoding="utf-8")
        )
        examples = example_manifest.get("cases")
        if not isinstance(examples, list) or not examples:
            raise ValueError(f"Schema {version} has no canonical examples")
        for example in examples:
            report = json.loads(
                checked_source(example["output"]).read_text(encoding="utf-8")
            )
            if report.get("schema_version") != version or not schema_accepts(
                report, schema
            ):
                raise ValueError(
                    f"canonical example {example['id']} is invalid for Schema {version}"
                )
        schemas[version] = schema
    return registry, schemas


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-compatibility-corpus/1":
        raise ValueError("unsupported compatibility manifest schema")
    policy = manifest.get("consumer_policy")
    if policy.get("policy_id") != "svgdiff-consumer-compatibility/1":
        raise ValueError("unsupported consumer compatibility policy")
    if policy.get("current_schema_version") not in policy.get(
        "accepted_schema_versions", []
    ):
        raise ValueError("current Schema is not accepted by the consumer policy")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("compatibility corpus contains no cases")
    ids = [case.get("id") for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("compatibility case IDs must be unique")
    registry, schemas = load_released_schemas(policy, set(ids))
    base_report = generate_base_report(args.cli, manifest["base_report"])

    results = []
    for case in cases:
        report = copy.deepcopy(base_report)
        for mutation in case["mutations"]:
            apply_mutation(report, mutation)
        decision, reason = classify(report, policy)
        if (decision, reason) != (
            case["expected_decision"],
            case["expected_reason"],
        ):
            raise ValueError(
                f"compatibility mismatch for {case['id']}: "
                f"expected={(case['expected_decision'], case['expected_reason'])}, "
                f"actual={(decision, reason)}"
            )
        declared_version = report.get("schema_version")
        if declared_version in schemas:
            schema_valid = schema_accepts(report, schemas[declared_version])
        else:
            schema_valid = any(
                schema_accepts(report, schema) for schema in schemas.values()
            )
        schema_validation = "valid" if schema_valid else "invalid"
        if schema_validation != case["expected_schema_validation"]:
            raise ValueError(
                f"Schema validation mismatch for {case['id']}: "
                f"expected={case['expected_schema_validation']}, "
                f"actual={schema_validation}"
            )
        encoded = json.dumps(report, sort_keys=True, separators=(",", ":")).encode()
        results.append(
            {
                "id": case["id"],
                "decision": decision,
                "reason": reason,
                "schema_validation": schema_validation,
                "report_sha256": hashlib.sha256(encoded).hexdigest(),
            }
        )

    output = {
        "schema_version": "svgdiff-compatibility-results/1",
        "corpus_version": manifest["schema_version"],
        "consumer_policy_id": policy["policy_id"],
        "schema_registry_version": registry["schema_version"],
        "cases": results,
    }
    args.output.write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    accepted = sum(result["decision"] == "accepted" for result in results)
    rejected = len(results) - accepted
    print(
        f"Compatibility corpus: {accepted} accepted, {rejected} rejected as expected"
    )


if __name__ == "__main__":
    main()
