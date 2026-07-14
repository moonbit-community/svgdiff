#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys

from harness import read_json_lines, validate_answer


ROOT = Path(__file__).resolve().parent


def load_cases(path: Path):
    document = json.loads(path.read_text(encoding="utf-8"))
    return document, {case["case_id"]: case for case in document["cases"]}


def mean(values):
    return sum(values) / len(values) if values else None


def union_bounds(bounds):
    if not bounds:
        return None
    left = min(item["x"] for item in bounds)
    top = min(item["y"] for item in bounds)
    right = max(item["x"] + item["width"] for item in bounds)
    bottom = max(item["y"] + item["height"] for item in bounds)
    return {"x": left, "y": top, "width": right - left, "height": bottom - top}


def intersection_area(left, right):
    width = max(
        0.0,
        min(left["x"] + left["width"], right["x"] + right["width"])
        - max(left["x"], right["x"]),
    )
    height = max(
        0.0,
        min(left["y"] + left["height"], right["y"] + right["height"])
        - max(left["y"], right["y"]),
    )
    return width * height


def area(bounds):
    return bounds["width"] * bounds["height"]


def region_score(predicted, reference, comparison_rule):
    if predicted is None:
        return 0.0
    intersection = intersection_area(predicted, reference)
    if comparison_rule == "predicted_region_contained_by_reference":
        predicted_area = area(predicted)
        return 1.0 if predicted_area == 0 else intersection / predicted_area
    union = area(predicted) + area(reference) - intersection
    return 1.0 if union == 0 else intersection / union


def report_regions(report):
    return {
        region["id"]: {
            "x": region["css_x"],
            "y": region["css_y"],
            "width": region["css_width"],
            "height": region["css_height"],
        }
        for event in report["events"]
        for region in event["difference_regions"]
    }


def report_envelope_candidates(report):
    return {
        fact_id
        for event in report["events"]
        for region in event["difference_regions"]
        for fact_id in region["cause_envelope"]["candidate_changed_fact_ids"]
    }


def actual_fact_ids(report, cause_label):
    matched = set()
    for actual in cause_label["actual_causes"]:
        locator = actual["fact_locator"]
        candidates = []
        for fact in report["changed_facts"]:
            if fact["property"] != locator["report_property"]:
                continue
            if set(fact["affected_subject_ids"]) != set(locator["affected_subject_ids"]):
                continue
            before = fact.get("before")
            after = fact.get("after")
            if before is not None and locator["source_property"] is not None:
                if before["property"] != locator["source_property"]:
                    continue
            if after is not None and locator["source_property"] is not None:
                if after["property"] != locator["source_property"]:
                    continue
            if before is not None and locator["before_declared_value"] is not None:
                if before["declared_value"] != locator["before_declared_value"]:
                    continue
            if after is not None and locator["after_declared_value"] is not None:
                if after["declared_value"] != locator["after_declared_value"]:
                    continue
            candidates.append(fact["id"])
        if len(candidates) != 1:
            raise ValueError(
                f"{cause_label['case_id']}: actual cause {actual['id']} matched {len(candidates)} Changed Facts"
            )
        matched.add(candidates[0])
    return matched


def reciprocal_rank(answer, target):
    if target["evaluation_status"] != "scorable":
        return None
    accepted_events = set(target["accepted_top_event_ids"])
    accepted_sets = [
        set(item) for item in target["accepted_top_atomic_difference_id_sets"]
    ]
    for index, change in enumerate(answer["main_changes"]):
        events = set(change["event_ids"])
        differences = set(change["atomic_difference_ids"])
        if events & accepted_events or any(
            accepted <= differences for accepted in accepted_sets
        ):
            return 1.0 / (index + 1)
    return 0.0


def score_case(task, answer, ranking, region_label, cause_label):
    case_id = task["case_id"]
    report = task["report"]
    validate_answer(answer, case_id)

    coverage = answer["coverage"]
    coverage_status_accuracy = (
        1.0 if coverage["analysis_status"] == report["analysis_status"] else 0.0
    )
    if report["analysis_status"] != "complete":
        expected_equality = "not_established"
    elif report["atomic_differences"]:
        expected_equality = "different"
    else:
        expected_equality = "established"
    equality_accuracy = (
        1.0 if coverage["equality_conclusion"] == expected_equality else 0.0
    )
    required_diagnostic_ids = {item["id"] for item in report["diagnostics"]}
    agent_diagnostic_ids = set(coverage["diagnostic_ids"])
    if required_diagnostic_ids:
        diagnostic_recall = len(required_diagnostic_ids & agent_diagnostic_ids) / len(
            required_diagnostic_ids
        )
    else:
        diagnostic_recall = 1.0
    hard_safety_failure = (
        1
        if coverage_status_accuracy < 1
        or equality_accuracy < 1
        or diagnostic_recall < 1
        else 0
    )

    expected_difference_ids = {
        difference["id"] for difference in report["atomic_differences"]
    }
    agent_difference_ids = {
        difference_id
        for difference in answer["differences"]
        for difference_id in difference["atomic_difference_ids"]
    }
    if expected_difference_ids:
        atomic_recall = len(expected_difference_ids & agent_difference_ids) / len(
            expected_difference_ids
        )
    else:
        atomic_recall = 1.0 if not agent_difference_ids else 0.0

    regions_by_id = report_regions(report)
    report_region_ids = set(regions_by_id)
    agent_region_ids = {
        region_id
        for difference in answer["differences"]
        for region_id in difference["region_ids"]
    }
    invalid_region_ids = sorted(agent_region_ids - report_region_ids)
    if region_label["localization_status"] == "localizable":
        reference = union_bounds(
            [region["bounds"] for region in region_label["regions"]]
        )
        comparison_rules = {
            region["comparison_rule"] for region in region_label["regions"]
        }
        if len(comparison_rules) != 1:
            raise ValueError(f"{case_id}: mixed region comparison rules are unsupported")
        comparison_rule = next(iter(comparison_rules))
        report_region_overlap = region_score(
            union_bounds([regions_by_id[item] for item in report_region_ids]),
            reference,
            comparison_rule,
        )
        agent_region_overlap = region_score(
            union_bounds(
                [regions_by_id[item] for item in agent_region_ids if item in regions_by_id]
            ),
            reference,
            comparison_rule,
        )
    else:
        report_region_overlap = None
        agent_region_overlap = None

    report_candidates = report_envelope_candidates(report)
    agent_candidates = {
        fact_id
        for difference in answer["differences"]
        for fact_id in difference["possible_cause_changed_fact_ids"]
    }
    changed_fact_ids = {fact["id"] for fact in report["changed_facts"]}
    invalid_cause_ids = sorted(agent_candidates - changed_fact_ids)
    if cause_label["evaluation_status"] == "eligible":
        actual_ids = actual_fact_ids(report, cause_label)
        report_cause_recall = len(actual_ids & report_candidates) / len(actual_ids)
        agent_cause_recall = len(actual_ids & agent_candidates) / len(actual_ids)
        report_false_positives = len(report_candidates - actual_ids)
        agent_false_positives = len(agent_candidates - actual_ids)
    else:
        actual_ids = set()
        report_cause_recall = None
        agent_cause_recall = None
        report_false_positives = None
        agent_false_positives = None

    return {
        "case_id": case_id,
        "agent_coverage_status_accuracy": coverage_status_accuracy,
        "agent_equality_conclusion_accuracy": equality_accuracy,
        "agent_required_diagnostic_recall": diagnostic_recall,
        "agent_hard_safety_failure": hard_safety_failure,
        "agent_atomic_difference_recall": atomic_recall,
        "agent_main_difference_reciprocal_rank": reciprocal_rank(answer, ranking),
        "report_region_overlap": report_region_overlap,
        "agent_region_overlap": agent_region_overlap,
        "report_cause_envelope_recall": report_cause_recall,
        "agent_possible_cause_recall": agent_cause_recall,
        "report_cause_false_positive_count": report_false_positives,
        "agent_cause_false_positive_count": agent_false_positives,
        "invalid_atomic_difference_ids": sorted(
            agent_difference_ids - expected_difference_ids
        ),
        "invalid_region_ids": invalid_region_ids,
        "invalid_cause_changed_fact_ids": invalid_cause_ids,
    }


def build_parser():
    parser = argparse.ArgumentParser(description="Score SVG Diff agent answers.")
    parser.add_argument("--tasks", type=Path, required=True)
    parser.add_argument("--answers", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--ranking-targets",
        type=Path,
        default=ROOT.parent / "annotations" / "ranking-targets.v1.json",
    )
    parser.add_argument(
        "--region-labels",
        type=Path,
        default=ROOT.parent / "annotations" / "regions.v1.json",
    )
    parser.add_argument(
        "--cause-labels",
        type=Path,
        default=ROOT.parent / "annotations" / "actual-causes.v1.json",
    )
    return parser


def main():
    args = build_parser().parse_args()
    try:
        tasks = {task["case_id"]: task for task in read_json_lines(args.tasks)}
        answers = {
            answer["case_id"]: answer for answer in read_json_lines(args.answers)
        }
        if set(tasks) != set(answers):
            raise ValueError("task and answer case IDs differ")
        _, rankings = load_cases(args.ranking_targets)
        _, regions = load_cases(args.region_labels)
        _, causes = load_cases(args.cause_labels)
        if not (set(tasks) == set(rankings) == set(regions) == set(causes)):
            raise ValueError("task and annotation case IDs differ")

        per_case = [
            score_case(tasks[case_id], answers[case_id], rankings[case_id], regions[case_id], causes[case_id])
            for case_id in sorted(tasks)
        ]

        def values(field):
            return [item[field] for item in per_case if item[field] is not None]

        result = {
            "metrics_version": "svgdiff-evaluation-metrics/1",
            "case_count": len(per_case),
            "aggregate": {
                "agent_coverage_status_accuracy_macro": mean(
                    values("agent_coverage_status_accuracy")
                ),
                "agent_equality_conclusion_accuracy_macro": mean(
                    values("agent_equality_conclusion_accuracy")
                ),
                "agent_required_diagnostic_recall_macro": mean(
                    values("agent_required_diagnostic_recall")
                ),
                "agent_hard_safety_failure_count": sum(
                    values("agent_hard_safety_failure")
                ),
                "agent_atomic_difference_recall_macro": mean(
                    values("agent_atomic_difference_recall")
                ),
                "agent_main_difference_mrr": mean(
                    values("agent_main_difference_reciprocal_rank")
                ),
                "report_region_overlap_macro": mean(
                    values("report_region_overlap")
                ),
                "agent_region_overlap_macro": mean(
                    values("agent_region_overlap")
                ),
                "report_cause_envelope_recall_macro": mean(
                    values("report_cause_envelope_recall")
                ),
                "agent_possible_cause_recall_macro": mean(
                    values("agent_possible_cause_recall")
                ),
                "report_cause_false_positive_count": sum(
                    values("report_cause_false_positive_count")
                ),
                "agent_cause_false_positive_count": sum(
                    values("agent_cause_false_positive_count")
                ),
                "invalid_evidence_reference_count": sum(
                    len(item[field])
                    for item in per_case
                    for field in (
                        "invalid_atomic_difference_ids",
                        "invalid_region_ids",
                        "invalid_cause_changed_fact_ids",
                    )
                ),
            },
            "per_case": per_case,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    except (OSError, ValueError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
