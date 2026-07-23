#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import shlex
import subprocess
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from evaluation.report_causes import (
    cause_candidate_difference_ids,
    report_differences,
    report_difference_ids,
)

ROOT = Path(__file__).resolve().parent
ACCEPTANCE_VERSION = "agent-acceptance/1"
ANALYSIS_STATUSES = {"complete", "partial", "failed"}
EQUALITY_CONCLUSIONS = {"established", "different", "not_established"}
CAUSE_GUARANTEES = {
    "sound_overapproximation",
    "not_established",
    "not_applicable",
}
MAGNITUDE_STATUSES = {"measured", "not_computed", "indeterminate"}


def report_limitation_ids(report):
    return [item["id"] for item in report.get("limitations", [])]


def report_cause_candidate_ids(report, causes):
    return cause_candidate_difference_ids(causes, report_difference_ids(report))


def read_json_lines(path: Path):
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        try:
            yield json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"{path}:{line_number}: invalid JSON: {error}") from error


def require_string_list(value, field: str, *, nonempty: bool = False) -> None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{field} must be an array of strings")
    if nonempty and not value:
        raise ValueError(f"{field} must not be empty")
    if len(value) != len(set(value)):
        raise ValueError(f"{field} must not contain duplicates")


def validate_report(report, source: Path) -> None:
    if not isinstance(report, dict):
        raise ValueError(f"{source}: report must be a JSON object")
    if not isinstance(report.get("schema_version"), str):
        raise ValueError(f"{source}: report lacks schema_version")
    if report.get("analysis_status") not in ANALYSIS_STATUSES:
        raise ValueError(f"{source}: invalid analysis_status")
    for field in ("difference_groups", "events", "limitations"):
        if not isinstance(report.get(field), list):
            raise ValueError(f"{source}: report field {field} must be an array")
    for group in report["difference_groups"]:
        if not isinstance(group, dict) or not isinstance(group.get("items"), list):
            raise ValueError(f"{source}: every difference group must contain items")


def validate_answer(answer, expected_case_id: str) -> None:
    if not isinstance(answer, dict):
        raise ValueError("agent answer must be a JSON object")
    if answer.get("case_id") != expected_case_id:
        raise ValueError(
            f"agent answer case_id {answer.get('case_id')!r} does not match {expected_case_id!r}"
        )
    if answer.get("acceptance_version") != ACCEPTANCE_VERSION:
        raise ValueError("agent answer uses an unsupported acceptance_version")

    coverage = answer.get("coverage")
    if not isinstance(coverage, dict):
        raise ValueError("coverage must be an object")
    if coverage.get("analysis_status") not in ANALYSIS_STATUSES:
        raise ValueError("coverage.analysis_status is invalid")
    if coverage.get("equality_conclusion") not in EQUALITY_CONCLUSIONS:
        raise ValueError("coverage.equality_conclusion is invalid")
    require_string_list(coverage.get("diagnostic_ids"), "coverage.diagnostic_ids")

    differences = answer.get("differences")
    if not isinstance(differences, list):
        raise ValueError("differences must be an array")
    for index, difference in enumerate(differences):
        prefix = f"differences[{index}]"
        if not isinstance(difference, dict):
            raise ValueError(f"{prefix} must be an object")
        require_string_list(
            difference.get("atomic_difference_ids"),
            f"{prefix}.atomic_difference_ids",
            nonempty=True,
        )
        if not isinstance(difference.get("kind"), str) or not difference["kind"]:
            raise ValueError(f"{prefix}.kind must be a nonempty string")
        require_string_list(difference.get("subject_ids"), f"{prefix}.subject_ids")
        if not isinstance(difference.get("description"), str) or not difference["description"]:
            raise ValueError(f"{prefix}.description must be a nonempty string")
        claims = difference.get("magnitude_claims")
        if not isinstance(claims, list):
            raise ValueError(f"{prefix}.magnitude_claims must be an array")
        for claim_index, claim in enumerate(claims):
            claim_prefix = f"{prefix}.magnitude_claims[{claim_index}]"
            if not isinstance(claim, dict):
                raise ValueError(f"{claim_prefix} must be an object")
            if not isinstance(claim.get("field"), str) or not claim["field"]:
                raise ValueError(f"{claim_prefix}.field must be a nonempty string")
            if claim.get("status") not in MAGNITUDE_STATUSES:
                raise ValueError(f"{claim_prefix}.status is invalid")
            if "value" not in claim or "unit" not in claim:
                raise ValueError(f"{claim_prefix} must contain value and unit")
            if claim["unit"] is not None and not isinstance(claim["unit"], str):
                raise ValueError(f"{claim_prefix}.unit must be a string or null")
        require_string_list(difference.get("region_ids"), f"{prefix}.region_ids")
        require_string_list(
            difference.get("possible_cause_changed_fact_ids"),
            f"{prefix}.possible_cause_changed_fact_ids",
        )
        if difference.get("cause_guarantee") not in CAUSE_GUARANTEES:
            raise ValueError(f"{prefix}.cause_guarantee is invalid")
        require_string_list(difference.get("diagnostic_ids"), f"{prefix}.diagnostic_ids")

    main_changes = answer.get("main_changes")
    if not isinstance(main_changes, list):
        raise ValueError("main_changes must be an array")
    for index, change in enumerate(main_changes):
        prefix = f"main_changes[{index}]"
        if not isinstance(change, dict):
            raise ValueError(f"{prefix} must be an object")
        require_string_list(change.get("event_ids"), f"{prefix}.event_ids")
        require_string_list(
            change.get("atomic_difference_ids"), f"{prefix}.atomic_difference_ids"
        )
        for field in ("description", "rationale"):
            if not isinstance(change.get(field), str) or not change[field]:
                raise ValueError(f"{prefix}.{field} must be a nonempty string")

    require_string_list(answer.get("limitations"), "limitations")


def write_json_lines(path: Path, values) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as output:
        for value in values:
            output.write(json.dumps(value, sort_keys=True, separators=(",", ":")))
            output.write("\n")


def prepare_tasks(reports: Path, output: Path, prompt_path: Path) -> None:
    prompt = prompt_path.read_text(encoding="utf-8").strip()
    if not prompt:
        raise ValueError("prompt must not be empty")
    report_paths = sorted(reports.glob("*.json"))
    if not report_paths:
        raise ValueError(f"no report JSON files found in {reports}")

    tasks = []
    seen_case_ids = set()
    for report_path in report_paths:
        case_id = report_path.stem
        if case_id in seen_case_ids:
            raise ValueError(f"duplicate case ID: {case_id}")
        seen_case_ids.add(case_id)
        report = json.loads(report_path.read_text(encoding="utf-8"))
        validate_report(report, report_path)
        tasks.append(
            {
                "case_id": case_id,
                "acceptance_version": ACCEPTANCE_VERSION,
                "prompt": prompt,
                "report": report,
            }
        )
    write_json_lines(output, tasks)


def run_agent(tasks_path: Path, output: Path, agent: str, timeout: float) -> None:
    command = shlex.split(agent)
    if not command:
        raise ValueError("agent command must not be empty")

    answers = []
    for task in read_json_lines(tasks_path):
        case_id = task.get("case_id")
        if not isinstance(case_id, str) or not case_id:
            raise ValueError("task lacks a valid case_id")
        try:
            result = subprocess.run(
                command,
                input=json.dumps(task),
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"{case_id}: agent timed out after {timeout} seconds") from error
        if result.returncode != 0:
            raise RuntimeError(
                f"{case_id}: agent exited {result.returncode}: {result.stderr.strip()}"
            )
        try:
            answer = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise ValueError(f"{case_id}: agent returned invalid JSON: {error}") from error
        validate_answer(answer, case_id)
        answers.append(answer)
    write_json_lines(output, answers)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run text-only SVG Diff evaluations.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    prepare = subparsers.add_parser("prepare", help="Build report-only task JSONL.")
    prepare.add_argument("--reports", type=Path, required=True)
    prepare.add_argument("--output", type=Path, required=True)
    prepare.add_argument("--prompt", type=Path, default=ROOT / "prompt.txt")

    run = subparsers.add_parser("run", help="Run an agent adapter over task JSONL.")
    run.add_argument("--tasks", type=Path, required=True)
    run.add_argument("--output", type=Path, required=True)
    run.add_argument("--agent", required=True)
    run.add_argument("--timeout", type=float, default=60.0)
    return parser


def main() -> None:
    args = build_parser().parse_args()
    try:
        if args.command == "prepare":
            prepare_tasks(args.reports, args.output, args.prompt)
        else:
            run_agent(args.tasks, args.output, args.agent, args.timeout)
    except (OSError, ValueError, RuntimeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
