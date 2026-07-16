#!/usr/bin/env python3

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate Impact Assessment frontiers against hidden main-change targets."
    )
    parser.add_argument("--cli", required=True, type=Path)
    return parser.parse_args()


def checked_path(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if ROOT not in path.parents or not path.is_file():
        raise ValueError(f"unsafe or missing evaluation path: {relative}")
    return path


def generate(cli: Path, case: dict) -> dict:
    result = subprocess.run(
        [
            str(cli),
            str(checked_path("evaluation/corpus/" + case["before"])),
            str(checked_path("evaluation/corpus/" + case["after"])),
            "--width",
            str(case["viewport"]["width"]),
            "--height",
            str(case["viewport"]["height"]),
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


def leaks_calibrated_label(value: object) -> bool:
    if isinstance(value, dict):
        return any(
            key in {"tier", "severity"} or leaks_calibrated_label(child)
            for key, child in value.items()
        )
    if isinstance(value, list):
        return any(leaks_calibrated_label(child) for child in value)
    return isinstance(value, str) and value.lower() in {
        "subtle",
        "salient",
        "major",
        "none",
        "low",
        "medium",
        "high",
    }


def main() -> None:
    args = parse_args()
    corpus = json.loads(
        checked_path("evaluation/corpus/manifest.json").read_text(encoding="utf-8")
    )
    targets = json.loads(
        checked_path("evaluation/annotations/ranking-targets.v1.json").read_text(
            encoding="utf-8"
        )
    )
    targets_by_id = {case["case_id"]: case for case in targets["cases"]}
    corpus_ids = {case["id"] for case in corpus["cases"]}
    if corpus_ids != set(targets_by_id):
        raise ValueError("Impact corpus and hidden ranking targets differ")

    scorable = 0
    not_applicable = 0
    for case in corpus["cases"]:
        report = generate(args.cli.resolve(), case)
        impact = report["impact_assessment"]
        if (
            impact["policy_id"] != "event_rendered_pareto/v1"
            or impact["calibration_status"] != "not_calibrated"
        ):
            raise ValueError(f"{case['id']}: unexpected Impact policy identity")
        if leaks_calibrated_label(impact):
            raise ValueError(f"{case['id']}: Impact output leaked calibrated labels")
        target = targets_by_id[case["id"]]
        frontier_event_ids = {
            event_id
            for group in impact["frontier_groups"]
            for event_id in group["event_ids"]
        }
        frontier_difference_ids = {
            difference_id
            for group in impact["frontier_groups"]
            for difference_id in group["atomic_difference_ids"]
        }
        event_ids = {event["id"] for event in report["events"]}
        difference_ids = {
            difference["id"] for difference in report["atomic_differences"]
        }
        if impact["candidate_event_count"] != len(event_ids):
            raise ValueError(
                f"{case['id']}: Impact candidate count differs from full event inventory"
            )
        if not frontier_event_ids <= event_ids:
            raise ValueError(f"{case['id']}: unresolved frontier event reference")
        if not frontier_difference_ids <= difference_ids:
            raise ValueError(f"{case['id']}: unresolved frontier difference reference")
        if target["evaluation_status"] == "not_applicable":
            not_applicable += 1
            if frontier_event_ids or frontier_difference_ids:
                raise ValueError(f"{case['id']}: expected an empty Impact frontier")
            continue
        accepted_events = set(target["accepted_top_event_ids"])
        accepted_difference_sets = [
            set(item) for item in target["accepted_top_atomic_difference_id_sets"]
        ]
        if not (
            frontier_event_ids.intersection(accepted_events)
            or any(
                accepted <= frontier_difference_ids
                for accepted in accepted_difference_sets
            )
        ):
            raise ValueError(
                f"{case['id']}: accepted main change is absent from Impact frontier"
            )
        scorable += 1

    print(
        f"Impact frontier benchmark: {scorable} scorable targets covered, "
        f"{not_applicable} not applicable"
    )


if __name__ == "__main__":
    main()
