#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


def build_parser():
    parser = argparse.ArgumentParser(description="Check SVG Diff benchmark thresholds.")
    parser.add_argument("--metrics", type=Path, required=True)
    parser.add_argument("--thresholds", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main():
    args = build_parser().parse_args()
    try:
        metrics = json.loads(args.metrics.read_text(encoding="utf-8"))
        thresholds = json.loads(args.thresholds.read_text(encoding="utf-8"))
        if thresholds.get("schema_version") != "svgdiff-benchmark-thresholds/1":
            raise ValueError("unsupported benchmark threshold version")
        if thresholds.get("metrics_version") != metrics.get("metrics_version"):
            raise ValueError("threshold and metrics versions differ")
        aggregate = metrics.get("aggregate")
        if not isinstance(aggregate, dict):
            raise ValueError("metrics document lacks aggregate results")

        checks = []
        for name, threshold in sorted(thresholds.get("minimum", {}).items()):
            actual = aggregate.get(name)
            if not isinstance(actual, (int, float)):
                raise ValueError(f"metric {name} is absent or non-numeric")
            checks.append(
                {
                    "metric": name,
                    "operator": ">=",
                    "threshold": threshold,
                    "actual": actual,
                    "passed": actual >= threshold,
                }
            )
        for name, threshold in sorted(thresholds.get("maximum", {}).items()):
            actual = aggregate.get(name)
            if not isinstance(actual, (int, float)):
                raise ValueError(f"metric {name} is absent or non-numeric")
            checks.append(
                {
                    "metric": name,
                    "operator": "<=",
                    "threshold": threshold,
                    "actual": actual,
                    "passed": actual <= threshold,
                }
            )
        if not checks:
            raise ValueError("threshold document contains no checks")

        result = {
            "gate_version": "svgdiff-benchmark-gate/1",
            "thresholds_version": thresholds["schema_version"],
            "metrics_version": metrics["metrics_version"],
            "passed": all(check["passed"] for check in checks),
            "checks": checks,
        }
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        if not result["passed"]:
            failed = [
                f"{item['metric']} {item['actual']} not {item['operator']} {item['threshold']}"
                for item in checks
                if not item["passed"]
            ]
            print("benchmark threshold failure: " + "; ".join(failed), file=sys.stderr)
            raise SystemExit(1)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
