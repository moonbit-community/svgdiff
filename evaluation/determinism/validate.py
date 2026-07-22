#!/usr/bin/env python3

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "evaluation/determinism/manifest.v1.json"
REQUIRED_CATEGORIES = {
    "equivalent", "changed", "inserted", "deleted", "resource-mediated",
    "unsupported", "multi-event", "non-default-viewport",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument("--bundle", type=Path)
    return parser.parse_args()


def checked_source(relative: str) -> Path:
    path = (ROOT / relative).resolve()
    if ROOT not in path.parents or not path.is_file():
        raise ValueError(f"unsafe or missing source: {relative}")
    return path


def run_report(cli: Path, case: dict[str, Any], compact: bool) -> bytes:
    command = [
        str(cli), str(checked_source(case["before"])),
        str(checked_source(case["after"])), "--width",
        str(case["viewport"]["width"]), "--height",
        str(case["viewport"]["height"]), *case.get("cli_args", []),
    ]
    if compact:
        command.append("--agent-json")
    result = subprocess.run(command, check=False, capture_output=True)
    if result.returncode != 0 or result.stderr:
        raise ValueError(f"{case['id']}: CLI failed: {result.stderr!r}")
    return result.stdout


def flatten_differences(report: dict[str, Any]) -> list[dict[str, Any]]:
    return [item for group in report["difference_groups"] for item in group["items"]]


def validate_links(report: dict[str, Any]) -> dict[str, int]:
    differences = flatten_differences(report)
    difference_ids = [item["id"] for item in differences]
    event_ids = [item["id"] for item in report["events"]]
    limitation_ids = [item["id"] for item in report["limitations"]]
    for label, identifiers in (
        ("difference", difference_ids),
        ("event", event_ids),
        ("limitation", limitation_ids),
    ):
        if len(identifiers) != len(set(identifiers)):
            raise ValueError(f"duplicate {label} ID")
    difference_set = set(difference_ids)
    limitation_set = set(limitation_ids)
    for difference in differences:
        if not set(difference["effective"].get("limitation_ids", [])) <= limitation_set:
            raise ValueError("dangling difference limitation")
    region_count = 0
    for event in report["events"]:
        if not set(event["difference_ids"]) <= difference_set:
            raise ValueError("dangling event difference")
        if len(event["difference_ids"]) != len(set(event["difference_ids"])):
            raise ValueError("duplicate event difference")
        for region in event["regions"]:
            region_count += 1
            causes = region["possible_causes"]
            if not set(causes["candidate_difference_ids"]) <= difference_set:
                raise ValueError("dangling possible cause")
            if not set(causes.get("limitation_ids", [])) <= limitation_set:
                raise ValueError("dangling region limitation")
    return {
        "difference": len(difference_ids),
        "event": len(event_ids),
        "region": region_count,
        "limitation": len(limitation_ids),
    }


def expect_rejection(report: dict[str, Any]) -> None:
    try:
        validate_links(report)
    except ValueError:
        return
    raise ValueError("integrity negative control was accepted")


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    cases = manifest["cases"]
    repetitions = manifest["repetitions"]
    categories = {category for case in cases for category in case["categories"]}
    if categories != REQUIRED_CATEGORIES:
        raise ValueError("determinism categories drifted")
    bundle = args.bundle.resolve() if args.bundle else None
    if bundle:
        bundle.mkdir(parents=True)

    reports: dict[str, dict[str, Any]] = {}
    results = []
    bundled = []
    for case in cases:
        pretty = [run_report(args.cli.resolve(), case, False) for _ in range(repetitions)]
        compact = [run_report(args.cli.resolve(), case, True) for _ in range(repetitions)]
        if len(set(pretty)) != 1 or len(set(compact)) != 1:
            raise ValueError(f"{case['id']}: report bytes are nondeterministic")
        pretty_report = json.loads(pretty[0])
        compact_report = json.loads(compact[0])
        if pretty_report != compact_report:
            raise ValueError(f"{case['id']}: compact report changed values")
        if pretty_report["comparison"]["viewport"] != case["viewport"]:
            raise ValueError(f"{case['id']}: viewport drifted")
        reports[case["id"]] = pretty_report
        counts = validate_links(pretty_report)
        results.append({
            "id": case["id"], "status": "passed",
            "pretty_sha256": hashlib.sha256(pretty[0]).hexdigest(),
            "compact_sha256": hashlib.sha256(compact[0]).hexdigest(),
            "report_local_id_counts": counts,
        })
        if bundle:
            reports_dir = bundle / "reports"
            reports_dir.mkdir(exist_ok=True)
            for mode, encoded in (("pretty", pretty[0]), ("compact", compact[0])):
                relative = f"reports/{case['id']}.{mode}.json"
                (bundle / relative).write_bytes(encoded)
                bundled.append({
                    "case_id": case["id"], "mode": mode, "path": relative,
                    "sha256": hashlib.sha256(encoded).hexdigest(),
                })

    control = reports["multi-event-ordering"]
    duplicate = copy.deepcopy(control)
    duplicate["events"][1]["id"] = duplicate["events"][0]["id"]
    expect_rejection(duplicate)
    dangling = copy.deepcopy(control)
    dangling["events"][0]["difference_ids"][0] = "diff:missing"
    expect_rejection(dangling)
    cause = copy.deepcopy(control)
    cause["events"][0]["regions"][0]["possible_causes"][
        "candidate_difference_ids"
    ] = ["diff:missing"]
    expect_rejection(cause)

    output = {
        "schema_version": "svgdiff-determinism-results/1",
        "manifest_version": manifest["schema_version"],
        "repetitions_per_mode": repetitions,
        "cases": results,
        "negative_controls": [
            "duplicate_report_local_id",
            "dangling_report_local_reference",
            "dangling_possible_cause",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if bundle:
        (bundle / "bundle.v1.json").write_text(
            json.dumps({
                "schema_version": "svgdiff-determinism-bundle/1",
                "corpus_version": manifest["schema_version"],
                "reports": bundled,
            }, indent=2, sort_keys=True) + "\n"
        )


if __name__ == "__main__":
    main()
