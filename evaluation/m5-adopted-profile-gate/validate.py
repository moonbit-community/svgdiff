#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


EXPECTED_IDS = {
    "platform_native_fonts",
    "beyond_srgb_color",
    "multi_renderer_comparison",
    "script_execution",
    "interaction_state",
    "animation_timeline",
    "foreign_object_layout",
}
PROFILE_INSTANCE_FIELDS = {
    "profile_identity",
    "profile_manifest_sha256",
    "profile_version",
}
ENVIRONMENT_INSTANCE_FIELDS = {
    "environment_identity",
    "implementation_build_ids",
    "limits_profile_identity",
    "resource_manifest_sha256",
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


def meaningful_requirement(value, field: str) -> None:
    require(isinstance(value, (list, dict)) and bool(value), f"{field} must be nonempty")


def validate_instance(value, required_fields: set[str], field: str) -> None:
    require(isinstance(value, dict), f"{field} must be an object")
    require(set(value) == required_fields, f"{field} fields mismatch")
    for key, item in value.items():
        if key == "implementation_build_ids":
            nonempty_strings(item, f"{field}.{key}")
        else:
            require(isinstance(item, str) and item, f"{field}.{key} must be nonempty")


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"{path} must contain a JSON object")
    return value


def validate(root: Path, manifest: dict, adoption_source_path: Path) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-m5-adopted-profile-gate/1",
        "gate identity mismatch",
    )
    require(
        manifest.get("canonical_rule")
        == "adoption_requires_implementation_concrete_profile_and_pinned_environment",
        "canonical rule mismatch",
    )
    require(
        set(manifest.get("adopted_profile_instance_required_fields", []))
        == PROFILE_INSTANCE_FIELDS,
        "profile instance contract mismatch",
    )
    require(
        set(manifest.get("pinned_environment_instance_required_fields", []))
        == ENVIRONMENT_INSTANCE_FIELDS,
        "environment instance contract mismatch",
    )

    adoption_source = load_json(adoption_source_path)
    require(
        adoption_source.get("schema_version") == "svgdiff-m5-nongoal-coverage-gate/1",
        "adoption source identity mismatch",
    )
    source_items = adoption_source.get("capabilities")
    require(isinstance(source_items, list), "adoption source capabilities must be an array")
    source_by_id = {
        item.get("id"): item for item in source_items if isinstance(item, dict)
    }

    capabilities = manifest.get("capabilities")
    require(isinstance(capabilities, list), "capabilities must be an array")
    by_id = {item.get("id"): item for item in capabilities if isinstance(item, dict)}
    require(set(by_id) == EXPECTED_IDS, "advanced capability inventory mismatch")
    require(len(by_id) == len(capabilities), "capability IDs must be unique")

    adopted = []
    for identifier, item in by_id.items():
        source_id = item.get("source_capability_id")
        require(source_id == identifier, f"{identifier}: source capability mismatch")
        require(source_id in source_by_id, f"{identifier}: source capability missing")
        status = item.get("adoption_status")
        require(status in ("not_adopted", "adopted"), f"{identifier}: invalid adoption status")
        for field in ("decision_artifact", "implementation_flag"):
            require(isinstance(item.get(field), str) and item[field], f"{identifier}: missing {field}")
        artifact_path = root / item["decision_artifact"]
        require(artifact_path.is_file(), f"{identifier}: decision artifact missing")
        artifact = load_json(artifact_path)
        implementation = artifact.get(item["implementation_flag"])
        require(isinstance(implementation, bool), f"{identifier}: implementation flag missing")

        identity_fields = item.get("profile_identity_fields")
        environment_fields = item.get("environment_requirement_fields")
        nonempty_strings(identity_fields, f"{identifier}.profile_identity_fields")
        nonempty_strings(environment_fields, f"{identifier}.environment_requirement_fields")
        for field in identity_fields:
            require(
                isinstance(artifact.get(field), str) and artifact[field],
                f"{identifier}: identity field {field} missing",
            )
        for field in environment_fields:
            meaningful_requirement(
                artifact.get(field),
                f"{identifier}: environment requirement {field}",
            )

        source_adopted = source_by_id[source_id].get("adopted")
        require(isinstance(source_adopted, bool), f"{identifier}: source adoption flag missing")
        if status == "adopted":
            adopted.append(identifier)
            require(source_adopted, f"{identifier}: adoption source is stale")
            require(implementation, f"{identifier}: product implementation is absent")
            validate_instance(
                item.get("adopted_profile_instance"),
                PROFILE_INSTANCE_FIELDS,
                f"{identifier}.adopted_profile_instance",
            )
            validate_instance(
                item.get("pinned_environment_instance"),
                ENVIRONMENT_INSTANCE_FIELDS,
                f"{identifier}.pinned_environment_instance",
            )
        else:
            require(not source_adopted, f"{identifier}: adoption source is stale")
            require(not implementation, f"{identifier}: implementation lacks adoption review")
            require(
                item.get("adopted_profile_instance") is None,
                f"{identifier}: unadopted capability has a profile instance",
            )
            require(
                item.get("pinned_environment_instance") is None,
                f"{identifier}: unadopted capability has an environment instance",
            )

    current = manifest.get("current_adopted_capabilities")
    require(isinstance(current, list), "current adopted capabilities must be an array")
    require(current == sorted(adopted), "current adopted capability set mismatch")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate the M5 adopted-profile gate.")
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--adoption-source", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent.parent
    try:
        manifest = load_json(args.manifest)
        source_path = args.adoption_source
        if source_path is None:
            source = manifest.get("adoption_source")
            require(isinstance(source, str) and source, "missing adoption source")
            source_path = root / source
        validate(root, manifest, source_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print("M5 adopted-profile gate passed: adopted capability set is empty")


if __name__ == "__main__":
    main()
