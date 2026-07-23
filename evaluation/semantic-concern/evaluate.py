#!/usr/bin/env python3

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.report_causes import (
    cause_candidate_difference_ids,
    report_difference_ids,
)


MANIFEST_PATH = ROOT / "evaluation/semantic-concern/manifest.v1.json"
RESULTS_PATH = ROOT / "evaluation/semantic-concern/results.v1.json"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def checked_source(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    require(ROOT in path.parents and path.is_file(), f"unsafe source: {relative}")
    return path


def run_report(cli: Path, manifest: dict[str, Any], compact: bool) -> dict[str, Any]:
    case = manifest["case"]
    command = [
        str(cli), str(checked_source(case["before"])),
        str(checked_source(case["after"])), "--width",
        str(case["viewport"]["width"]), "--height",
        str(case["viewport"]["height"]),
    ]
    if compact:
        command.append("--agent-json")
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    require(result.returncode == 0 and not result.stderr, "CLI failed")
    return json.loads(result.stdout)


def index(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result = {item["id"]: item for item in items}
    require(len(result) == len(items), "duplicate report ID")
    return result


def source_pair_hash(manifest: dict[str, Any]) -> str:
    digest = hashlib.sha256()
    for side in ("before", "after"):
        relative = manifest["case"][side]
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update(checked_source(relative).read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def has_forbidden_semantic_field(value: Any) -> bool:
    forbidden = {
        "semantic_concern", "semantic_concerns", "semantic_importance",
        "business_importance", "caller_concern",
    }
    if isinstance(value, dict):
        return bool(forbidden.intersection(value)) or any(
            has_forbidden_semantic_field(child) for child in value.values()
        )
    if isinstance(value, list):
        return any(has_forbidden_semantic_field(child) for child in value)
    return False


def build_results(cli: Path) -> dict[str, Any]:
    manifest = load_json(MANIFEST_PATH)
    report = run_report(cli, manifest, compact=False)
    compact = run_report(cli, manifest, compact=True)
    require(report == compact, "compact transport changed the report")
    require(report["schema_version"] == manifest["report_schema_version"], "schema drift")
    require(report["analysis_status"] == "complete", "comparison is not complete")

    events = index(report["events"])
    difference_items = [
        item for group in report["difference_groups"] for item in group["items"]
    ]
    differences = index(difference_items)
    selector = manifest["caller_concern"]["selector"]
    expected_bounds = selector["region_css_bounds"]
    matches = [
        event for event in report["events"]
        if any(region["bounds"] == expected_bounds for region in event["regions"])
    ]
    require(len(matches) == 1, "external selector did not find one event")
    target = matches[0]
    target_differences = [differences[item] for item in target["difference_ids"]]
    require(
        {item["kind"] for item in target_differences}
        == {selector["atomic_difference_domain"]},
        "target kind drifted",
    )

    target_outcome = target["outcome"]
    dominant = next(
        event for event in report["events"]
        if event["id"] != target["id"]
        and event["outcome"].get("changed_pixels", 0) > target_outcome["changed_pixels"]
        and event["outcome"].get("changed_fraction", 0) > target_outcome["changed_fraction"]
        and event["outcome"].get("linear_rgba_rmse", 0) > target_outcome["linear_rgba_rmse"]
    )
    comparison_difference_ids = report_difference_ids(report)
    cause_ids = set().union(
        *[
            cause_candidate_difference_ids(
                region["possible_causes"],
                comparison_difference_ids,
            )
            for region in target["regions"]
        ]
    )
    require(set(target["difference_ids"]) <= cause_ids <= differences.keys(), "cause links drifted")
    require(not has_forbidden_semantic_field(report), "report inferred semantic priority")

    return {
        "schema_version": "svgdiff-semantic-concern-results/1",
        "input_version": manifest["schema_version"],
        "source_pair_sha256": source_pair_hash(manifest),
        "report_schema_version": report["schema_version"],
        "analysis_status": report["analysis_status"],
        "caller_concern_source": manifest["caller_concern"]["source"],
        "engine_inferred_semantic_importance": False,
        "target_event_id": target["id"],
        "target_measurements": target_outcome,
        "dominant_event_measurements": dominant["outcome"],
        "full_inventory_event_count": len(events),
        "full_inventory_atomic_difference_count": len(differences),
        "target_evidence": {
            "atomic_difference_ids": target["difference_ids"],
            "cause_candidate_difference_ids": sorted(cause_ids),
        },
        "agent_transport_preserved_target": target["id"] in index(compact["events"]),
        "decision": {
            "serialized_universal_ranking": "not_present",
            "query_matching_small_event": "must_be_reported",
            "missing_query_context_semantic_importance": "unknown",
            "source_derived_semantic_priority": "rejected",
            "threshold_suppression_of_small_events": "rejected",
            "production_concern_fields": "not_added",
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--update", action="store_true")
    args = parser.parse_args()
    actual = build_results(args.cli.resolve())
    if args.update:
        RESULTS_PATH.write_text(json.dumps(actual, indent=2) + "\n")
    else:
        require(load_json(RESULTS_PATH) == actual, "semantic-concern results drifted")
    print(
        "Semantic concern policy: small target preserved in full and compact "
        "inventories; semantic priority remains query-conditioned"
    )


if __name__ == "__main__":
    main()
