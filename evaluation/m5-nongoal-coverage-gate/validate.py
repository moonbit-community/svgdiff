#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


EXPECTED_IDS = {
    "deterministic_font_runtime",
    "platform_native_fonts",
    "beyond_srgb_color",
    "multi_renderer_comparison",
    "script_execution",
    "interaction_state",
    "animation_timeline",
    "foreign_object_layout",
    "general_external_resources",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def nonempty_strings(value, field: str, *, allow_empty: bool = False) -> None:
    require(isinstance(value, list), f"{field} must be an array")
    require(all(isinstance(item, str) and item for item in value), f"{field} must contain nonempty strings")
    require(len(value) == len(set(value)), f"{field} must not contain duplicates")
    require(allow_empty or bool(value), f"{field} must not be empty")


def validate(root: Path, manifest: dict) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-m5-nongoal-coverage-gate/1",
        "gate identity mismatch",
    )
    require(
        manifest.get("canonical_rule")
        == "unsupported_or_unavailable_advanced_semantics_never_establish_complete_equality",
        "canonical rule mismatch",
    )
    capabilities = manifest.get("capabilities")
    require(isinstance(capabilities, list), "capabilities must be an array")
    by_id = {item.get("id"): item for item in capabilities if isinstance(item, dict)}
    require(set(by_id) == EXPECTED_IDS, "capability inventory mismatch")
    require(len(by_id) == len(capabilities), "capability IDs must be unique")

    for identifier, item in by_id.items():
        require(item.get("adopted") is False, f"{identifier}: capability unexpectedly adopted")
        for field in ("disposition", "authority", "document", "decision_artifact", "validation_command"):
            require(isinstance(item.get(field), str) and item[field], f"{identifier}: missing {field}")
        for field in ("document", "decision_artifact", "validation_command"):
            require((root / item[field]).is_file(), f"{identifier}: missing path {item[field]}")
        artifact = json.loads((root / item["decision_artifact"]).read_text(encoding="utf-8"))
        require(isinstance(artifact.get("schema_version"), str), f"{identifier}: decision artifact lacks identity")
        guards = item.get("product_guards")
        nonempty_strings(guards, f"{identifier}.product_guards", allow_empty=True)
        if not guards:
            require(
                isinstance(item.get("outside_input_reason"), str)
                and item["outside_input_reason"],
                f"{identifier}: empty guards need an outside-input reason",
            )
        nonempty_strings(item.get("future_identities"), f"{identifier}.future_identities")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate the M5 non-goal coverage manifest.")
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent.parent
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        validate(root, manifest)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print(f"M5 non-goal coverage manifest passed: {args.manifest}")


if __name__ == "__main__":
    main()
