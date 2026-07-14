#!/usr/bin/env python3

import argparse
import json
import platform
import resource
import subprocess
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Measure one isolated svgdiff run.")
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--expected-differences", required=True, type=int)
    return parser.parse_args()


def normalized_rss_mib(raw: int) -> float:
    if platform.system() == "Darwin":
        return raw / (1024 * 1024)
    return raw / 1024


def main() -> None:
    args = parse_args()
    start = time.perf_counter()
    result = subprocess.run(
        [
            str(args.cli),
            str(args.before),
            str(args.after),
            "--width",
            str(args.width),
            "--height",
            str(args.height),
            "--agent-json",
        ],
        check=False,
        capture_output=True,
    )
    elapsed_ms = (time.perf_counter() - start) * 1000
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    if result.returncode != 0 or result.stderr:
        raise ValueError(
            f"measured CLI failed: status={result.returncode}, "
            f"stderr={result.stderr.decode(errors='replace')!r}"
        )
    report = json.loads(result.stdout)
    if report.get("analysis_status") != "complete":
        raise ValueError("measured workload did not produce complete analysis")
    if len(report.get("atomic_differences", [])) != args.expected_differences:
        raise ValueError("measured workload produced an unexpected difference count")
    print(
        json.dumps(
            {
                "elapsed_ms": elapsed_ms,
                "peak_rss_mib": normalized_rss_mib(usage.ru_maxrss),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
