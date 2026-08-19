#!/usr/bin/env python3

import argparse
import copy
import difflib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MEASUREMENT_FIELDS = {
    "changed_pixel_fraction",
    "changed_pixels",
    "max_channel_delta",
    "premultiplied_rgba8_rmse",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate a renderer-conformance report against its platform policy."
    )
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument(
        "--baseline",
        type=Path,
        default=ROOT / "evaluation/renderer-conformance/baseline.v1.json",
    )
    parser.add_argument(
        "--variants",
        type=Path,
        default=ROOT / "evaluation/renderer-conformance/platform-variants.v1.json",
    )
    return parser.parse_args()


def load(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected a JSON object: {path}")
    return value


def case_index(report: dict, label: str) -> dict[str, dict]:
    cases = report.get("cases")
    if not isinstance(cases, list):
        raise ValueError(f"{label} cases are not an array")
    indexed = {
        case.get("id"): case
        for case in cases
        if isinstance(case, dict) and isinstance(case.get("id"), str)
    }
    if len(indexed) != len(cases):
        raise ValueError(f"{label} case IDs are missing or duplicated")
    return indexed


def validate_policy(baseline: dict, variants: dict) -> None:
    if variants.get("schema_version") != "svgdiff-renderer-conformance-platform-variants/1":
        raise ValueError("unsupported renderer conformance platform-variant schema")
    for field in ("conformance_profile_id", "fixture_source_set_sha256"):
        if variants.get(field) != baseline.get(field):
            raise ValueError(f"baseline and platform variants use different {field}")

    baseline_cases = case_index(baseline, "baseline")
    base_platform = baseline.get("browser_environment", {}).get("host_platform")
    platforms = variants.get("platforms")
    if not isinstance(base_platform, str) or not isinstance(platforms, dict):
        raise ValueError("renderer conformance platform policy is incomplete")
    if platforms.get(base_platform) != {"cases": {}}:
        raise ValueError("baseline host platform must have no measurement overrides")

    for platform_id, platform_policy in platforms.items():
        if not isinstance(platform_id, str) or not platform_id:
            raise ValueError("renderer conformance platform ID is invalid")
        if not isinstance(platform_policy, dict) or set(platform_policy) != {"cases"}:
            raise ValueError(f"invalid platform policy: {platform_id}")
        overrides = platform_policy["cases"]
        if not isinstance(overrides, dict):
            raise ValueError(f"platform case overrides are not an object: {platform_id}")
        for case_id, measurement_overrides in overrides.items():
            if case_id not in baseline_cases:
                raise ValueError(f"platform override names an unknown case: {case_id}")
            if (
                not isinstance(measurement_overrides, dict)
                or not measurement_overrides
                or not set(measurement_overrides) <= MEASUREMENT_FIELDS
            ):
                raise ValueError(f"invalid measurement override: {platform_id}/{case_id}")
            if all(
                baseline_cases[case_id].get(field) == value
                for field, value in measurement_overrides.items()
            ):
                raise ValueError(f"redundant measurement override: {platform_id}/{case_id}")


def expected_report(baseline: dict, variants: dict, platform_id: str) -> dict:
    platforms = variants["platforms"]
    if platform_id not in platforms:
        raise ValueError(f"unsupported renderer conformance host platform: {platform_id}")
    expected = copy.deepcopy(baseline)
    expected["browser_environment"]["host_platform"] = platform_id
    expected_cases = case_index(expected, "baseline")
    for case_id, overrides in platforms[platform_id]["cases"].items():
        expected_cases[case_id].update(overrides)
    return expected


def formatted(value: dict) -> list[str]:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").splitlines(keepends=True)


def main() -> None:
    args = parse_args()
    baseline = load(args.baseline)
    variants = load(args.variants)
    report = load(args.report)
    validate_policy(baseline, variants)
    case_index(report, "observed report")
    platform_id = report.get("browser_environment", {}).get("host_platform")
    if not isinstance(platform_id, str):
        raise ValueError("renderer conformance report lacks a host platform")
    expected = expected_report(baseline, variants, platform_id)
    if report != expected:
        difference = "".join(
            difflib.unified_diff(
                formatted(expected),
                formatted(report),
                fromfile=f"expected ({platform_id})",
                tofile="observed",
            )
        )
        raise ValueError(f"renderer conformance baseline differs:\n{difference}")
    print(f"Renderer conformance baseline: accepted for {platform_id}")


if __name__ == "__main__":
    main()
