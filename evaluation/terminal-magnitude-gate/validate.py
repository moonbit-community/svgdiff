#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


EXPECTED_DIMENSIONS = {
    "exact_parameter_scales",
    "transform_effect",
    "painted_boundary_geometry",
    "painted_alpha_coverage",
    "presence_footprint",
    "scene_raster",
    "intrinsic_raster",
    "perceptual_color",
    "perceptual_flip",
}
EXPECTED_RULES = {
    "no_visibility_boolean",
    "no_universal_cross_domain_scalar",
    "no_missing_as_measured_zero",
    "no_domain_ordering_as_raw_evidence",
    "no_impact_as_magnitude_authority",
    "no_raster_quantization_over_exact_parameter",
    "no_alpha_coverage_as_rgb_difference",
    "no_perceptual_metric_as_equality_or_severity",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def nonempty_strings(value, field: str) -> None:
    require(isinstance(value, list) and bool(value), f"{field} must be a nonempty array")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{field} must contain nonempty strings",
    )
    require(len(value) == len(set(value)), f"{field} must not contain duplicates")


def validate(root: Path, manifest: dict) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-terminal-magnitude-gate/1",
        "gate identity mismatch",
    )
    require(
        manifest.get("canonical_rule")
        == "preserve_named_raw_magnitude_dimensions_and_availability",
        "canonical rule mismatch",
    )
    rules = manifest.get("anti_collapse_rules")
    nonempty_strings(rules, "anti_collapse_rules")
    require(set(rules) == EXPECTED_RULES, "anti-collapse rule inventory mismatch")

    dimensions = manifest.get("dimensions")
    require(isinstance(dimensions, list), "dimensions must be an array")
    by_id = {item.get("id"): item for item in dimensions if isinstance(item, dict)}
    require(set(by_id) == EXPECTED_DIMENSIONS, "magnitude dimension inventory mismatch")
    require(len(by_id) == len(dimensions), "dimension IDs must be unique")
    for identifier, item in by_id.items():
        require(
            isinstance(item.get("availability_rule"), str) and item["availability_rule"],
            f"{identifier}: missing availability rule",
        )
        for field in ("fields", "units_or_denominators", "authorities", "tests"):
            values = item.get(field)
            nonempty_strings(values, f"{identifier}.{field}")
            if field in ("authorities", "tests"):
                for value in values:
                    require((root / value).is_file(), f"{identifier}: missing {field} path {value}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate the terminal magnitude manifest.")
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent.parent
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        require(isinstance(manifest, dict), "manifest must contain a JSON object")
        validate(root, manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print("Terminal magnitude manifest passed: 9 raw evidence dimensions retained")


if __name__ == "__main__":
    main()
