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
    decision["schema_version"] == "svgdiff-foreign-content-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_profile_identity_format"]
    == "svgdiff-foreign-object-layout-profile/1",
    "foreign-content profile identity drifted",
)
require(
    decision["initial_slice_identity_format"]
    == "svgdiff-foreign-object-xhtml-rect-slice/1",
    "foreign-content initial slice identity drifted",
)
require(
    decision["future_observation_identity_format"]
    == "svgdiff-foreign-object-observation/1",
    "foreign-content observation identity drifted",
)
require(
    decision["current_static_profile"]
    == {
        "foreign_content_layout": False,
        "html_parser": False,
        "script_execution": False,
        "interaction": False,
        "animation_execution": False,
        "implicit_external_acquisition": False,
        "changed": False,
    },
    "current static profile changed",
)
require(
    decision["general_static_xhtml_requires_deterministic_host_language_engine"]
    is True,
    "general foreign content no longer requires a host-language engine",
)
for field in [
    "closed_subset_may_use_smaller_project_owned_evaluator",
    "initial_subset_selected",
]:
    require(decision[field] is True, f"bounded implementation seam lost: {field}")
for field in [
    "engine_must_be_complete_browser",
    "engine_must_run_in_comparison_process",
    "closed_subset_implies_general_html_css_support",
    "current_xml_input_uses_html_tree_builder",
    "unknown_namespace_is_xhtml",
    "unknown_namespace_is_empty_content",
    "outer_rectangle_establishes_content_semantics",
    "browser_pixels_establish_canonical_semantic_layers",
    "missing_or_unsupported_means_empty",
    "external_observation_may_fabricate_semantic_layers",
]:
    require(decision[field] is False, f"unsafe foreign-content inference enabled: {field}")
require(
    len(decision["initial_slice_constraints"]) == 7,
    "foreign-content initial slice is incomplete",
)
require(
    len(decision["required_profile_identity_groups"]) == 9,
    "foreign-content profile identity is incomplete",
)
require(
    set(decision["separate_evidence_layers"])
    == {
        "authored_foreign_markup",
        "computed_style_and_dependencies",
        "box_line_glyph_and_replaced_content_layout",
        "isolated_foreign_surface",
        "final_svg_compositing",
        "coverage_alignment_and_causal_provenance",
    },
    "foreign-content evidence layers were collapsed",
)
require(
    set(decision["canonical_outcomes"])
    == {
        "css_feature_unsupported",
        "dynamic_state_unsupported",
        "evaluator_conformance_divergent",
        "font_unavailable",
        "foreign_markup_invalid",
        "foreign_namespace_unsupported",
        "host_language_feature_unsupported",
        "insufficient_evidence",
        "invalid_profile",
        "layout_limit_exceeded",
        "layout_unavailable",
        "platform_widget_unsupported",
        "privacy_sensitive_state_unsupported",
        "renderer_conformance_unavailable",
        "resolved",
        "resource_unavailable",
        "svg_integration_unsupported",
    },
    "canonical foreign-content outcomes drifted",
)
require(
    set(decision["observation_failure_outcomes"])
    == {"ambient_unreproducible", "failed", "replay_diverged", "unavailable"},
    "foreign-content observation failures drifted",
)
for field in [
    "dependency_selected",
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
                    "svgdiff-foreign-object-layout-profile",
                    "svgdiff-foreign-object-xhtml-rect-slice",
                    "svgdiff-foreign-object-observation",
                ]:
                    require(
                        identity not in text,
                        f"future foreign-content identity leaked into {path.relative_to(ROOT)}",
                    )

print(
    "Foreign content decision: general canonical XHTML requires a deterministic "
    "host-language engine; closed evaluators remain bounded subsets"
)
