#!/usr/bin/env python3

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PROFILE = ROOT / "evaluation" / "language-model-benchmark" / "profile.v1.json"
RETAINED = ("answers.jsonl", "metrics.json", "gate.json", "failures.json")
IDENTITY_FILES = {
    "adapter": ROOT / "evaluation" / "harness" / "codex_report_only_agent.py",
    "answer_schema": ROOT / "evaluation" / "harness" / "agent-answer.schema.json",
    "structured_output_schema": ROOT / "evaluation" / "harness" / "codex-agent-answer.schema.json",
    "canonical_prompt": ROOT / "evaluation" / "harness" / "prompt.txt",
    "harness": ROOT / "evaluation" / "harness" / "harness.py",
    "scorer": ROOT / "evaluation" / "harness" / "score.py",
    "threshold_checker": ROOT / "evaluation" / "harness" / "check_thresholds.py",
    "failure_classifier": ROOT / "evaluation" / "harness" / "classify_failures.py",
    "thresholds": ROOT / "evaluation" / "benchmark-thresholds.v1.json",
    "corpus_manifest": ROOT / "evaluation" / "corpus" / "manifest.json",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_command(command: list[str]) -> str:
    result = subprocess.run(command, text=True, capture_output=True, check=True)
    return result.stdout.strip()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def require_empty_output(path: Path) -> None:
    if path.exists() and any(path.iterdir()):
        raise ValueError(f"output directory is not empty: {path}")
    path.mkdir(parents=True, exist_ok=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the opt-in report-only language-model benchmark.")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--codex", default="codex")
    args = parser.parse_args()

    output = args.output.resolve()
    profile_path = args.profile.resolve()
    profile = json.loads(profile_path.read_text(encoding="utf-8"))
    codex_path = shutil.which(args.codex)
    if codex_path is None:
        raise ValueError(f"Codex executable not found: {args.codex}")
    codex_version = read_command([codex_path, "--version"])
    if codex_version != profile.get("codex_cli_version"):
        raise ValueError(
            f"Codex CLI version {codex_version!r} does not match pinned "
            f"{profile.get('codex_cli_version')!r}"
        )
    require_empty_output(output)
    shutil.copy2(profile_path, output / "profile.json")

    started = datetime.now(timezone.utc)
    benchmark_exit_code = 1
    with tempfile.TemporaryDirectory(prefix="svgdiff-language-model-benchmark-") as temporary:
        run_directory = Path(temporary) / "run"
        agent_command = shlex.join(
            [
                sys.executable,
                str(ROOT / "evaluation" / "harness" / "codex_report_only_agent.py"),
                "--profile",
                str(profile_path),
                "--codex",
                codex_path,
            ]
        )
        command = [
            "sh",
            str(ROOT / "scripts" / "run-agent-benchmark.sh"),
            "--output",
            str(run_directory),
            "--agent",
            agent_command,
            "--agent-timeout",
            str(profile["per_case_timeout_seconds"] + 30),
        ]
        benchmark_exit_code = subprocess.run(command, cwd=ROOT, check=False).returncode
        for filename in RETAINED:
            source = run_directory / filename
            if source.is_file():
                shutil.copy2(source, output / filename)

    completed = datetime.now(timezone.utc)
    runtime = {
        "schema_version": "svgdiff-language-model-runtime/1",
        "started_at_utc": started.isoformat(),
        "completed_at_utc": completed.isoformat(),
        "duration_seconds": (completed - started).total_seconds(),
        "benchmark_exit_code": benchmark_exit_code,
        "codex_cli_path": codex_path,
        "codex_cli_version": codex_version,
        "model": profile["model"],
        "reasoning_effort": profile["reasoning_effort"],
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "repository_commit": read_command(["git", "-C", str(ROOT), "rev-parse", "HEAD"]),
        "repository_dirty_at_run": bool(
            read_command(["git", "-C", str(ROOT), "status", "--short"])
        ),
        "tool_event_rejection_enforced": True,
        "input_authority": profile["input_authority"],
        "implementation_sha256": {
            name: digest(path) for name, path in IDENTITY_FILES.items()
        },
    }
    write_json(output / "runtime.json", runtime)

    artifact_names = ("profile.json", "runtime.json", *RETAINED)
    present = [name for name in artifact_names if (output / name).is_file()]
    write_json(
        output / "integrity.json",
        {
            "schema_version": "svgdiff-language-model-integrity/1",
            "algorithm": "sha256",
            "files": {name: digest(output / name) for name in present},
        },
    )

    if benchmark_exit_code != 0:
        raise SystemExit(benchmark_exit_code)
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "evaluation" / "language-model-benchmark" / "validate_observation.py"),
            str(output),
        ],
        cwd=ROOT,
        check=True,
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
