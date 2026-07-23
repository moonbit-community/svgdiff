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
    decision["schema_version"] == "svgdiff-interaction-state-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_profile_identity_format"]
    == "svgdiff-interaction-state-profile/1",
    "interaction profile identity drifted",
)
require(
    decision["future_observation_identity_format"]
    == "svgdiff-interaction-observation/1",
    "interaction observation identity drifted",
)
require(
    decision["future_scenario_identity_format"]
    == "svgdiff-interaction-scenario/1",
    "interaction scenario identity drifted",
)
require(
    decision["current_static_profile"]
    == {
        "interaction_state": "none",
        "pseudo_class_matching": False,
        "event_dispatch": False,
        "script_execution": False,
        "animation_execution": False,
        "changed": False,
    },
    "current static profile changed",
)
require(
    decision["canonical_input_kind"] == "typed_checkpoint_seeds",
    "canonical state stopped using typed seeds",
)
require(
    set(decision["cross_side_checkpoint_modes"])
    == {"coordinate_locked", "mapped_subject_locked"},
    "cross-side checkpoint questions were conflated",
)
require(
    len(decision["required_checkpoint_input_groups"]) == 6,
    "checkpoint identity is incomplete",
)
require(
    set(decision["derived_candidate_pseudo_classes"])
    == {"active", "focus", "focus-visible", "focus-within", "hover", "target"},
    "candidate pseudo-class boundary drifted",
)
require(
    decision["structural_pseudo_classes_belong_to_static_selector_work"] is True,
    "static selector work was mixed into interaction state",
)
require(
    decision["visited_is_canonical_non_goal"] is True,
    "visited history entered canonical state",
)
require(
    set(decision["canonical_outcomes"])
    == {
        "hit_test_unavailable",
        "insufficient_evidence",
        "invalid_profile",
        "pseudo_class_unsupported",
        "resolved",
        "state_incomparable",
        "state_resolution_limit_exceeded",
        "state_unstable",
        "target_unavailable",
    },
    "canonical outcome vocabulary drifted",
)
require(
    decision["observation_must_record_achieved_state_postconditions"] is True,
    "action observations lost achieved-state validation",
)
require(
    set(decision["observation_failure_outcomes"])
    == {
        "ambient_unreproducible",
        "failed",
        "replay_diverged",
        "state_not_reached",
        "unavailable",
    },
    "observation failure vocabulary drifted",
)
for field in [
    "caller_supplied_match_booleans_allowed",
    "action_trace_is_canonical_state",
    "missing_target_means_empty_state",
    "failed_replay_means_selector_non_match",
    "external_observation_may_fabricate_semantic_layers",
]:
    require(decision[field] is False, f"unsafe state inference enabled: {field}")
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

for directory in [
    ROOT / "modules" / "svgdiff" / "engine",
    ROOT / "schema",
    ROOT / "modules" / "svgdiff" / "cmd",
    ROOT / ".github",
]:
    if directory.exists():
        for path in directory.rglob("*"):
            if path.is_file():
                text = path.read_text(encoding="utf-8", errors="ignore").lower()
                for identity in [
                    "svgdiff-interaction-state-profile",
                    "svgdiff-interaction-observation",
                    "svgdiff-interaction-scenario",
                ]:
                    require(
                        identity not in text,
                        f"future interaction identity leaked into {path.relative_to(ROOT)}",
                    )

print(
    "Interaction decision: typed checkpoint seeds derive canonical state; browser "
    "actions remain observations and must prove achieved postconditions"
)
