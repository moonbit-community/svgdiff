#!/usr/bin/env python3

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
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


def run_report(cli: Path, manifest: dict[str, Any], agent: bool) -> dict[str, Any]:
    case = manifest["case"]
    viewport = case["viewport"]
    command = [
        str(cli),
        str(checked_source(case["before"])),
        str(checked_source(case["after"])),
        "--width",
        str(viewport["width"]),
        "--height",
        str(viewport["height"]),
    ]
    if agent:
        command.append("--agent-json")
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    require(
        result.returncode == 0 and not result.stderr,
        f"CLI failed: status={result.returncode}, stderr={result.stderr!r}",
    )
    return json.loads(result.stdout)


def index(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result = {item["id"]: item for item in items}
    require(len(result) == len(items), "report contains duplicate IDs")
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
        "semantic_concern",
        "semantic_concerns",
        "semantic_importance",
        "business_importance",
        "caller_concern",
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
    report = run_report(cli, manifest, agent=False)
    agent = run_report(cli, manifest, agent=True)
    require(report["schema_version"] == manifest["report_schema_version"], "schema drift")
    require(report["analysis_status"] == "complete", "comparison is not complete")

    impact = report["impact_assessment"]
    require(impact["policy_id"] == manifest["impact_policy_id"], "policy drift")
    require(impact["status"] == "complete", "Impact is not complete")
    events = index(report["events"])
    differences = index(report["atomic_differences"])
    facts = index(report["changed_facts"])

    selector = manifest["caller_concern"]["selector"]
    expected_bounds = selector["region_css_bounds"]
    target_matches = []
    for event in report["events"]:
        for region in event["difference_regions"]:
            bounds = {
                "x": region["css_x"],
                "y": region["css_y"],
                "width": region["css_width"],
                "height": region["css_height"],
            }
            if bounds == expected_bounds:
                target_matches.append(event)
                break
    require(len(target_matches) == 1, "external selector did not find one event")
    target = target_matches[0]
    target_id = target["id"]
    target_differences = [differences[item] for item in target["atomic_difference_ids"]]
    require(
        {item["domain"] for item in target_differences}
        == {selector["atomic_difference_domain"]},
        "target domain drifted",
    )

    frontier_ids = {
        event_id
        for group in impact["frontier_groups"]
        for event_id in group["event_ids"]
    }
    require(target_id not in frontier_ids, "target unexpectedly entered frontier")
    witnesses = [
        item
        for item in impact["domination_witnesses"]
        if item["dominated_event_id"] == target_id
    ]
    require(len(witnesses) == 1, "target lacks one domination witness")
    dominant = events[witnesses[0]["dominant_event_id"]]
    target_magnitude = target["rendered_outcome"]["magnitude"]
    dominant_magnitude = dominant["rendered_outcome"]["magnitude"]
    require(
        target_magnitude["changed_pixels"] < dominant_magnitude["changed_pixels"]
        and target_magnitude["changed_pixel_fraction"]
        < dominant_magnitude["changed_pixel_fraction"]
        and target_magnitude["linear_premultiplied_rgba_rmse"]
        < dominant_magnitude["linear_premultiplied_rgba_rmse"],
        "target is not smaller in every Impact dimension",
    )

    changed_fact_ids = {
        fact_id for item in target_differences for fact_id in item["changed_fact_ids"]
    }
    require(changed_fact_ids and changed_fact_ids <= facts.keys(), "unresolved target facts")
    cause_ids = set()
    for region in target["difference_regions"]:
        envelope = region["cause_envelope"]
        require(envelope["guarantee"] == "sound_overapproximation", "unsound target cause")
        cause_ids.update(envelope["candidate_changed_fact_ids"])
    require(changed_fact_ids <= cause_ids <= facts.keys(), "target cause links drifted")

    for field in (
        "impact_assessment",
        "subject_alignments",
        "changed_facts",
        "atomic_differences",
        "events",
        "diagnostics",
    ):
        require(agent[field] == report[field], f"Agent transport changed {field}")
    require(target_id in index(agent["events"]), "Agent transport omitted target")
    require(not has_forbidden_semantic_field(report), "report inferred semantic priority")

    observed_behavior = {
        "target_is_frontier_member": False,
        "target_has_domination_witness": True,
        "target_remains_in_full_inventory": target_id in events,
        "agent_transport_preserves_target": True,
        "engine_infers_semantic_importance": False,
    }
    require(
        observed_behavior == manifest["expected_policy_behavior"],
        "expected policy behavior drifted",
    )
    return {
        "schema_version": "svgdiff-semantic-concern-results/1",
        "input_version": manifest["schema_version"],
        "source_pair_sha256": source_pair_hash(manifest),
        "report_schema_version": report["schema_version"],
        "impact_policy_id": impact["policy_id"],
        "analysis_status": report["analysis_status"],
        "caller_concern_source": manifest["caller_concern"]["source"],
        "engine_inferred_semantic_importance": False,
        "target_event_id": target_id,
        "target_measurements": target_magnitude,
        "target_frontier_member": False,
        "domination_witness": witnesses[0],
        "dominant_event_measurements": dominant_magnitude,
        "full_inventory_event_count": len(events),
        "full_inventory_atomic_difference_count": len(differences),
        "target_evidence": {
            "atomic_difference_ids": target["atomic_difference_ids"],
            "changed_fact_ids": sorted(changed_fact_ids),
            "cause_candidate_changed_fact_ids": sorted(cause_ids),
        },
        "agent_transport_preserved_target": True,
        "decision": {
            "context_free_main_change_policy": "retained",
            "query_matching_dominated_event": "must_be_reported",
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
        RESULTS_PATH.write_text(json.dumps(actual, indent=2) + "\n", encoding="utf-8")
    else:
        require(RESULTS_PATH.is_file(), "semantic-concern results are missing")
        require(load_json(RESULTS_PATH) == actual, "semantic-concern results drifted")
    print(
        "Semantic concern policy: dominated 1-pixel target preserved in full and "
        "Agent inventories; semantic priority remains query-conditioned"
    )


if __name__ == "__main__":
    main()
