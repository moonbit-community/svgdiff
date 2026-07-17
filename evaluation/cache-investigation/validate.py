#!/usr/bin/env python3

import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
ARTIFACT = ROOT / "candidates.v1.json"

EXPECTED_CANDIDATES = {
    "within_call_memoization": "accepted_when_measured",
    "local_exact_result": "future_first_candidate",
    "per_input_semantic_artifact": "deferred_pending_stable_intermediate_contract",
    "render_artifact": "deferred_pending_complete_render_identity",
    "pair_stage_artifact": "deferred_pending_dependency_proof",
    "graph_incremental_recompute": "deferred_pending_explicit_dependency_dag",
    "shared_remote_cache": "rejected_until_local_value_and_trust_model",
}

EXPECTED_KEY_GROUPS = {
    "key_and_artifact_protocols",
    "ordered_before_after_exact_source_bytes",
    "ordered_side_qualified_resource_inputs",
    "complete_comparison_profile",
    "semantic_engine_build_and_dependency_identities",
    "all_report_coverage_alignment_region_magnitude_provenance_and_impact_policy_identities",
    "all_adopted_execution_profile_identities",
    "effective_deterministic_resource_limits_and_control_mode",
    "target_toolchain_and_build_identity_when_cross_target_equality_is_unproven",
}

EXPECTED_INVARIANTS = {
    "cache_hit_never_upgrades_completeness_or_evidence_authority",
    "before_after_order_is_not_commutative",
    "cancelled_or_interrupted_calls_store_no_result",
    "unknown_incompatible_corrupt_or_oversized_entry_is_a_miss",
    "every_miss_or_validation_error_falls_back_to_full_recomputation",
    "stored_bytes_are_untrusted_and_digest_checked_before_report_use",
    "cache_deletion_is_always_semantically_safe",
    "no_svg_authored_path_or_network_reference_controls_cache_io",
    "operational_cache_telemetry_stays_outside_structured_report_semantics",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def unique_strings(values: object, label: str) -> list[str]:
    require(isinstance(values, list), f"{label} must be an array")
    require(all(isinstance(value, str) and value for value in values), f"bad {label}")
    require(len(values) == len(set(values)), f"duplicate {label}")
    return values


def validate(document: object) -> None:
    require(isinstance(document, dict), "artifact must be an object")
    require(document.get("schema_version") == "svgdiff-cache-investigation/1", "schema identity drifted")
    require(document.get("outcome") == "defer_persistent_product_cache", "outcome drifted")
    require(document.get("full_recomputation_is_correctness_reference") is True, "full recomputation lost authority")
    require(document.get("reserved_future_key_id") == "svgdiff-exact-result-cache-key/1", "future key identity drifted")
    require(document.get("future_first_candidate") == "local_exact_result", "future first candidate drifted")
    require(document.get("current_product_changes") is False, "investigation claims product changes")

    candidates = document.get("candidates")
    require(isinstance(candidates, list), "candidates must be an array")
    actual: dict[str, str] = {}
    for candidate in candidates:
        require(isinstance(candidate, dict), "candidate must be an object")
        candidate_id = candidate.get("id")
        disposition = candidate.get("disposition")
        reusable_unit = candidate.get("reusable_unit")
        require(isinstance(candidate_id, str) and candidate_id, "bad candidate id")
        require(candidate_id not in actual, "duplicate candidate id")
        require(isinstance(disposition, str) and disposition, "bad disposition")
        require(isinstance(reusable_unit, str) and reusable_unit, "bad reusable unit")
        actual[candidate_id] = disposition
    require(actual == EXPECTED_CANDIDATES, "candidate inventory or disposition drifted")

    key_groups = set(unique_strings(document.get("required_exact_result_key_groups"), "key groups"))
    require(key_groups == EXPECTED_KEY_GROUPS, "exact-result key is incomplete")
    invariants = set(unique_strings(document.get("required_safety_invariants"), "safety invariants"))
    require(invariants == EXPECTED_INVARIANTS, "cache safety invariants drifted")
    reconsideration = unique_strings(document.get("required_reconsideration_evidence"), "reconsideration evidence")
    require(len(reconsideration) >= 7, "reconsideration evidence is incomplete")


def negative_controls(document: dict) -> None:
    mutations: list[dict] = []

    missing_key = copy.deepcopy(document)
    missing_key["required_exact_result_key_groups"].remove("complete_comparison_profile")
    mutations.append(missing_key)

    incremental = copy.deepcopy(document)
    for candidate in incremental["candidates"]:
        if candidate["id"] == "graph_incremental_recompute":
            candidate["disposition"] = "accepted_now"
    mutations.append(incremental)

    remote = copy.deepcopy(document)
    for candidate in remote["candidates"]:
        if candidate["id"] == "shared_remote_cache":
            candidate["disposition"] = "future_first_candidate"
    mutations.append(remote)

    for index, mutation in enumerate(mutations):
        try:
            validate(mutation)
        except ValueError:
            continue
        raise AssertionError(f"negative control {index} was accepted")


def main() -> None:
    document = json.loads(ARTIFACT.read_text(encoding="utf-8"))
    validate(document)
    negative_controls(document)
    print("Cache investigation: 7 candidate shapes, 9 complete key groups, and safe deferral validated")


if __name__ == "__main__":
    main()
