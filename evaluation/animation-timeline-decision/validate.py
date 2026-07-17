#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


decision = json.loads((HERE / "decision.v1.json").read_text(encoding="utf-8"))
require(
    decision["future_checkpoint_set_identity_format"]
    == "svgdiff-animation-checkpoint-set/1",
    "animation checkpoint-set identity drifted",
)
require(
    decision["schema_version"] == "svgdiff-animation-timeline-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_profile_identity_format"]
    == "svgdiff-animation-timeline-profile/1",
    "animation timeline profile identity drifted",
)
require(
    decision["future_observation_identity_format"]
    == "svgdiff-animation-observation/1",
    "animation observation identity drifted",
)
require(
    decision["current_static_profile"]
    == {
        "timeline": "none",
        "animation_execution": False,
        "transition_execution": False,
        "event_dispatch": False,
        "script_execution": False,
        "interaction": False,
        "changed": False,
    },
    "current static profile changed",
)
require(
    decision["canonical_time_representation"]
    == "signed_rational_logical_time",
    "canonical logical time representation drifted",
)
require(
    decision["default_cross_side_synchronization"] == "document_time_locked",
    "document-time synchronization stopped being the default",
)
require(
    set(decision["synchronization_modes"])
    == {
        "document_time_locked",
        "logical_event_locked",
        "effect_phase_locked_diagnostic",
        "external_frame_locked_observation",
    },
    "timeline synchronization questions were conflated",
)
require(
    decision["boundary_inventory_policy"]
    == "union_with_side_and_mechanism_provenance",
    "one-sided timing boundaries may be discarded",
)
require(len(decision["required_identity_groups"]) == 7, "timeline identity is incomplete")
require(
    set(decision["checkpoint_kinds"])
    == {"point", "finite_point_set", "boundary_event_set", "continuous_interval"},
    "checkpoint questions were conflated",
)
for field in [
    "wall_time_is_document_time",
    "disabled_animation_is_time_zero",
    "raf_count_is_time_coordinate",
    "normalized_progress_is_timeline_synchronization",
    "finite_samples_may_prove_interval_equality",
    "unresolved_time_means_zero",
    "missing_effect_means_no_difference",
    "external_observation_may_fabricate_semantic_layers",
]:
    require(decision[field] is False, f"unsafe temporal inference enabled: {field}")
for field in [
    "finite_samples_may_witness_interval_difference",
    "interval_equality_requires_complete_analytic_event_partition_proof",
    "mechanism_specific_state_preserved",
    "css_transition_requires_style_change_history",
]:
    require(decision[field] is True, f"required temporal distinction lost: {field}")
require(
    set(decision["preserved_state_classes"])
    == {
        "ambient",
        "cancelled",
        "finished",
        "idle",
        "indefinite_or_infinite",
        "inactive",
        "limit_exceeded",
        "nonterminating_processing",
        "paused",
        "pending",
        "replay_divergent",
        "running",
        "unsupported",
        "unresolved",
    },
    "temporal state classes were collapsed",
)
require(
    set(decision["canonical_outcomes"])
    == {
        "checkpoint_mapping_unavailable",
        "dependency_limit_exceeded",
        "effect_inventory_incomparable",
        "insufficient_evidence",
        "interval_proof_unavailable",
        "invalid_profile",
        "mechanism_unsupported",
        "nonterminating_processing",
        "resolved",
        "resource_unavailable",
        "sampling_limit_exceeded",
        "time_unresolved",
        "timeline_inactive",
        "trigger_unresolved",
    },
    "canonical outcome vocabulary drifted",
)
require(
    set(decision["observation_failure_outcomes"])
    == {
        "ambient_unreproducible",
        "failed",
        "replay_diverged",
        "requested_time_not_reached",
        "state_not_reached",
        "unavailable",
    },
    "observation failure vocabulary drifted",
)
for field in [
    "product_profile_implemented",
    "report_schema_change",
    "public_api_change",
    "module_dependency_change",
    "diagnostic_change",
    "fixture_change",
    "default_ci_change",
]:
    require(decision[field] is False, f"unexpected current change: {field}")

for directory in [ROOT / "engine", ROOT / "schema", ROOT / "cmd", ROOT / ".github"]:
    if directory.exists():
        for path in directory.rglob("*"):
            if path.is_file():
                text = path.read_text(encoding="utf-8", errors="ignore").lower()
                for identity in [
                    "svgdiff-animation-timeline-profile",
                    "svgdiff-animation-checkpoint-set",
                    "svgdiff-animation-observation",
                ]:
                    require(
                        identity not in text,
                        f"future animation identity leaked into {path.relative_to(ROOT)}",
                    )

print(
    "Animation timeline decision: exact shared document-time checkpoints preserve timing "
    "differences; finite samples never prove interval equality"
)
