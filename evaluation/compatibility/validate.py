#!/usr/bin/env python3

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
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
    if set(report) - KNOWN_TOP_LEVEL:
        return "accepted", "accepted_additive_fields"
    return "accepted", "accepted_current"


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-compatibility-corpus/1":
        raise ValueError("unsupported compatibility manifest schema")
    policy = manifest.get("consumer_policy")
    if policy.get("policy_id") != "svgdiff-consumer-compatibility/1":
        raise ValueError("unsupported consumer compatibility policy")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("compatibility corpus contains no cases")
    ids = [case.get("id") for case in cases]
    if len(ids) != len(set(ids)):
        raise ValueError("compatibility case IDs must be unique")
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
        encoded = json.dumps(report, sort_keys=True, separators=(",", ":")).encode()
        results.append(
            {
                "id": case["id"],
                "decision": decision,
                "reason": reason,
                "report_sha256": hashlib.sha256(encoded).hexdigest(),
            }
        )

    output = {
        "schema_version": "svgdiff-compatibility-results/1",
        "corpus_version": manifest["schema_version"],
        "consumer_policy_id": policy["policy_id"],
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
