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


def magnitude_claims(magnitude):
    claims = [
        {
            "field": f"magnitude.{field}",
            "status": "measured" if value is not None else "not_computed",
            "value": value,
            "unit": MAGNITUDE_UNITS[field],
        }
        for field, value in magnitude.items()
        if field in MAGNITUDE_UNITS
    ]
    boundary = magnitude["painted_boundary_displacement"]
    if boundary is None:
        claims.append(
            {
                "field": "magnitude.painted_boundary_displacement",
                "status": "not_computed",
                "value": None,
                "unit": "symmetric_nearest_boundary_pixels/v1",
            }
        )
    else:
        claims.extend(
            [
                {
                    "field": "magnitude.painted_boundary_displacement.method_id",
                    "status": "measured",
                    "value": boundary["method_id"],
                    "unit": None,
                },
                {
                    "field": "magnitude.painted_boundary_displacement.before_sample_count",
                    "status": "measured",
                    "value": boundary["before_sample_count"],
                    "unit": "boundary_pixel_samples",
                },
                {
                    "field": "magnitude.painted_boundary_displacement.after_sample_count",
                    "status": "measured",
                    "value": boundary["after_sample_count"],
                    "unit": "boundary_pixel_samples",
                },
                {
                    "field": "magnitude.painted_boundary_displacement.mean_css_px",
                    "status": "measured",
                    "value": boundary["mean_css_px"],
                    "unit": "css_px",
                },
                {
                    "field": "magnitude.painted_boundary_displacement.p95_css_px",
                    "status": "measured",
                    "value": boundary["p95_css_px"],
                    "unit": "css_px",
                },
                {
                    "field": "magnitude.painted_boundary_displacement.max_css_px",
                    "status": "measured",
                    "value": boundary["max_css_px"],
                    "unit": "css_px",
                },
            ]
        )
    coverage = magnitude["painted_coverage_difference"]
    if coverage is None:
        claims.append(
            {
                "field": "magnitude.painted_coverage_difference",
                "status": "not_computed",
                "value": None,
                "unit": "symmetric_alpha_coverage_l1_over_union/v1",
            }
        )
        return claims
    claims.extend(
        [
            {
                "field": "magnitude.painted_coverage_difference.method_id",
                "status": "measured",
                "value": coverage["method_id"],
                "unit": None,
            },
            {
                "field": "magnitude.painted_coverage_difference.before_coverage_css_px2",
                "status": "measured",
                "value": coverage["before_coverage_css_px2"],
                "unit": "css_px2",
            },
            {
                "field": "magnitude.painted_coverage_difference.after_coverage_css_px2",
                "status": "measured",
                "value": coverage["after_coverage_css_px2"],
                "unit": "css_px2",
            },
            {
                "field": "magnitude.painted_coverage_difference.absolute_difference_css_px2",
                "status": "measured",
                "value": coverage["absolute_difference_css_px2"],
                "unit": "css_px2",
            },
            {
                "field": "magnitude.painted_coverage_difference.union_coverage_css_px2",
                "status": "measured",
                "value": coverage["union_coverage_css_px2"],
                "unit": "css_px2",
            },
            {
                "field": "magnitude.painted_coverage_difference.fraction",
                "status": "measured",
                "value": coverage["fraction"],
                "unit": "coverage_union_fraction",
            },
        ]
    )
    return claims


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
            "magnitude_claims": magnitude_claims(difference["magnitude"]),
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
