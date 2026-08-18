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
    assert all(
        len(event["difference_ids"]) <= len(event["evidence_domains"])
        for event in scene["events"]
    )
    assert all(event["scope"] == "systemic" for event in scene["events"])
    assert all(event["evidence_event_ids"] for event in scene["events"])
    coverage = scene["evidence_coverage"]
    assert coverage["classified_difference_count"] + coverage[
        "residual_difference_count"
    ] == coverage["effective_difference_count"]
    assert sum(item["count"] for item in coverage["residual_domains"]) == coverage[
        "residual_difference_count"
    ]
    print("Visual scene banking acceptance: ok")


if __name__ == "__main__":
    main()
