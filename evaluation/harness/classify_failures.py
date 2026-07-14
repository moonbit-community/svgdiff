#!/usr/bin/env python3

import argparse
from collections import Counter
import json
from pathlib import Path
import sys

from harness import read_json_lines


ROOT = Path(__file__).resolve().parent


def diagnostic_domain(code, policy):
    matches = []
    for domain, rules in policy["diagnostic_domains"].items():
        if code in rules.get("exact", []) or any(
            code.startswith(prefix) for prefix in rules.get("prefix", [])
        ):
            matches.append(domain)
    if len(matches) > 1:
        raise ValueError(f"Diagnostic {code} matches multiple domains: {matches}")
    return matches[0] if matches else "unclassified"


def metric_domain(metric, policy):
    matches = [
        domain
        for domain, metrics in policy["metric_domains"].items()
        if metric in metrics
    ]
    if len(matches) > 1:
        raise ValueError(f"metric {metric} matches multiple domains: {matches}")
    return matches[0] if matches else "unclassified"


def classify(tasks, gate, policy):
    cases = []
    diagnostic_counts = Counter()
    for task in sorted(tasks, key=lambda item: item["case_id"]):
        observations = []
        for diagnostic in task["report"]["diagnostics"]:
            domain = diagnostic_domain(diagnostic["code"], policy)
            diagnostic_counts[domain] += 1
            observations.append(
                {
                    "domain": domain,
                    "source": "diagnostic",
                    "diagnostic_id": diagnostic["id"],
                    "diagnostic_code": diagnostic["code"],
                }
            )
        cases.append({"case_id": task["case_id"], "observations": observations})

    threshold_failures = []
    threshold_counts = Counter()
    for check in gate["checks"]:
        if check["passed"]:
            continue
        domain = metric_domain(check["metric"], policy)
        threshold_counts[domain] += 1
        threshold_failures.append(
            {
                "domain": domain,
                "source": "threshold",
                "metric": check["metric"],
                "operator": check["operator"],
                "threshold": check["threshold"],
                "actual": check["actual"],
            }
        )

    all_domains = set(policy["diagnostic_domains"]) | set(
        policy["metric_domains"]
    ) | {"unclassified"}
    return {
        "classification_version": policy["schema_version"],
        "gate_passed": gate["passed"],
        "summary": {
            "diagnostic_observations_by_domain": {
                domain: diagnostic_counts[domain] for domain in sorted(all_domains)
            },
            "threshold_failures_by_domain": {
                domain: threshold_counts[domain] for domain in sorted(all_domains)
            },
            "has_unclassified": (
                diagnostic_counts["unclassified"] > 0
                or threshold_counts["unclassified"] > 0
            ),
        },
        "cases": cases,
        "threshold_failures": threshold_failures,
    }


def build_parser():
    parser = argparse.ArgumentParser(description="Attribute SVG Diff benchmark failures.")
    parser.add_argument("--tasks", type=Path, required=True)
    parser.add_argument("--gate", type=Path, required=True)
    parser.add_argument(
        "--policy",
        type=Path,
        default=ROOT.parent / "failure-classification.v1.json",
    )
    parser.add_argument("--output", type=Path, required=True)
    return parser


def main():
    args = build_parser().parse_args()
    try:
        tasks = list(read_json_lines(args.tasks))
        gate = json.loads(args.gate.read_text(encoding="utf-8"))
        policy = json.loads(args.policy.read_text(encoding="utf-8"))
        if policy.get("schema_version") != "svgdiff-failure-classification/1":
            raise ValueError("unsupported failure-classification policy")
        result = classify(tasks, gate, policy)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
