#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


EXPECTED_OBLIGATIONS = {
    "profile_scope",
    "feature_inventory",
    "central_coverage_proof",
    "unsupported_input_safety",
    "renderer_disposition",
    "sound_evidence_graph",
    "failed_admission",
    "advanced_non_goal_coverage",
    "advanced_adoption_boundary",
    "hostile_boundary_regression",
}
EXPECTED_FORBIDDEN = {
    "complete_means_entire_svg_standard",
    "complete_means_cross_browser_equivalence",
    "empty_differences_override_partial_or_failed",
    "raw_pixel_equality_overrides_diagnostics",
    "missing_measurement_means_zero",
    "partial_cause_envelope_is_complete",
    "future_identity_format_means_implemented",
    "finite_test_pass_rate_defines_semantic_coverage",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def nonempty_strings(value, field: str) -> None:
    require(isinstance(value, list) and bool(value), f"{field} must be a nonempty array")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{field} must contain nonempty strings",
    )
    require(len(value) == len(set(value)), f"{field} must not contain duplicates")


def validate(root: Path, manifest: dict) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-terminal-coverage-gate/1",
        "gate identity mismatch",
    )
    require(
        manifest.get("claim_scope") == "declared_supported_profile_schema_1_44",
        "claim scope mismatch",
    )
    require(
        manifest.get("canonical_rule")
        == "encountered_visual_semantics_require_evidence_or_completeness_revoking_diagnostic",
        "canonical rule mismatch",
    )
    require(
        manifest.get("required_analysis_statuses") == ["complete", "partial", "failed"],
        "analysis status contract mismatch",
    )
    forbidden = manifest.get("forbidden_inferences")
    nonempty_strings(forbidden, "forbidden_inferences")
    require(set(forbidden) == EXPECTED_FORBIDDEN, "forbidden inference inventory mismatch")

    obligations = manifest.get("obligations")
    require(isinstance(obligations, list), "obligations must be an array")
    by_id = {item.get("id"): item for item in obligations if isinstance(item, dict)}
    require(set(by_id) == EXPECTED_OBLIGATIONS, "obligation inventory mismatch")
    require(len(by_id) == len(obligations), "obligation IDs must be unique")
    for identifier, item in by_id.items():
        for field in ("claim", "boundary"):
            require(isinstance(item.get(field), str) and item[field], f"{identifier}: missing {field}")
        for field in ("authorities", "validation_commands"):
            values = item.get(field)
            nonempty_strings(values, f"{identifier}.{field}")
            for value in values:
                require((root / value).is_file(), f"{identifier}: missing {field} path {value}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate the terminal coverage gate manifest.")
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent.parent
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        require(isinstance(manifest, dict), "manifest must contain a JSON object")
        validate(root, manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print("Terminal coverage manifest passed: evidence-or-Diagnostic closure is explicit")


if __name__ == "__main__":
    main()
