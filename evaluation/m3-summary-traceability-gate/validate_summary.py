#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


def escape_markdown(value: str) -> str:
    return (
        value.replace("\\", "\\\\")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
        .replace("\t", "\\t")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("`", "&#96;")
        .replace("*", "\\*")
        .replace("_", "\\_")
        .replace("[", "\\[")
        .replace("]", "\\]")
    )


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def require_text(summary: str, value: str, context: str) -> None:
    require(escape_markdown(value) in summary, f"summary lacks {context}: {value}")


def validate(report: dict, summary: str) -> None:
    require(summary.startswith("# SVG Diff Summary\n"), "summary title mismatch")
    require("Derived presentation only" in summary, "summary lacks derived-presentation disclaimer")
    require("This Markdown may omit evidence" in summary, "summary falsely implies completeness")
    require("canonical Structured Report JSON is authoritative" in summary, "summary lacks canonical authority")
    require_text(summary, report["schema_version"], "report Schema")
    require(
        f"- Analysis status: {escape_markdown(report['analysis_status'])}" in summary,
        "summary analysis status mismatch",
    )

    require_text(summary, "event_rendered_pareto/v1", "Impact policy")
    require_text(summary, "not_calibrated", "Impact calibration state")
    require("does not provide a severity label or total order" in summary, "summary lacks Impact limitation")
    for event in report["events"]:
        require_text(summary, event["id"], "Visual Event ID")
    differences = [
        difference
        for group in report["difference_groups"]
        for difference in group["items"]
    ]
    for difference in differences:
        require_text(summary, difference["id"], "Atomic Difference ID")
        for diagnostic_id in difference["effective"].get("limitation_ids", []):
            require_text(summary, diagnostic_id, "relation Diagnostic ID")
    for diagnostic in report["limitations"]:
        require_text(summary, diagnostic["id"], "Diagnostic ID")

    if report["analysis_status"] != "complete":
        require("Inspect coverage and Diagnostics" in summary, "limited report lacks coverage warning")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Markdown summary traceability.")
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
        summary = args.summary.read_text(encoding="utf-8")
        validate(report, summary)
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print(f"Markdown summary traceability passed: {args.summary}")


if __name__ == "__main__":
    main()
