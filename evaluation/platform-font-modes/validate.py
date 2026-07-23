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
    decision["schema_version"] == "svgdiff-platform-font-mode-decision/1",
    "unexpected decision version",
)
require(
    decision["observation_identity_format"] == "svgdiff-platform-font-observation/1",
    "observation identity drifted",
)

modes = {entry["mode"]: entry for entry in decision["classifications"]}
require(
    set(modes)
    == {
        "project_runtime_closed_bundle",
        "platform_native_closed_bundle",
        "browser_closed_bundle",
        "platform_or_browser_ambient_fonts",
        "platform_native_canonical_execution",
    },
    "mode classification is incomplete",
)
require(
    modes["platform_native_canonical_execution"]["status"] == "permanent_non_goal",
    "platform-native execution became canonical",
)
require(
    modes["platform_native_closed_bundle"]["status"]
    == "conditionally_permitted_external_observation",
    "closed-bundle platform role drifted",
)
require(
    modes["platform_or_browser_ambient_fonts"]["status"]
    == "ambient_unreproducible",
    "ambient fonts received a reproducible claim",
)
require(
    all(entry["structured_report_evidence"] is False for entry in modes.values()),
    "external mode became Structured Report evidence",
)

forbidden_inputs = set(decision["canonical_forbidden_inputs"])
require(
    {
        "generic_families",
        "local_font_sources",
        "network_font_services",
        "platform_fallback",
        "system_font_discovery",
    }
    <= forbidden_inputs,
    "ambient canonical input was admitted",
)
forbidden_claims = set(decision["canonical_claims_forbidden"])
require(
    {
        "causal_completeness",
        "complete_analysis",
        "difference_magnitude",
        "structured_report_evidence",
        "visual_equality",
    }
    <= forbidden_claims,
    "platform observation gained a canonical claim",
)
require(
    len(decision["required_observation_identity_groups"]) == 7,
    "observation identity groups are incomplete",
)
require(
    decision["conformance_effect_requires_separate_review"] is True,
    "observation bypassed conformance review",
)
require(
    decision["multi_renderer_semantics_still_open"] is True,
    "this decision preempted multi-renderer semantics",
)
for field in [
    "product_backend_implemented",
    "report_schema_change",
    "public_api_change",
    "module_dependency_change",
    "default_ci_change",
]:
    require(decision[field] is False, f"unexpected current product change: {field}")

for path in [ROOT / "modules/svgdiff/moon.mod", ROOT / "modules/svgdiff/moon.pkg"]:
    if path.exists():
        text = path.read_text(encoding="utf-8").lower()
        require("coretext" not in text, f"CoreText dependency leaked into {path.name}")
        require("directwrite" not in text, f"DirectWrite dependency leaked into {path.name}")
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
                require("platform-font-observation" not in text, f"observation leaked into {path.relative_to(ROOT)}")
                require("coretext" not in text, f"CoreText backend leaked into {path.relative_to(ROOT)}")
                require("directwrite" not in text, f"DirectWrite backend leaked into {path.relative_to(ROOT)}")

print(
    "Platform font modes: canonical native execution permanently rejected; "
    "closed-bundle observations external, ambient captures exploratory only"
)
