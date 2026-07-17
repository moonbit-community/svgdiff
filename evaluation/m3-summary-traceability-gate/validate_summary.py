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

    impact = report["impact_assessment"]
    require_text(summary, impact["policy_id"], "Impact policy")
    require_text(summary, impact["calibration_status"], "Impact calibration state")
    require_text(summary, impact["frontier_relation"], "Impact frontier relation")
    require("does not provide a severity label or total order" in summary, "summary lacks Impact limitation")
    for group in impact["frontier_groups"]:
        for event_id in group["event_ids"]:
            require_text(summary, event_id, "frontier event ID")
        for difference_id in group["atomic_difference_ids"]:
            require_text(summary, difference_id, "frontier Atomic Difference ID")

    for difference in report["atomic_differences"]:
        require_text(summary, difference["id"], "Atomic Difference ID")
        if difference.get("subject_alignment_id") is not None:
            require_text(summary, difference["subject_alignment_id"], "Subject Alignment ID")
        for fact_id in difference["changed_fact_ids"]:
            require_text(summary, fact_id, "Changed Fact ID")
        for diagnostic_id in difference["computed_relation"]["diagnostic_ids"]:
            require_text(summary, diagnostic_id, "relation Diagnostic ID")
    for diagnostic in report["diagnostics"]:
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
