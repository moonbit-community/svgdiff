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
    decision["schema_version"] == "svgdiff-script-runtime-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_observation_identity_format"] == "svgdiff-script-observation/1",
    "observation identity drifted",
)
require(
    decision["current_canonical_profile"]
    == {
        "processing_mode": "secure_static",
        "script_execution": False,
        "event_dispatch": False,
        "animation_execution": False,
        "interaction": False,
        "implicit_external_acquisition": False,
        "changed": False,
    },
    "current secure-static profile changed",
)
require(
    decision["canonical_script_execution"] == "permanent_non_goal",
    "canonical script execution became admissible",
)
require(
    decision["external_script_observation"] == "deferred_candidate",
    "external observation boundary drifted",
)
require(
    len(decision["required_observation_identity_groups"]) == 8,
    "external observation identity is incomplete",
)
require(
    set(decision["observation_classes"])
    == {
        "ambient_unreproducible",
        "closed_replayable_observation",
        "failed",
        "unavailable",
    },
    "observation classifications drifted",
)
require(
    decision["closed_observation_requires_byte_identical_repetition"] is True,
    "closed observations lost repeatability",
)
for field in [
    "sandbox_security_implies_determinism",
    "pinned_browser_implies_closed_state",
    "identical_script_bytes_imply_visual_equality",
    "disabled_script_effects_imply_visual_equality",
    "external_observation_may_establish_canonical_completeness",
    "missing_or_failed_side_means_zero",
    "external_observation_may_fabricate_semantic_layers",
]:
    require(decision[field] is False, f"forbidden script inference enabled: {field}")
require(
    len(decision["canonical_reconsideration_requires"]) == 6,
    "canonical reconsideration gate is incomplete",
)
for field in [
    "product_runtime_implemented",
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
                require(
                    "svgdiff-script-observation" not in text,
                    f"future script observation leaked into {path.relative_to(ROOT)}",
                )

print(
    "Script runtime decision: canonical secure-static execution remains script-free; "
    "sandbox is not determinism; future script output is external observation only"
)
