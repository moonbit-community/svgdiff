#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys

from validate_summary import escape_markdown, validate


def expect_rejected(report: dict, summary: str, name: str) -> None:
    try:
        validate(report, summary)
    except ValueError:
        return
    raise ValueError(f"summary validator accepted negative control: {name}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Exercise Markdown summary negative controls.")
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    summary = args.summary.read_text(encoding="utf-8")

    trace_id = report["atomic_differences"][0]["id"]
    missing_trace = summary.replace(escape_markdown(trace_id), "")
    expect_rejected(report, missing_trace, "missing_trace_id")

    missing_authority = summary.replace(
        "canonical Structured Report JSON is authoritative",
        "canonical report is available",
        1,
    )
    expect_rejected(report, missing_authority, "missing_authority_disclaimer")

    wrong_status = summary.replace(
        f"- Analysis status: {escape_markdown(report['analysis_status'])}",
        "- Analysis status: failed",
        1,
    )
    expect_rejected(report, wrong_status, "wrong_analysis_status")
    print("Markdown summary negative controls: 3 rejected")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
