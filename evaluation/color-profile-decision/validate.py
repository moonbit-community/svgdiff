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
    decision["schema_version"] == "svgdiff-color-profile-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_profile_identity_format"]
    == "svgdiff-color-execution-profile/1",
    "future profile identity drifted",
)
require(
    decision["external_observation_identity_format"]
    == "svgdiff-color-observation/1",
    "observation identity drifted",
)
require(
    set(decision["observation_roles"])
    == {"ambient_unreproducible", "closed_reference_observation"},
    "color observation roles drifted",
)

current = decision["current_product_profile"]
require(current["color_interpretation"] == "srgb", "current sRGB profile changed")
require(
    current["raster_representation"]
    == "linear_srgb_premultiplied_rgba_f64",
    "current raster representation changed",
)
require(current["changed"] is False, "decision claims a current product change")

require(
    set(decision["required_profile_layers"])
    == {
        "conversion_and_numeric_execution",
        "execution_identity_limits_and_conformance",
        "interpolation",
        "measurement",
        "reference_output_and_mapping",
        "source_admission_and_resources",
        "working_compositing_and_alpha",
    },
    "color profile layers are incomplete",
)

families = {entry["family"]: entry for entry in decision["families"]}
require(
    set(families)
    == {
        "ambient_platform_color_management",
        "arbitrary_icc_custom_and_non_rgb",
        "browser_os_and_physical_display_output",
        "css_color_4_predefined_sdr",
        "hdr_reference_space",
        "icc_v4_rgb_matrix_trc",
        "implicit_cross_profile_equality",
        "png_cicp_predefined_sdr",
    },
    "color family classification is incomplete",
)
require(
    families["css_color_4_predefined_sdr"]["status"]
    == "first_future_canonical_candidate_after_separate_gates",
    "predefined SDR is no longer the first candidate",
)
require(
    families["icc_v4_rgb_matrix_trc"]["status"].startswith(
        "deferred_canonical_candidate"
    ),
    "bounded ICC candidate drifted",
)
require(
    families["hdr_reference_space"]["status"] == "deferred_experimental_only",
    "HDR became canonical without its gates",
)
require(
    families["browser_os_and_physical_display_output"]["status"]
    == "external_observation_only",
    "physical output became canonical",
)
for family in [
    "ambient_platform_color_management",
    "implicit_cross_profile_equality",
]:
    require(
        families[family]["status"] == "permanent_non_goal",
        f"permanent boundary drifted: {family}",
    )
require(
    not any(entry["canonical_now"] for entry in families.values()),
    "decision introduced a current canonical profile",
)

forbidden = set(decision["canonical_forbidden_defaults"])
require(
    {
        "ambient_display_profile",
        "automatic_platform_cms",
        "device_dependent_tone_mapping",
        "implicit_cross_profile_comparison",
        "silent_retag_as_srgb",
        "silent_srgb_clipping",
    }
    <= forbidden,
    "an ambient or lossy default was admitted",
)

icc = decision["first_icc_candidate_constraints"]
require(
    icc
    == {
        "profile_version": "v4",
        "device_space": "rgb",
        "transform_shape": "matrix_trc",
        "rendering_intent": "media_relative_colorimetric",
        "black_point_compensation": "disabled",
        "exact_profile_bytes_required": True,
        "pinned_transform_implementation_required": True,
    },
    "first ICC candidate widened or became ambiguous",
)
require(len(decision["hdr_profile_must_close"]) == 9, "HDR inputs are incomplete")
require(
    decision["same_profile_required_for_before_after"] is True,
    "before and after may use different profiles",
)
require(
    decision["cross_profile_equality_forbidden"] is True,
    "cross-profile equality was admitted",
)
require(
    decision["external_observation_is_structured_report_evidence"] is False,
    "external pixels became canonical report evidence",
)

for field in [
    "color_dependency_selected",
    "product_conversion_implemented",
    "report_schema_change",
    "public_api_change",
    "module_dependency_change",
    "diagnostic_change",
    "default_ci_change",
]:
    require(decision[field] is False, f"unexpected current change: {field}")

for path in [ROOT / "modules/svgdiff/moon.mod", ROOT / "modules/svgdiff/moon.pkg"]:
    if path.exists():
        text = path.read_text(encoding="utf-8").lower()
        require("lcms" not in text, f"color dependency leaked into {path.name}")
        require("skcms" not in text, f"color dependency leaked into {path.name}")

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
                    "svgdiff-color-execution-profile" not in text,
                    f"future color profile leaked into {path.relative_to(ROOT)}",
                )
                require(
                    "svgdiff-color-observation" not in text,
                    f"color observation leaked into {path.relative_to(ROOT)}",
                )

print(
    "Color profile decision: current sRGB unchanged; predefined SDR first future "
    "candidate, ICC and HDR staged, ambient platform color permanently rejected"
)
