#!/usr/bin/env python3

import argparse
import json
import platform
import statistics
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PROBE = ROOT / "evaluation/performance/probe.py"
GENERATOR = ROOT / "evaluation/performance/generate_workload.py"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run svgdiff performance budgets.")
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def probe(cli: Path, directory: Path, workload: dict) -> dict:
    result = subprocess.run(
        [
            sys.executable,
            str(PROBE),
            "--cli",
            str(cli),
            "--before",
            str(directory / "before.svg"),
            "--after",
            str(directory / "after.svg"),
            "--width",
            str(workload["viewport_width"]),
            "--height",
            str(workload["viewport_height"]),
            "--expected-differences",
            str(workload.get("expected_differences", workload["subjects_per_input"])),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    version = subprocess.run(
        [str(args.cli), "--version"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    results = []
    with tempfile.TemporaryDirectory(prefix="svgdiff-performance-") as temporary:
        temporary_path = Path(temporary)
        for workload in manifest["workloads"]:
            case_directory = temporary_path / workload["id"]
            subprocess.run(
                [
                    sys.executable,
                    str(GENERATOR),
                    "--workload",
                    workload["id"],
                    "--manifest",
                    str(args.manifest),
                    "--output",
                    str(case_directory),
                ],
                check=True,
            )
            samples = [
                probe(args.cli, case_directory, workload)
                for _ in range(manifest["samples_per_workload"])
            ]
            median_elapsed = statistics.median(
                sample["elapsed_ms"] for sample in samples
            )
            max_rss = max(sample["peak_rss_mib"] for sample in samples)
            checks = [
                {
                    "metric": "median_wall_time_ms",
                    "actual": median_elapsed,
                    "maximum": workload["median_wall_time_ms_max"],
                    "passed": median_elapsed <= workload["median_wall_time_ms_max"],
                },
                {
                    "metric": "peak_rss_mib",
                    "actual": max_rss,
                    "maximum": workload["peak_rss_mib_max"],
                    "passed": max_rss <= workload["peak_rss_mib_max"],
                },
            ]
            results.append(
                {
                    "id": workload["id"],
                    "size": workload["size"],
                    "subjects_per_input": workload["subjects_per_input"],
                    "viewport_width": workload["viewport_width"],
                    "viewport_height": workload["viewport_height"],
                    "samples": samples,
                    "median_wall_time_ms": median_elapsed,
                    "maximum_peak_rss_mib": max_rss,
                    "checks": checks,
                    "passed": all(check["passed"] for check in checks),
                }
            )
    output = {
        "schema_version": manifest["result_schema_version"],
        "budget_version": manifest["schema_version"],
        "target": manifest["target"],
        "build_profile": manifest["build_profile"],
        "samples_per_workload": manifest["samples_per_workload"],
        "environment": {
            "operating_system": platform.system(),
            "architecture": platform.machine(),
            "python_version": platform.python_version(),
            "product_version": version,
        },
        "workloads": results,
        "passed": all(result["passed"] for result in results),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if not output["passed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
