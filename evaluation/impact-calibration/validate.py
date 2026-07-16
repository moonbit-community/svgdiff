#!/usr/bin/env python3

import argparse
import json
import subprocess
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DATASET_PATH = ROOT / "evaluation/impact-calibration/dataset.v1.json"
RESULTS_PATH = ROOT / "evaluation/impact-calibration/results.v1.json"
TIER_ORDER = ["none", "low", "medium", "high"]
FRONTIER_RELATIONS = [
    "not_applicable",
    "unique",
    "tied",
    "incomparable",
    "mixed",
]
PERCEPTUAL_BACKGROUND = {"red": 255, "green": 255, "blue": 255}
PIXELS_PER_DEGREE = 20


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Calibrate Impact candidates against versioned human labels."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--update", action="store_true")
    return parser.parse_args()


def checked_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if ROOT not in path.parents or not path.is_file():
        raise ValueError(f"unsafe or missing evaluation path: {relative}")
    return path


def load_json(relative: str) -> dict[str, Any]:
    return json.loads(checked_path(relative).read_text(encoding="utf-8"))


def generate_report(cli: Path, case: dict[str, Any]) -> dict[str, Any]:
    result = subprocess.run(
        [
            str(cli),
            str(checked_path("evaluation/corpus/" + case["before"])),
            str(checked_path("evaluation/corpus/" + case["after"])),
            "--width",
            str(case["viewport"]["width"]),
            "--height",
            str(case["viewport"]["height"]),
            "--perceptual-background",
            "white",
            "--flip-pixels-per-degree",
            str(PIXELS_PER_DEGREE),
            "--agent-json",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode not in {0, 1} or result.stderr:
        raise ValueError(
            f"{case['id']}: comparison failed with status={result.returncode}, "
            f"stderr={result.stderr!r}"
        )
    return json.loads(result.stdout)


def contains_calibration_label(value: Any) -> bool:
    if isinstance(value, dict):
        return any(
            key in {"tier", "severity"} or contains_calibration_label(child)
            for key, child in value.items()
        )
    if isinstance(value, list):
        return any(contains_calibration_label(child) for child in value)
    return isinstance(value, str) and value.lower() in {
        "subtle",
        "salient",
        "major",
        "none",
        "low",
        "medium",
        "high",
    }


def event_measurements(event: dict[str, Any]) -> dict[str, Any]:
    rendered = event["rendered_outcome"]
    raw = rendered.get("magnitude")
    color = rendered["perceptual_color"]
    flip = rendered["perceptual_flip"]
    return {
        "raw_rendered": (
            None
            if rendered["status"] != "computed" or raw is None
            else {
                "changed_pixel_fraction": raw["changed_pixel_fraction"],
                "linear_premultiplied_rgba_rmse": raw[
                    "linear_premultiplied_rgba_rmse"
                ],
            }
        ),
        "perceptual_color": (
            None
            if color["status"] != "computed"
            else {
                "method_id": color["magnitude"]["method_id"],
                "sample_count": color["magnitude"]["sample_count"],
                "mean_delta_e_ok": color["magnitude"]["mean_delta_e_ok"],
            }
        ),
        "perceptual_flip": (
            None
            if flip["status"] != "computed"
            else {
                "method_id": flip["map"]["method_id"],
                "statistics_method_id": flip["statistics"]["method_id"],
                "canvas_mean": flip["statistics"]["canvas_mean"],
                "event_region_mean": flip["statistics"]["event_region_mean"],
                "response_p95": flip["statistics"]["response_p95"],
                "response_maximum": flip["statistics"]["response_maximum"],
            }
        ),
    }


def target_matches_event(target: dict[str, Any], event: dict[str, Any]) -> bool:
    if event["id"] in target["accepted_top_event_ids"]:
        return True
    difference_ids = set(event["atomic_difference_ids"])
    return any(
        set(accepted) <= difference_ids
        for accepted in target["accepted_top_atomic_difference_id_sets"]
    )


def build_dataset(cli: Path) -> dict[str, Any]:
    corpus = load_json("evaluation/corpus/manifest.json")
    annotations = load_json("evaluation/annotations/main-changes.v1.json")
    targets = load_json("evaluation/annotations/ranking-targets.v1.json")
    labels_by_id = {case["case_id"]: case for case in annotations["cases"]}
    targets_by_id = {case["case_id"]: case for case in targets["cases"]}
    corpus_ids = {case["id"] for case in corpus["cases"]}
    if corpus_ids != set(labels_by_id) or corpus_ids != set(targets_by_id):
        raise ValueError("corpus, labels, and ranking targets differ")

    cases = []
    renderer_ids = set()
    conformance_ids = set()
    for case in corpus["cases"]:
        label = labels_by_id[case["id"]]
        if len(label["main_visual_changes"]) != 1:
            raise ValueError(f"{case['id']}: calibration v1 requires one main label")
        importance = label["main_visual_changes"][0]["relative_importance"]
        if importance["rank"] != 1 or importance["tier"] not in TIER_ORDER:
            raise ValueError(f"{case['id']}: invalid top-label tier or rank")
        report = generate_report(cli, case)
        if contains_calibration_label(report["impact_assessment"]):
            raise ValueError(f"{case['id']}: production Impact output leaked labels")
        if report["schema_version"] != "1.43":
            raise ValueError(f"{case['id']}: unexpected report schema")
        renderer_ids.add(report["profile"]["renderer_id"])
        conformance_ids.add(report["profile"]["renderer_conformance_profile_id"])
        target = targets_by_id[case["id"]]
        events = []
        for event in report["events"]:
            events.append(
                {
                    "event_id": event["id"],
                    "atomic_difference_ids": event["atomic_difference_ids"],
                    "accepted_top_target": target_matches_event(target, event),
                    "measurements": event_measurements(event),
                }
            )
        frontier_ids = {
            event_id
            for group in report["impact_assessment"]["frontier_groups"]
            for event_id in group["event_ids"]
        }
        cases.append(
            {
                "case_id": case["id"],
                "viewport": case["viewport"],
                "human_tier": importance["tier"],
                "human_rank": importance["rank"],
                "target_evaluation_status": target["evaluation_status"],
                "analysis_status": report["analysis_status"],
                "impact_status": report["impact_assessment"]["status"],
                "impact_frontier_relation": report["impact_assessment"][
                    "frontier_relation"
                ],
                "event_count": len(events),
                "frontier_group_count": len(
                    report["impact_assessment"]["frontier_groups"]
                ),
                "missing_frontier_measurement_group_count": sum(
                    group["measurements"] is None
                    for group in report["impact_assessment"]["frontier_groups"]
                ),
                "frontier_event_ids": sorted(frontier_ids, key=lambda x: (len(x), x)),
                "events": events,
            }
        )
    if len(renderer_ids) != 1 or len(conformance_ids) != 1:
        raise ValueError("calibration reports used inconsistent renderer identities")
    return {
        "schema_version": "svgdiff-impact-calibration-dataset/1",
        "corpus_version": corpus["schema_version"],
        "main_change_labels_version": annotations["schema_version"],
        "ranking_targets_version": targets["schema_version"],
        "annotation_review_status": annotations["review_status"],
        "report_schema_version": "1.43",
        "impact_policy_id": "event_rendered_pareto/v1",
        "renderer_id": next(iter(renderer_ids)),
        "renderer_conformance_profile_id": next(iter(conformance_ids)),
        "calibration_profile": {
            "perceptual_background": PERCEPTUAL_BACKGROUND,
            "flip_viewing_conditions": {"pixels_per_degree": PIXELS_PER_DEGREE},
            "flip_error_threshold": None,
        },
        "cases": cases,
    }


def top_rows(dataset: dict[str, Any]) -> list[dict[str, Any]]:
    rows = []
    for case in dataset["cases"]:
        if case["target_evaluation_status"] != "scorable":
            continue
        accepted = [event for event in case["events"] if event["accepted_top_target"]]
        if len(accepted) != 1:
            raise ValueError(
                f"{case['case_id']}: calibration v1 requires one accepted top event"
            )
        rows.append(
            {
                "case_id": case["case_id"],
                "tier": case["human_tier"],
                "event": accepted[0],
            }
        )
    return rows


def nested_value(row: dict[str, Any], path: tuple[str, ...]) -> float | None:
    value: Any = row["event"]["measurements"]
    for key in path:
        if value is None:
            return None
        value = value[key]
    return value


def tier_ranges(
    rows: list[dict[str, Any]], path: tuple[str, ...]
) -> dict[str, dict[str, float] | None]:
    result = {}
    for tier in TIER_ORDER:
        values = [
            value
            for row in rows
            if row["tier"] == tier
            and (value := nested_value(row, path)) is not None
        ]
        result[tier] = (
            None if not values else {"minimum": min(values), "maximum": max(values)}
        )
    return result


def fit_cutpoints(
    rows: list[dict[str, Any]], path: tuple[str, ...]
) -> tuple[list[float] | None, str | None]:
    ranges = tier_ranges(rows, path)
    if any(ranges[tier] is None for tier in TIER_ORDER):
        return None, "one_or_more_tiers_have_no_measured_training_case"
    cutpoints = []
    for left, right in zip(TIER_ORDER, TIER_ORDER[1:]):
        left_maximum = ranges[left]["maximum"]
        right_minimum = ranges[right]["minimum"]
        if left_maximum >= right_minimum:
            return None, f"{left}_and_{right}_ranges_overlap_or_invert"
        cutpoints.append((left_maximum + right_minimum) / 2.0)
    return cutpoints, None


def predict_tier(value: float, cutpoints: list[float]) -> str:
    for index, cutpoint in enumerate(cutpoints):
        if value <= cutpoint:
            return TIER_ORDER[index]
    return TIER_ORDER[-1]


def evaluate_cutpoint_candidate(
    identifier: str,
    input_field: str,
    path: tuple[str, ...],
    rows: list[dict[str, Any]],
) -> dict[str, Any]:
    ranges = tier_ranges(rows, path)
    full_cutpoints, full_reason = fit_cutpoints(rows, path)
    measured_rows = [row for row in rows if nested_value(row, path) is not None]
    measured_tier_counts = Counter(row["tier"] for row in measured_rows)
    full_predictions = []
    if full_cutpoints is not None:
        for row in measured_rows:
            predicted = predict_tier(nested_value(row, path), full_cutpoints)
            full_predictions.append(
                {
                    "case_id": row["case_id"],
                    "expected": row["tier"],
                    "predicted": predicted,
                }
            )

    held_out = []
    correct = 0
    predicted_count = 0
    for row in rows:
        value = nested_value(row, path)
        if value is None:
            held_out.append(
                {"case_id": row["case_id"], "status": "missing_measurement"}
            )
            continue
        training = [candidate for candidate in rows if candidate is not row]
        cutpoints, reason = fit_cutpoints(training, path)
        if cutpoints is None:
            held_out.append(
                {
                    "case_id": row["case_id"],
                    "status": "not_trainable",
                    "reason": reason,
                }
            )
            continue
        predicted = predict_tier(value, cutpoints)
        predicted_count += 1
        correct += int(predicted == row["tier"])
        held_out.append(
            {
                "case_id": row["case_id"],
                "status": "predicted",
                "expected": row["tier"],
                "predicted": predicted,
                "cutpoints": cutpoints,
            }
        )

    return {
        "candidate_id": identifier,
        "kind": "ordinal_tier_cutpoints",
        "input_fields": [input_field],
        "tier_order": TIER_ORDER,
        "measured_case_count": len(measured_rows),
        "measured_tier_counts": {
            tier: measured_tier_counts[tier] for tier in TIER_ORDER
        },
        "tier_ranges": ranges,
        "full_fit": {
            "status": "fitted" if full_cutpoints is not None else "not_trainable",
            "cutpoints": full_cutpoints,
            "reason": full_reason,
            "measured_accuracy": (
                None
                if not full_predictions
                else sum(
                    item["expected"] == item["predicted"]
                    for item in full_predictions
                )
                / len(full_predictions)
            ),
        },
        "leave_one_case_out": {
            "labeled_case_count": len(rows),
            "predicted_case_count": predicted_count,
            "correct_case_count": correct,
            "coverage": predicted_count / len(rows),
            "conditional_accuracy": (
                None if predicted_count == 0 else correct / predicted_count
            ),
            "overall_accuracy": correct / len(rows),
            "cases": held_out,
        },
    }


def evaluate_ordering_candidate(dataset: dict[str, Any]) -> dict[str, Any]:
    evaluable = 0
    pair_count = 0
    correct = 0
    cases = []
    for case in dataset["cases"]:
        if case["target_evaluation_status"] != "scorable" or len(case["events"]) < 2:
            continue
        measured = [
            event
            for event in case["events"]
            if event["measurements"]["raw_rendered"] is not None
        ]
        accepted = [event for event in measured if event["accepted_top_target"]]
        others = [event for event in measured if not event["accepted_top_target"]]
        if not accepted or not others:
            continue
        evaluable += 1
        pair_count += len(accepted) * len(others)
        ranked = sorted(
            measured,
            key=lambda event: (
                -event["measurements"]["raw_rendered"]["changed_pixel_fraction"],
                -event["measurements"]["raw_rendered"][
                    "linear_premultiplied_rgba_rmse"
                ],
                len(event["event_id"]),
                event["event_id"],
            ),
        )
        hit = ranked[0]["accepted_top_target"]
        correct += int(hit)
        cases.append(
            {
                "case_id": case["case_id"],
                "predicted_event_id": ranked[0]["event_id"],
                "accepted": hit,
            }
        )
    return {
        "candidate_id": "event_rendered_extent_then_error_lexicographic/v1",
        "kind": "total_event_order",
        "input_fields": [
            "events[].rendered_outcome.magnitude.changed_pixel_fraction",
            "events[].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse",
        ],
        "evaluable_multi_event_case_count": evaluable,
        "labeled_pair_count": pair_count,
        "top_event_accuracy": None if evaluable == 0 else correct / evaluable,
        "cases": cases,
    }


def decide_candidates(
    candidates: list[dict[str, Any]],
    rows: list[dict[str, Any]],
) -> None:
    for candidate in candidates:
        if candidate["kind"] == "ordinal_tier_cutpoints":
            gates = {
                "independent_reviewer_agreement": False,
                "minimum_measured_cases_per_tier": all(
                    candidate["measured_tier_counts"][tier] >= 2
                    for tier in TIER_ORDER
                ),
                "complete_policy_inputs": candidate["measured_case_count"]
                == len(rows),
                "full_fit_trainable": candidate["full_fit"]["status"] == "fitted",
                "leave_one_case_out_coverage": candidate["leave_one_case_out"][
                    "coverage"
                ]
                == 1.0,
                "leave_one_case_out_accuracy": candidate["leave_one_case_out"][
                    "overall_accuracy"
                ]
                == 1.0,
            }
        else:
            gates = {
                "independent_reviewer_agreement": False,
                "human_ranked_multi_event_cases": candidate[
                    "evaluable_multi_event_case_count"
                ]
                > 0,
                "human_ranked_event_pairs": candidate["labeled_pair_count"] > 0,
                "top_event_accuracy": candidate["top_event_accuracy"] == 1.0,
            }
        candidate["release_gate_results"] = gates
        candidate["decision"] = "accepted" if all(gates.values()) else "rejected"
        candidate["decision_reasons"] = [
            gate for gate, passed in gates.items() if not passed
        ]


def build_results(dataset: dict[str, Any]) -> dict[str, Any]:
    rows = top_rows(dataset)
    tier_counts = Counter(case["human_tier"] for case in dataset["cases"])
    event_tier_counts = Counter(row["tier"] for row in rows)
    frontier_relation_counts = Counter(
        case["impact_frontier_relation"] for case in dataset["cases"]
    )
    measured_raw = sum(
        nested_value(row, ("raw_rendered", "changed_pixel_fraction")) is not None
        for row in rows
    )
    measured_flip = sum(
        nested_value(row, ("perceptual_flip", "canvas_mean")) is not None
        for row in rows
    )
    scorable = [
        case
        for case in dataset["cases"]
        if case["target_evaluation_status"] == "scorable"
    ]
    frontier_hits = sum(
        any(
            event["accepted_top_target"]
            and event["event_id"] in set(case["frontier_event_ids"])
            for event in case["events"]
        )
        for case in scorable
    )
    candidates = [
        evaluate_cutpoint_candidate(
            "changed_pixel_fraction_ordinal_cutpoints/v1",
            "events[].rendered_outcome.magnitude.changed_pixel_fraction",
            ("raw_rendered", "changed_pixel_fraction"),
            rows,
        ),
        evaluate_cutpoint_candidate(
            "linear_premultiplied_rgba_rmse_ordinal_cutpoints/v1",
            "events[].rendered_outcome.magnitude.linear_premultiplied_rgba_rmse",
            ("raw_rendered", "linear_premultiplied_rgba_rmse"),
            rows,
        ),
        evaluate_cutpoint_candidate(
            "flip_canvas_mean_ordinal_cutpoints/v1",
            "events[].rendered_outcome.perceptual_flip.statistics.canvas_mean",
            ("perceptual_flip", "canvas_mean"),
            rows,
        ),
        evaluate_ordering_candidate(dataset),
    ]
    decide_candidates(candidates, rows)
    return {
        "schema_version": "svgdiff-impact-calibration-results/1",
        "dataset_version": dataset["schema_version"],
        "decision": {
            "production_policy": "rejected",
            "retained_policy_id": "event_rendered_pareto/v1",
            "retained_calibration_status": "not_calibrated",
            "reasons": [
                "annotations_have_no_recorded_independent_reviewer_agreement",
                "only_one_low_tier_event_case_exists",
                "one_high_tier_target_has_no_rendered_or_perceptual_measurements",
                "no_human_ranked_multi_event_case_exists",
                "held_out_threshold_results_are_incomplete_or_inaccurate",
                "single_metric_tier_ranges_overlap_or_invert",
            ],
        },
        "evidence_summary": {
            "case_count": len(dataset["cases"]),
            "scorable_case_count": len(scorable),
            "event_bearing_scorable_case_count": len(rows),
            "multi_event_scorable_case_count": sum(
                case["event_count"] > 1 for case in scorable
            ),
            "human_tier_case_counts": {
                tier: tier_counts[tier] for tier in TIER_ORDER
            },
            "human_tier_event_counts": {
                tier: event_tier_counts[tier] for tier in TIER_ORDER
            },
            "raw_rendered_measurement_case_count": measured_raw,
            "flip_measurement_case_count": measured_flip,
            "annotation_review_status": dataset["annotation_review_status"],
            "recorded_independent_agreement_comparisons": 0,
            "agreement_metric": None,
            "frontier_relation_case_counts": {
                relation: frontier_relation_counts[relation]
                for relation in FRONTIER_RELATIONS
            },
            "partial_impact_case_count": sum(
                case["impact_status"] == "partial" for case in dataset["cases"]
            ),
            "missing_frontier_measurement_case_count": sum(
                case["missing_frontier_measurement_group_count"] > 0
                for case in dataset["cases"]
            ),
        },
        "uncalibrated_frontier_baseline": {
            "accepted_top_target_hits": frontier_hits,
            "scorable_case_count": len(scorable),
            "recall": frontier_hits / len(scorable),
            "claim": "frontier_recall_only_not_calibrated_ordering",
        },
        "release_gates": {
            "independent_reviewer_agreement_required": True,
            "minimum_measured_cases_per_emitted_tier": 2,
            "all_labeled_target_events_require_policy_inputs": True,
            "human_ranked_multi_event_cases_required": True,
            "required_leave_one_case_out_coverage": 1.0,
            "required_leave_one_case_out_accuracy": 1.0,
        },
        "candidates": candidates,
        "requirements_before_retry": [
            "add_an_independent_blinded_review_and_record_agreement",
            "add_ranked_multi_event_cases_with_cross_domain_tradeoffs",
            "add_more_low_tier_and_boundary_cases",
            "provide_policy_inputs_for_embedded_raster_and_other_missing_events",
            "repeat_sensitivity_across_viewports_backgrounds_and_viewing_conditions",
        ],
    }


def canonical_json(value: dict[str, Any]) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def verify_or_update(path: Path, value: dict[str, Any], update: bool) -> None:
    encoded = canonical_json(value)
    if update:
        path.write_text(encoded, encoding="utf-8")
        return
    if not path.is_file() or path.read_text(encoding="utf-8") != encoded:
        raise ValueError(f"calibration artifact drifted: {path.relative_to(ROOT)}")


def main() -> None:
    args = parse_args()
    dataset = build_dataset(args.cli.resolve())
    results = build_results(dataset)
    verify_or_update(DATASET_PATH, dataset, args.update)
    verify_or_update(RESULTS_PATH, results, args.update)
    if results["decision"]["production_policy"] != "rejected":
        raise ValueError("calibration v1 unexpectedly accepted a production policy")
    print(
        "Impact calibration: 13 cases, 12 scorable, 0 multi-event ranked; "
        "production calibrated policy rejected"
    )


if __name__ == "__main__":
    main()
