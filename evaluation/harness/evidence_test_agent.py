#!/usr/bin/env python3

import json
import sys

from harness import (
    report_cause_candidate_ids,
    report_differences,
    report_limitation_ids,
)
from magnitude_claims import difference_magnitude_claims


task = json.load(sys.stdin)
report = task["report"]


def event_for_difference(difference_id):
    for event in report["events"]:
        if difference_id in event["difference_ids"]:
            return event
    return None


differences = []
for difference in report_differences(report):
    event = event_for_difference(difference["id"])
    regions = [] if event is None else event["regions"]
    candidate_ids = sorted(
        {
            candidate_id
            for region in regions
            for candidate_id in report_cause_candidate_ids(
                report,
                region["possible_causes"],
            )
        }
    )
    guarantees = {region["possible_causes"]["guarantee"] for region in regions}
    if not regions:
        guarantee = "not_applicable"
    elif guarantees == {"sound_overapproximation"}:
        guarantee = "sound_overapproximation"
    else:
        guarantee = "not_established"
    differences.append(
        {
            "atomic_difference_ids": [difference["id"]],
            "kind": difference["kind"],
            "subject_ids": [difference["subject"]],
            "description": f"Reported {difference['kind']} difference.",
            "magnitude_claims": difference_magnitude_claims(difference),
            "region_ids": [region["id"] for region in regions],
            "possible_cause_changed_fact_ids": candidate_ids,
            "cause_guarantee": guarantee,
            "diagnostic_ids": sorted(
                {
                    limitation_id
                    for region in regions
                    for limitation_id in region["possible_causes"].get(
                        "limitation_ids", []
                    )
                }
            ),
        }
    )

main_changes = [
    {
        "event_ids": [event["id"]],
        "atomic_difference_ids": event["difference_ids"],
        "description": f"Reported visual event {event['id']}.",
        "rationale": "The concise report retains this candidate visual event without imposing a universal severity order.",
    }
    for event in report["events"]
]

status = report["analysis_status"]
if status != "complete":
    equality = "not_established"
elif report_differences(report):
    equality = "different"
else:
    equality = "established"

json.dump(
    {
        "case_id": task["case_id"],
        "acceptance_version": task["acceptance_version"],
        "coverage": {
            "analysis_status": status,
            "equality_conclusion": equality,
            "diagnostic_ids": report_limitation_ids(report),
        },
        "differences": differences,
        "main_changes": main_changes,
        "limitations": sorted({
            f"{item['code']} ({item.get('subject', 'report')}): affects "
            + ", ".join(item.get("affects", []))
            for item in report["limitations"]
        }),
    },
    sys.stdout,
)
