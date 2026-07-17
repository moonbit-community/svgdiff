#!/usr/bin/env python3

import argparse
import hashlib
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "harness"))

from harness import validate_answer


REQUIRED_FILES = (
    "profile.json",
    "runtime.json",
    "answers.jsonl",
    "metrics.json",
    "gate.json",
    "failures.json",
)


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate(directory: Path) -> None:
    require(directory.is_dir(), f"observation directory not found: {directory}")
    for filename in (*REQUIRED_FILES, "integrity.json"):
        require((directory / filename).is_file(), f"missing {filename}")

    profile = load_json(directory / "profile.json")
    runtime = load_json(directory / "runtime.json")
    metrics = load_json(directory / "metrics.json")
    gate = load_json(directory / "gate.json")
    failures = load_json(directory / "failures.json")
    integrity = load_json(directory / "integrity.json")
    thresholds = load_json(
        Path(__file__).resolve().parent.parent / "benchmark-thresholds.v1.json"
    )

    require(
        profile.get("schema_version")
        == "svgdiff-language-model-benchmark-profile/1",
        "profile identity mismatch",
    )
    require(
        runtime.get("schema_version") == "svgdiff-language-model-runtime/1",
        "runtime identity mismatch",
    )
    require(runtime.get("benchmark_exit_code") == 0, "benchmark did not exit cleanly")
    require(runtime.get("tool_event_rejection_enforced") is True, "tool rejection was not enforced")
    require(runtime.get("codex_cli_version") == profile.get("codex_cli_version"), "Codex CLI version mismatch")
    require(runtime.get("model") == profile.get("model"), "model identity mismatch")
    require(runtime.get("reasoning_effort") == profile.get("reasoning_effort"), "reasoning identity mismatch")
    require(
        profile.get("case_id_exposure")
        == "fresh_random_opaque_id_per_case_invocation",
        "case IDs were not declared opaque",
    )
    require(metrics.get("case_count") == 13, "accepted corpus must contain 13 cases")
    require(gate.get("passed") is True, "benchmark threshold gate failed")
    expected_checks = set(thresholds["minimum"]) | set(thresholds["maximum"])
    actual_checks = {check.get("metric") for check in gate.get("checks", [])}
    require(actual_checks == expected_checks, "benchmark threshold check set mismatch")
    require(
        all(check.get("passed") is True for check in gate.get("checks", [])),
        "benchmark contains a failed threshold check",
    )
    summary = failures.get("summary", {})
    require(failures.get("gate_passed") is True, "failure classification records a failed gate")
    require(summary.get("has_unclassified") is False, "unclassified failures remain")
    require(
        summary.get("threshold_failures_by_domain", {}).get("unclassified") == 0,
        "unclassified threshold failures remain",
    )

    answers = [
        json.loads(line)
        for line in (directory / "answers.jsonl").read_text(encoding="utf-8").splitlines()
        if line.strip()
    ]
    case_ids = [answer.get("case_id") for answer in answers]
    require(len(case_ids) == 13, "observation must retain 13 answers")
    require(len(case_ids) == len(set(case_ids)), "answer case IDs must be unique")
    require(all(isinstance(case_id, str) and case_id for case_id in case_ids), "answer case ID is invalid")
    for answer in answers:
        validate_answer(answer, answer["case_id"])
    metric_case_ids = [item.get("case_id") for item in metrics.get("per_case", [])]
    failure_case_ids = [item.get("case_id") for item in failures.get("cases", [])]
    require(case_ids == metric_case_ids, "answer and metric case order mismatch")
    require(case_ids == failure_case_ids, "answer and failure case order mismatch")

    require(integrity.get("algorithm") == "sha256", "unsupported integrity algorithm")
    recorded = integrity.get("files")
    require(isinstance(recorded, dict), "integrity files must be an object")
    require(set(recorded) == set(REQUIRED_FILES), "integrity file set mismatch")
    for filename, expected in recorded.items():
        require(digest(directory / filename) == expected, f"integrity mismatch: {filename}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate one retained language-model benchmark observation.")
    parser.add_argument("observation", type=Path)
    args = parser.parse_args()
    try:
        validate(args.observation)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print(f"Language-model observation passed: {args.observation}")


if __name__ == "__main__":
    main()
