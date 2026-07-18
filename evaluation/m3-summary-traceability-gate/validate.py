#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


EXPECTED = {
    "compact_json_value_identity": {
        "commands": {"scripts/test-cli.sh", "scripts/test-report-determinism.sh"},
        "negative_controls": {"parsed_value_mismatch"},
    },
    "projection_exact_reconstruction": {
        "commands": {"scripts/test-agent-projection.sh"},
        "coverage_classes": {"complete", "partial", "failed", "empty_inventory", "flip"},
        "negative_controls": {
            "missing_record",
            "duplicate_record",
            "reordered_record",
            "miscounted_section",
            "wrong_section",
            "unknown_projection_identity",
            "source_schema_mismatch",
        },
    },
    "impact_frontier_semantic_edges": {
        "commands": {"scripts/test-impact-assessment.sh", "scripts/test-report-determinism.sh"},
        "negative_controls": {
            "dangling_impact_event_reference",
            "wrong_valid_impact_difference_reference",
        },
    },
    "transitive_evidence_reference_closure": {
        "commands": {"scripts/test-report-determinism.sh"},
        "negative_controls": {
            "duplicate_report_local_id",
            "dangling_report_local_reference",
            "duplicate_report_local_reference",
            "alignment_role_mismatch",
            "incomplete_cause_envelope",
            "cross_event_cause_contamination",
        },
    },
    "markdown_traceability_without_authority": {
        "commands": {"scripts/test-m3-summary-traceability-gate.sh"},
        "coverage_classes": {"complete", "partial", "failed"},
        "negative_controls": {
            "missing_trace_id",
            "missing_authority_disclaimer",
            "wrong_analysis_status",
        },
    },
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def validate(manifest: dict) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-m3-summary-traceability-gate/1",
        "gate identity mismatch",
    )
    require(manifest.get("report_schema_version") == "1.45", "report Schema mismatch")
    require(
        manifest.get("agent_projection_version") == "svgdiff-agent-projection/1",
        "Agent projection identity mismatch",
    )
    require(
        manifest.get("impact_policy_id") == "event_rendered_pareto/v1",
        "Impact policy identity mismatch",
    )
    require(
        manifest.get("markdown_authority") == "derived_presentation_only",
        "Markdown authority mismatch",
    )
    require(
        manifest.get("canonical_authority") == "structured_report_json",
        "canonical authority mismatch",
    )

    obligations = manifest.get("obligations")
    require(isinstance(obligations, list), "obligations must be an array")
    by_id = {item.get("id"): item for item in obligations if isinstance(item, dict)}
    require(set(by_id) == set(EXPECTED), "gate obligation set mismatch")
    require(len(by_id) == len(obligations), "gate obligation IDs must be unique")
    for identifier, expected in EXPECTED.items():
        obligation = by_id[identifier]
        require(isinstance(obligation.get("claim"), str) and obligation["claim"], f"{identifier}: missing claim")
        for field, values in expected.items():
            actual = obligation.get(field)
            require(isinstance(actual, list), f"{identifier}: {field} must be an array")
            require(set(actual) == values, f"{identifier}: {field} mismatch")
            require(len(actual) == len(set(actual)), f"{identifier}: duplicate {field}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate the M3 summary-traceability gate manifest.")
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        validate(manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print(f"M3 summary-traceability manifest passed: {args.manifest}")


if __name__ == "__main__":
    main()
