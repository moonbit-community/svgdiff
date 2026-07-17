#!/usr/bin/env python3

import argparse
import hashlib
import json
from pathlib import Path
import sys


EXPECTED_OBLIGATIONS = {
    "complete_difference_inventory": ("agent", "agent_atomic_difference_recall_macro", 1.0),
    "accepted_main_change_first": ("agent", "agent_main_difference_mrr", 1.0),
    "localized_outcomes": ("agent", "agent_region_overlap_macro", 1.0),
    "possible_cause_recall": ("agent", "agent_possible_cause_recall_macro", 1.0),
    "possible_cause_precision": ("agent", "agent_cause_false_positive_count", 0),
    "coverage_status": ("agent", "agent_coverage_status_accuracy_macro", 1.0),
    "equality_safety": ("agent", "agent_equality_conclusion_accuracy_macro", 1.0),
    "diagnostic_recall": ("agent", "agent_required_diagnostic_recall_macro", 1.0),
    "hard_safety": ("agent", "agent_hard_safety_failure_count", 0),
    "reference_validity": ("agent", "invalid_evidence_reference_count", 0),
    "report_region_soundness": ("report", "report_region_overlap_macro", 1.0),
    "report_cause_recall": ("report", "report_cause_envelope_recall_macro", 1.0),
    "report_cause_precision": ("report", "report_cause_false_positive_count", 0),
}
EXPECTED_NON_GUARANTEES = {
    "not_a_claim_about_other_models_or_versions",
    "not_a_promise_that_a_future_nondeterministic_run_passes",
    "not_a_severity_scale_or_universal_importance_order",
    "not_full_svg_or_cross_profile_coverage",
    "report_metrics_are_not_agent_credit",
    "possible_cause_candidates_are_not_proven_unique_causes",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def nonempty_strings(value, field: str) -> None:
    require(isinstance(value, list) and value, f"{field} must be a nonempty array")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{field} must contain nonempty strings",
    )
    require(len(value) == len(set(value)), f"{field} must not contain duplicates")


def validate(root: Path, manifest: dict, observation_override: Path | None) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-terminal-agent-reliability-gate/1",
        "gate identity mismatch",
    )
    require(
        manifest.get("claim_scope") == "accepted_retained_observation_only",
        "claim scope mismatch",
    )

    observation_contract = manifest.get("observation")
    require(isinstance(observation_contract, dict), "observation contract missing")
    observation_path = observation_override or root / observation_contract.get("path", "")
    require(observation_path.is_dir(), f"observation directory not found: {observation_path}")
    require(
        digest(observation_path / "integrity.json")
        == observation_contract.get("integrity_manifest_sha256"),
        "accepted observation identity mismatch",
    )

    benchmark_dir = root / "evaluation/language-model-benchmark"
    sys.path.insert(0, str(benchmark_dir))
    from validate_observation import validate as validate_observation

    validate_observation(observation_path)
    profile = load_json(observation_path / "profile.json")
    metrics = load_json(observation_path / "metrics.json")
    gate = load_json(observation_path / "gate.json")
    require(
        metrics.get("case_count") == observation_contract.get("case_count") == 13,
        "accepted corpus case count mismatch",
    )
    expected_profile = observation_contract.get("profile")
    require(isinstance(expected_profile, dict) and expected_profile, "profile binding missing")
    for field, expected in expected_profile.items():
        require(profile.get(field) == expected, f"profile binding mismatch: {field}")

    obligations = manifest.get("obligations")
    require(isinstance(obligations, list), "obligations must be an array")
    by_id = {item.get("id"): item for item in obligations if isinstance(item, dict)}
    require(set(by_id) == set(EXPECTED_OBLIGATIONS), "obligation inventory mismatch")
    require(len(by_id) == len(obligations), "obligation IDs must be unique")
    aggregate = metrics.get("aggregate")
    require(isinstance(aggregate, dict), "aggregate metrics missing")
    gate_checks = {item.get("metric"): item for item in gate.get("checks", [])}
    for identifier, (layer, metric, target) in EXPECTED_OBLIGATIONS.items():
        item = by_id[identifier]
        require(item.get("layer") == layer, f"{identifier}: layer mismatch")
        require(item.get("metric") == metric, f"{identifier}: metric mismatch")
        require(item.get("operator") == "==", f"{identifier}: operator mismatch")
        require(item.get("target") == target, f"{identifier}: target mismatch")
        require(
            isinstance(item.get("claim_phrase"), str) and item["claim_phrase"],
            f"{identifier}: claim phrase missing",
        )
        evidence = item.get("evidence")
        nonempty_strings(evidence, f"{identifier}.evidence")
        for path in evidence:
            require((root / path).is_file(), f"{identifier}: missing evidence path {path}")
        require(aggregate.get(metric) == target, f"{identifier}: terminal target not met")
        check = gate_checks.get(metric)
        require(
            isinstance(check, dict) and check.get("passed") is True,
            f"{identifier}: accepted benchmark decision missing",
        )

    non_guarantees = manifest.get("required_non_guarantees")
    nonempty_strings(non_guarantees, "required_non_guarantees")
    require(set(non_guarantees) == EXPECTED_NON_GUARANTEES, "non-guarantee inventory mismatch")
    suite_commands = manifest.get("suite_commands")
    nonempty_strings(suite_commands, "suite_commands")
    for command in suite_commands:
        parts = command.split()
        require(
            len(parts) == 2 and parts[0] == "sh" and (root / parts[1]).is_file(),
            f"invalid suite command: {command}",
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate terminal text-only Agent reliability.")
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--observation", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent.parent
    try:
        manifest = load_json(args.manifest)
        require(isinstance(manifest, dict), "manifest must contain a JSON object")
        validate(root, manifest, args.observation)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print("Terminal text-only Agent reliability gate: passed")


if __name__ == "__main__":
    main()
