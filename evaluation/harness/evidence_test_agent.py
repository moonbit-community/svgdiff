#!/usr/bin/env python3

import json
import sys

from magnitude_claims import difference_magnitude_claims


task = json.load(sys.stdin)
report = task["report"]


def event_for_difference(difference_id):
    for event in report["events"]:
        if difference_id in event["atomic_difference_ids"]:
            return event
    return None


differences = []
for difference in report["atomic_differences"]:
    event = event_for_difference(difference["id"])
    regions = [] if event is None else event["difference_regions"]
    region_ids = [region["id"] for region in regions]
    possible_causes = sorted(
        {
            fact_id
            for region in regions
            for fact_id in region["cause_envelope"]["candidate_changed_fact_ids"]
        }
    )
    guarantees = {
        region["cause_envelope"]["guarantee"] for region in regions
    }
    if not regions:
        guarantee = "not_applicable"
    elif guarantees == {"sound_overapproximation"}:
        guarantee = "sound_overapproximation"
    else:
        guarantee = "not_established"
    differences.append(
        {
            "atomic_difference_ids": [difference["id"]],
            "kind": difference["domain"],
            "subject_ids": (
                []
                if difference.get("subject_alignment_id") is None
                else [difference["subject_alignment_id"]]
            ),
            "description": f"Reported {difference['domain']} difference.",
            "magnitude_claims": difference_magnitude_claims(difference),
            "region_ids": region_ids,
            "possible_cause_changed_fact_ids": possible_causes,
            "cause_guarantee": guarantee,
            "diagnostic_ids": sorted(
                {
                    diagnostic_id
                    for region in regions
                    for diagnostic_id in region["cause_envelope"]["diagnostic_ids"]
                }
            ),
        }
    )

impact = report["impact_assessment"]
frontier_groups = impact["frontier_groups"]
main_changes = []
for index, group in enumerate(frontier_groups):
    if group["measurements"] is None:
        rationale = (
            "The versioned Impact Assessment retains this event because its "
            "required rendered measurements are unavailable; it cannot be "
            "treated as zero or dominated."
        )
    elif len(frontier_groups) == 1 and len(group["event_ids"]) == 1:
        rationale = (
            "The versioned Impact Assessment identifies this unique "
            "non-dominated event."
        )
    elif len(frontier_groups) == 1:
        rationale = (
            "The versioned Impact Assessment preserves these events as an "
            "exact measured tie."
        )
    else:
        rationale = (
            "The versioned Impact Assessment preserves this non-dominated "
            f"frontier group {index + 1} of {len(frontier_groups)} as "
            "incomparable with the other groups."
        )
    main_changes.append(
        {
            "event_ids": group["event_ids"],
            "atomic_difference_ids": group["atomic_difference_ids"],
            "description": "Reported main event group "
            + ", ".join(group["event_ids"])
            + ".",
            "rationale": rationale,
        }
    )

status = report["analysis_status"]
if status != "complete":
    equality = "not_established"
elif report["atomic_differences"]:
    equality = "different"
else:
    equality = "established"

limitations = [
    f"{row['feature_id']} ({row['subject_id']}): "
    + ", ".join(
        layer
        for layer in (
            "source_semantics",
            "computed_appearance",
            "rendered_evidence",
        )
        if row[layer] in {"limited", "failed"}
    )
    for row in report.get("coverage_matrix", [])
    if any(
        row[layer] in {"limited", "failed"}
        for layer in (
            "source_semantics",
            "computed_appearance",
            "rendered_evidence",
        )
    )
]
if impact["status"] == "partial":
    limitations.append(
        "Impact Assessment is partial because at least one candidate event "
        "has unavailable rendered measurements."
    )

json.dump(
    {
        "case_id": task["case_id"],
        "acceptance_version": task["acceptance_version"],
        "coverage": {
            "analysis_status": status,
            "equality_conclusion": equality,
            "diagnostic_ids": [item["id"] for item in report["diagnostics"]],
        },
        "differences": differences,
        "main_changes": main_changes,
        "limitations": limitations,
    },
    sys.stdout,
)
