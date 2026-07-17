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
    decision["schema_version"] == "svgdiff-multi-renderer-profile-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_container_identity_format"]
    == "svgdiff-renderer-experiment-matrix/1",
    "container identity drifted",
)
require(
    decision["future_cell_identity_format"]
    == "svgdiff-renderer-experiment-cell/1",
    "cell identity drifted",
)

current = decision["current_structured_report"]
require(
    current
    == {
        "cell_count": 1,
        "single_comparison_profile": True,
        "single_renderer_identity": True,
        "changed": False,
    },
    "current single-profile report semantics changed",
)
require(
    set(decision["supported_future_questions"])
    == {
        "full_typed_target_by_profile_matrix",
        "same_profile_cross_target_conformance",
        "same_target_cross_profile_sensitivity",
    },
    "future question coverage is incomplete",
)
require(
    set(decision["cell_payload_kinds"])
    == {
        "canonical_structured_report",
        "external_render_observation",
        "unavailable",
    },
    "cell payload kinds drifted",
)
require(
    len(decision["required_cell_identity_groups"]) == 7,
    "cell identity groups are incomplete",
)

edges = {entry["kind"]: entry for entry in decision["edge_kinds"]}
require(
    set(edges)
    == {
        "confounded_diagonal",
        "profile_sensitivity",
        "renderer_conformance",
        "renderer_target_observation",
        "target_profile_interaction",
    },
    "edge classification is incomplete",
)
require(
    edges["profile_sensitivity"]["varied"] == ["semantic_profile"],
    "profile edge changes another axis",
)
require(
    edges["renderer_conformance"]["varied"] == ["engine_identity"],
    "conformance edge is not engine-only",
)
require(
    "material_non_engine_environment"
    in edges["renderer_conformance"]["held_constant"],
    "engine conformance omitted environment equivalence",
)
require(
    edges["renderer_target_observation"]["direct_attribution"]
    == "target_bundle_only",
    "target/environment confounding was hidden",
)
require(
    edges["confounded_diagonal"]["direct_attribution"] == "forbidden",
    "diagonal gained direct attribution",
)
require(
    edges["target_profile_interaction"]["direct_attribution"]
    == "interaction_only",
    "interaction gained a unique cause",
)
require(
    set(decision["edge_must_retain_relations"])
    == {
        "after_output_relation",
        "before_output_relation",
        "before_to_after_difference_outcome_relation",
    },
    "edge lost side or difference evidence",
)
mapping = decision["cross_cell_mapping"]
require(mapping["versioned_mapping_required"] is True, "versioned mapping disabled")
require(
    mapping["ambiguous_mapping_means_insufficient_evidence"] is True,
    "ambiguous cross-cell mapping gained a conclusion",
)
require(
    mapping["external_cells_map_only_available_output_evidence"] is True,
    "external cells gained unavailable semantic evidence",
)
for field in ["report_local_ids_are_global", "array_position_mapping_allowed"]:
    require(mapping[field] is False, f"unsafe cross-cell mapping enabled: {field}")
require(
    set(decision["agent_classifications"])
    == {
        "confounded",
        "insufficient_evidence",
        "invariant_across_required_cells",
        "profile_sensitive",
        "renderer_sensitive",
        "renderer_target_sensitive",
        "target_profile_interaction",
    },
    "Agent synthesis vocabulary is incomplete",
)
for field in [
    "invariance_requires_all_declared_required_cells",
    "missing_or_incomparable_cell_means_insufficient_evidence",
]:
    require(decision[field] is True, f"required safety rule disabled: {field}")
for field in [
    "external_cells_may_fabricate_semantic_layers",
    "majority_vote_allowed",
    "averaging_allowed",
    "preferred_renderer_truth_allowed",
    "diagonal_direct_attribution_allowed",
]:
    require(decision[field] is False, f"forbidden inference enabled: {field}")
for field in [
    "product_container_implemented",
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
                require(
                    "svgdiff-renderer-experiment-matrix" not in text,
                    f"future matrix leaked into {path.relative_to(ROOT)}",
                )
                require(
                    "svgdiff-renderer-experiment-cell" not in text,
                    f"future cell leaked into {path.relative_to(ROOT)}",
                )

print(
    "Multi-renderer decision: profile sensitivity and renderer conformance typed "
    "separately; matrices preserve edges, diagonals confounded, no majority truth"
)
