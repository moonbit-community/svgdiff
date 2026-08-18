#!/usr/bin/env python3

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CASE = ROOT / "evaluation/stress/cases/banking-domain-cross-generator"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    args = parser.parse_args()
    result = subprocess.run(
        [
            str(args.cli),
            str(CASE / "before.svg"),
            str(CASE / "after.svg"),
            "--width",
            "16",
            "--height",
            "16",
            "--agent-json",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    report = json.loads(result.stdout)
    scene = report["scene"]
    assert scene["summary"] == {
        "status": "computed",
        "content": "preserved",
        "object_set": "preserved",
        "relation_graph": "preserved",
        "layout": "changed",
        "style": "changed",
        "representation": "changed",
        "before_object_count": 9,
        "after_object_count": 9,
        "before_relation_count": 6,
        "after_relation_count": 6,
    }
    assert all(
        alignment["relation"] in {"correspondence", "equivalence_class"}
        for alignment in scene["alignments"]
    )
    assert all(
        relation["endpoint_basis"] == "nearest_endpoint"
        and len(relation["endpoints"]) == 2
        for relation in scene["before_relations"] + scene["after_relations"]
    )
    expected_labels = {
        "Bank",
        "Branch",
        "Account",
        "AccountStatus",
        "Customer",
        "Individual",
        "Company",
        "Transaction",
        "TransactionType",
    }
    assert {obj["label"] for obj in scene["before_objects"]} == expected_labels
    assert {obj["label"] for obj in scene["after_objects"]} == expected_labels
    for side in ("before_objects", "after_objects"):
        subjects = [subject for obj in scene[side] for subject in obj["subjects"]]
        assert subjects
        assert len(subjects) == len(set(subjects))
    assert {event["kind"] for event in scene["events"]} == {
        "layout.reflow",
        "style.change",
        "representation.change",
    }
    assert len(scene["object_changes"]) == 27
    object_changes = {change["id"]: change for change in scene["object_changes"]}
    assigned_change_ids = [
        change_id
        for event in scene["events"]
        for change_id in event["object_change_ids"]
    ]
    assert len(assigned_change_ids) == len(set(assigned_change_ids)) == 27
    assert set(assigned_change_ids) == set(object_changes)
    assert all(
        all(
            object_changes[change_id]["kind"] == event["kind"]
            for change_id in event["object_change_ids"]
        )
        for event in scene["events"]
    )
    for event in scene["events"]:
        remaining = set(event["object_change_ids"])
        reached = {remaining.pop()}
        while remaining:
            connected = {
                candidate
                for candidate in remaining
                if any(
                    set(object_changes[candidate]["changed_fact_ids"])
                    & set(object_changes[current]["changed_fact_ids"])
                    for current in reached
                )
            }
            assert connected
            reached |= connected
            remaining -= connected
    for index, left in enumerate(scene["events"]):
        for right in scene["events"][index + 1 :]:
            if left["kind"] == right["kind"]:
                assert not set(left["changed_fact_ids"]) & set(right["changed_fact_ids"])
    layout_events = [
        event for event in scene["events"] if event["kind"] == "layout.reflow"
    ]
    assert len(layout_events) == 1
    layout = layout_events[0]
    viewport_fact_ids = {
        fact["id"]
        for fact in report["changed_facts"]
        if fact["id"].startswith("fact:viewport:0:0:")
    }
    assert viewport_fact_ids == {
        "fact:viewport:0:0:width",
        "fact:viewport:0:0:height",
        "fact:viewport:0:0:viewBox",
        "fact:viewport:0:0:preserveAspectRatio",
    }
    assert viewport_fact_ids <= set(layout["changed_fact_ids"])
    assert layout["scope"] == "systemic"
    assert len(layout["object_change_ids"]) == 9
    assert layout["effect_count"] > len(layout["changed_fact_ids"])
    assert layout["affected_subject_count"] > len(viewport_fact_ids)
    difference_coverage = scene["evidence_coverage"]["difference_to_object"]
    assert difference_coverage["assigned_difference_count"] + difference_coverage[
        "unresolved_difference_count"
    ] == difference_coverage["effective_difference_count"]
    assert sum(
        item["count"] for item in difference_coverage["unresolved_domains"]
    ) == difference_coverage["unresolved_difference_count"]
    object_coverage = scene["evidence_coverage"]["object_to_scene"]
    assert object_coverage == {
        "object_change_count": 27,
        "assigned_object_change_count": 27,
        "residual_object_change_count": 0,
        "residual_kinds": [],
    }
    assert all(
        set(event["changed_fact_ids"])
        == {
            fact_id
            for change_id in event["object_change_ids"]
            for fact_id in object_changes[change_id]["changed_fact_ids"]
        }
        for event in scene["events"]
    )
    print("Visual scene banking acceptance: ok")


if __name__ == "__main__":
    main()
