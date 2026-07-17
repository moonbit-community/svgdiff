#!/usr/bin/env python3
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


manifest = json.loads((HERE / "manifest.v1.json").read_text(encoding="utf-8"))
results = json.loads((HERE / "results.v1.json").read_text(encoding="utf-8"))

require(
    manifest["schema_version"] == "svgdiff-font-runtime-selection-input/1",
    "unexpected selection manifest version",
)
require(
    results["schema_version"] == "svgdiff-font-runtime-selection-result/1",
    "unexpected selection result version",
)
require(manifest["decision_status"] == "accepted_not_implemented", "bad decision")
require(manifest["product_integration"] is False, "decision became product behavior")
require(results["product_acceptance"] is False, "probe became product acceptance")
require(
    manifest["ownership"]
    == {
        "kind": "separately_versioned_workspace_module",
        "path": "modules/font_runtime",
        "module": "Milky2018/svgdiff-font-runtime",
        "upstream_types_public": False,
        "copies_verified_input_bytes": True,
        "copies_all_outputs": True,
    },
    "runtime ownership boundary drifted",
)

sources = {source["component"]: source for source in manifest["sources"]}
require(set(sources) == {"harfbuzz", "freetype"}, "unexpected source set")
require(sources["harfbuzz"]["version"] == "14.2.1", "HarfBuzz version drift")
require(sources["freetype"]["version"] == "2.14.3", "FreeType version drift")
for source in sources.values():
    require(SHA256.fullmatch(source["archive_sha256"]) is not None, "bad archive hash")
    require(
        re.fullmatch(r"[0-9a-f]{40}", source["peeled_commit"]) is not None,
        "bad peeled commit",
    )

hb_disabled = set(manifest["harfbuzz_build"]["disabled_meson_features"])
require(
    {
        "coretext",
        "directwrite",
        "freetype",
        "glib",
        "graphite2",
        "harfrust",
        "icu",
        "raster",
        "subset",
        "wasm",
    }
    <= hb_disabled,
    "ambient or optional HarfBuzz feature was admitted",
)
require(manifest["harfbuzz_build"]["default_library"] == "static", "HarfBuzz not static")
require(manifest["freetype_build"]["shared_libraries"] is False, "FreeType not static")
require(
    set(manifest["initial_slice"]["containers"])
    == {"opentype_sfnt", "opentype_collection"},
    "initial container slice drifted",
)
require(
    set(manifest["initial_slice"]["outlines"]) == {"glyf_static", "cff1_static"},
    "initial outline slice drifted",
)
require(manifest["initial_slice"]["shaper"] == "ot", "shaper is not explicit")
require(
    manifest["initial_slice"]["shaping_font_callbacks"] == "hb_ot_font",
    "FreeType leaked into shaping",
)
gated = set(manifest["initial_slice"]["gated"])
require(
    {
        "cff2_and_variable_fonts",
        "color_glyphs",
        "hinting_bytecode",
        "lcd_and_subpixel",
        "platform_backends",
        "svg_glyphs",
        "woff1_and_woff2",
    }
    <= gated,
    "required initial feature gate is missing",
)

verified = {item["component"]: item["sha256"] for item in results["verified_archives"]}
require(
    verified == {name: source["archive_sha256"] for name, source in sources.items()},
    "probe archive identity differs from selection",
)
for artifact in results["build_artifacts"]:
    require(artifact["kind"] == "static_archive", "probe artifact was not static")
    require(artifact["byte_length"] > 0, "empty probe artifact")
    require(SHA256.fullmatch(artifact["sha256"]) is not None, "bad artifact hash")

require(results["probe_sources"]["uses_hb_ft"] is False, "probe used hb-ft")
require(
    results["probe_sources"]["uses_path_font_api"] is False,
    "probe used a path font API",
)
require(len(results["observations"]) == 2, "unexpected probe observation count")
for observation in results["observations"]:
    packed = observation["packed_result"]
    require(packed >> 24 == observation["glyph_count"], "glyph count packing drift")
    require(
        (packed >> 8) & 0xFFFF == observation["first_glyph_outline_points"],
        "outline point packing drift",
    )
    require(packed & 0xFF == observation["pixel_mode_value"], "pixel mode packing drift")
    require(observation["pixel_mode"] == "FT_PIXEL_MODE_GRAY", "non-gray result")
require(
    {item["face_index"] for item in results["observations"]} == {0, 1},
    "single-face and collection-face coverage is missing",
)
require(
    all(
        "harfbuzz" not in dependency.lower() and "freetype" not in dependency.lower()
        for dependency in results["linked_dynamic_dependencies"]
    ),
    "probe resolved a dynamic font dependency",
)
require(
    "product_runtime_acceptance" in results["not_established"]
    and "cross_target_pixel_equality" in results["not_established"],
    "probe limitations were weakened",
)

require(
    not (ROOT / "prototype" / "font-runtime-probe").exists(),
    "throwaway font runtime probe was not removed",
)
for path in [ROOT / "moon.mod", ROOT / "moon.pkg"]:
    if path.exists():
        text = path.read_text(encoding="utf-8")
        require("svgdiff-font-runtime" not in text, f"runtime dependency leaked into {path.name}")
for directory in [ROOT / "engine", ROOT / "schema", ROOT / "cmd", ROOT / ".github"]:
    if directory.exists():
        for path in directory.rglob("*"):
            if path.is_file():
                text = path.read_text(encoding="utf-8", errors="ignore").lower()
                require("harfbuzz" not in text, f"HarfBuzz leaked into {path.relative_to(ROOT)}")
                require("freetype" not in text, f"FreeType leaked into {path.relative_to(ROOT)}")

print(
    "Font runtime selection: HarfBuzz 14.2.1 + FreeType 2.14.3 static "
    "MoonBit FFI feasible; product runtime and conformance remain unimplemented"
)
