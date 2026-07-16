#!/usr/bin/env python3

import json
import sys


task = json.load(sys.stdin)
report = task["report"]


def event_for_difference(difference_id):
    for event in report["events"]:
        if difference_id in event["atomic_difference_ids"]:
            return event
    return None


MAGNITUDE_UNITS = {
    "parameter_abs_user_units": "local_user_units",
    "parameter_signed_user_units": "local_user_units",
    "symmetric_relative": "ratio",
    "parameter_abs_css_px": "css_px",
    "parameter_viewport_fraction": "viewport_diagonal_fraction",
    "parameter_entity_fraction": "entity_diagonal_fraction",
    "geometry_displacement_css_px": "css_px",
    "geometry_viewport_fraction": "viewport_diagonal_fraction",
    "presence_painted_viewport_fraction": "viewport_fraction",
    "raster_changed_pixel_fraction": "pixel_fraction",
    "raster_rgba8_rmse": "rgba8_rmse",
    "raster_linear_premultiplied_rgba_rmse": "linear_premultiplied_rgba_rmse",
}


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
            "magnitude_claims": [
                {
                    "field": f"magnitude.{field}",
                    "status": "measured" if value is not None else "not_computed",
                    "value": value,
                    "unit": MAGNITUDE_UNITS[field],
                }
                for field, value in difference["magnitude"].items()
                if field in MAGNITUDE_UNITS
            ],
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

main_changes = [
    {
        "event_ids": [event["id"]],
        "atomic_difference_ids": event["atomic_difference_ids"],
        "description": f"Reported event {event['id']}.",
        "rationale": "The report presents this event in deterministic event order.",
    }
    for event in report["events"]
]

status = report["analysis_status"]
if status != "complete":
    equality = "not_established"
elif report["atomic_differences"]:
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
            "diagnostic_ids": [item["id"] for item in report["diagnostics"]],
        },
        "differences": differences,
        "main_changes": main_changes,
        "limitations": [
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
        ],
    },
    sys.stdout,
)
