#!/usr/bin/env python3

import argparse
import json
import subprocess
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from evaluation.report_causes import report_differences
NEW_CONFORMANCE_CODES = {
    "renderer_fractional_geometry_unproven",
    "renderer_gradient_raster_unproven",
    "renderer_fractional_opacity_unproven",
    "renderer_transform_raster_unproven",
    "renderer_use_inherited_paint_raster_unproven",
    "renderer_curved_shape_raster_unproven",
    "renderer_point_shape_raster_unproven",
    "renderer_stroke_outline_raster_unproven",
    "renderer_stroke_join_raster_unproven",
    "renderer_stroke_dash_raster_unproven",
    "renderer_non_scaling_stroke_unproven",
    "renderer_marker_raster_unproven",
}

ADMITTED_CLIP_CASES = {
    "clip-path",
    "clip-object-bbox",
    "clip-transform",
    "clip-container",
}

ADMITTED_MASK_CASES = {
    "mask-alpha",
    "mask-luminance",
    "mask-object-bbox",
    "mask-container",
    "mask-mode-alpha",
    "mask-transform",
}

ADMITTED_FILTER_CASES = {
    "filter-offset-user-space",
    "filter-offset-object-bbox",
    "filter-offset-named-chain",
    "filter-offset-source-alpha",
}

ADMITTED_BLEND_CASES = {
    "blend-modes",
    "blend-modes-canonical",
    "blend-isolation-auto",
    "blend-isolation-auto-canonical",
    "blend-isolation-isolate",
    "blend-isolation-isolate-canonical",
    "blend-transparent-backdrop",
    "blend-transparent-backdrop-canonical",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate renderer divergence dispositions against the CLI."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument(
        "--baseline",
        type=Path,
        default=ROOT / "evaluation/renderer-conformance/baseline.v1.json",
    )
    parser.add_argument(
        "--dispositions",
        type=Path,
        default=ROOT / "evaluation/renderer-conformance/dispositions.v1.json",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "evaluation/browser-oracle/manifest.json",
    )
    return parser.parse_args()


def compare_pair(cli: Path, before: Path, after: Path) -> dict:
    result = subprocess.run(
        [str(cli), str(before), str(after), "--agent-json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or result.stderr:
        raise ValueError(
            f"CLI failed for {before} and {after}: "
            f"status={result.returncode}, stderr={result.stderr!r}"
        )
    return json.loads(result.stdout)


def compare_source(cli: Path, source: Path) -> dict:
    return compare_pair(cli, source, source)


def diagnostic_codes(report: dict) -> set[str]:
    return {diagnostic["code"] for diagnostic in report["limitations"]}


def renderer_components(cli: Path) -> set[str]:
    result = subprocess.run(
        [str(cli), "--version"],
        check=True,
        capture_output=True,
        text=True,
    )
    renderer_line = next(
        (line for line in result.stdout.splitlines() if line.startswith("renderer: ")),
        None,
    )
    if renderer_line is None:
        raise ValueError("CLI version output lacks renderer identity")
    return set(renderer_line.removeprefix("renderer: ").split("+"))


def main() -> None:
    args = parse_args()
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    dispositions = json.loads(args.dispositions.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    expected_profile = "svgdiff-renderer-conformance-profile/29"
    baseline_profile = baseline.get("conformance_profile_id")
    disposition_profile = dispositions.get("conformance_profile_id")
    if baseline_profile != expected_profile:
        raise ValueError("unsupported renderer conformance profile")
    if disposition_profile != baseline_profile:
        raise ValueError(
            "baseline and dispositions use different renderer conformance profiles"
        )
    fixtures = {fixture["id"]: fixture for fixture in manifest["fixtures"]}
    divergent = {
        case["id"] for case in baseline["cases"] if case["comparison"] == "divergent"
    }
    mappings = {case["id"]: case for case in dispositions["cases"]}
    if set(mappings) != divergent or len(mappings) != len(dispositions["cases"]):
        raise ValueError("divergent baseline cases and dispositions are not one-to-one")

    diagnostic_count = 0
    normalizer_count = 0
    compositor_count = 0
    components = renderer_components(args.cli)
    for case_id in sorted(divergent):
        mapping = mappings[case_id]
        disposition = mapping.get("disposition")
        if disposition == "normalizer":
            canonical_id = mapping.get("canonical_case_id")
            normalizer_id = mapping.get("normalizer_id")
            if canonical_id not in fixtures or not isinstance(normalizer_id, str):
                raise ValueError(f"invalid normalizer disposition for {case_id}")
            if fixtures[case_id].get("canonical_equivalent_id") != canonical_id:
                raise ValueError(f"manifest canonical fixture differs for {case_id}")
            canonical_baseline = next(
                (case for case in baseline["cases"] if case["id"] == canonical_id),
                None,
            )
            if (
                canonical_baseline is None
                or canonical_baseline["comparison"] != "exact"
                or canonical_baseline["coverage_claim"] != "supported"
            ):
                raise ValueError(f"canonical fixture is not exact and supported: {case_id}")
            source = (ROOT / fixtures[case_id]["source"]).resolve()
            canonical = (ROOT / fixtures[canonical_id]["source"]).resolve()
            report = compare_pair(args.cli, source, canonical)
            if report.get("analysis_status") != "complete":
                raise ValueError(f"normalizer comparison remained partial: {case_id}")
            component_id = normalizer_id.removeprefix("svgdiff/")
            if normalizer_id not in components and component_id not in components:
                raise ValueError(f"normalizer identity missing for {case_id}")
            differences = report_differences(report)
            if not differences or any(
                difference.get("effective", {}).get("relation") != "equivalent"
                for difference in differences
            ):
                raise ValueError(f"normalizer did not prove computed equivalence: {case_id}")
            events = report.get("events", [])
            if not events or any(
                event.get("outcome", {}).get("changed_pixels") != 0
                for event in events
            ):
                raise ValueError(f"normalizer changed production pixels: {case_id}")
            emitted = diagnostic_codes(report)
            if emitted & NEW_CONFORMANCE_CODES:
                raise ValueError(f"normalizer comparison acquired a guard: {case_id}")
            normalizer_count += 1
            continue
        if disposition == "compositor":
            compositor_id = mapping.get("compositor_id")
            before_path = mapping.get("validation_before")
            after_path = mapping.get("validation_after")
            if not all(isinstance(value, str) and value for value in (
                compositor_id,
                before_path,
                after_path,
            )):
                raise ValueError(f"invalid compositor disposition for {case_id}")
            source = (ROOT / fixtures[case_id]["source"]).resolve()
            self_report = compare_source(args.cli, source)
            if self_report.get("analysis_status") != "complete":
                raise ValueError(f"compositor source remained partial: {case_id}")
            component_id = compositor_id.removeprefix("svgdiff/")
            if compositor_id not in components and component_id not in components:
                raise ValueError(f"compositor identity missing for {case_id}")
            if any(
                diagnostic.get("code") == "group_opacity_compositing_unsupported"
                for diagnostic in self_report.get("limitations", [])
            ):
                raise ValueError(f"retired group opacity guard emitted: {case_id}")
            canonical_id = mapping.get("canonical_case_id")
            if canonical_id is not None:
                if canonical_id not in fixtures:
                    raise ValueError(f"invalid compositor canonical case: {case_id}")
                if fixtures[case_id].get("canonical_equivalent_id") != canonical_id:
                    raise ValueError(f"manifest canonical fixture differs for {case_id}")
                canonical_baseline = next(
                    (case for case in baseline["cases"] if case["id"] == canonical_id),
                    None,
                )
                if (
                    canonical_baseline is None
                    or canonical_baseline["comparison"] != "exact"
                    or canonical_baseline["coverage_claim"] != "supported"
                ):
                    raise ValueError(
                        f"compositor canonical fixture is not exact: {case_id}"
                    )
                canonical_report = compare_pair(
                    args.cli,
                    source,
                    (ROOT / fixtures[canonical_id]["source"]).resolve(),
                )
                canonical_events = canonical_report.get("events", [])
                if canonical_report.get("analysis_status") != "complete" or not canonical_events:
                    raise ValueError(
                        f"compositor canonical comparison remained partial: {case_id}"
                    )
                if any(
                    event.get("outcome", {}).get("status") != "computed"
                    or event.get("outcome", {}).get("changed_pixels") != 0
                    for event in canonical_events
                ):
                    raise ValueError(
                        f"compositor did not match canonical pixels: {case_id}"
                    )
            report = compare_pair(
                args.cli,
                (ROOT / before_path).resolve(),
                (ROOT / after_path).resolve(),
            )
            differences = [
                difference
                for difference in report_differences(report)
                if difference.get("kind")
                == mapping.get("validation_domain", "compositing.opacity")
            ]
            if report.get("analysis_status") != "complete" or len(differences) != 1:
                raise ValueError(f"compositor validation comparison failed: {case_id}")
            if not any(
                event.get("outcome", {}).get("status") == "computed"
                and event.get("outcome", {}).get("changed_pixels", 0) > 0
                for event in report.get("events", [])
                if differences[0]["id"] in event.get("difference_ids", [])
            ):
                raise ValueError(f"compositor produced no measured response: {case_id}")
            compositor_count += 1
            continue
        if disposition != "diagnostic":
            raise ValueError(f"unsupported disposition for {case_id}")
        code = mapping.get("diagnostic_code")
        if not isinstance(code, str) or not code:
            raise ValueError(f"missing diagnostic code for {case_id}")
        source = (ROOT / fixtures[case_id]["source"]).resolve()
        report = compare_source(args.cli, source)
        if report.get("analysis_status") != "partial":
            raise ValueError(f"divergent case remained complete: {case_id}")
        if code not in diagnostic_codes(report):
            raise ValueError(f"disposition diagnostic missing for {case_id}: {code}")
        diagnostic_count += 1

    exact_supported = [
        case
        for case in baseline["cases"]
        if case["comparison"] == "exact" and case["coverage_claim"] == "supported"
    ]
    for case in exact_supported:
        source = (ROOT / fixtures[case["id"]]["source"]).resolve()
        report = compare_source(args.cli, source)
        emitted = diagnostic_codes(report)
        unexpected = emitted & NEW_CONFORMANCE_CODES
        if unexpected:
            raise ValueError(
                f"exact supported case acquired a conformance guard: "
                f"{case['id']} {sorted(unexpected)}"
            )
        if case["id"] in ADMITTED_CLIP_CASES:
            clip_guards = sorted(code for code in emitted if code.startswith("clip_path_"))
            if report.get("analysis_status") != "complete" or clip_guards:
                raise ValueError(
                    f"admitted clip case lost complete coverage: "
                    f"{case['id']} {clip_guards}"
                )

    exact_clip_cases = {
        case["id"]
        for case in exact_supported
        if case["id"] in ADMITTED_CLIP_CASES
    }
    if exact_clip_cases != ADMITTED_CLIP_CASES:
        raise ValueError(
            f"admitted clip fixtures are not all exact and supported: "
            f"{sorted(ADMITTED_CLIP_CASES - exact_clip_cases)}"
        )

    admitted_mask_cases = {
        case["id"]
        for case in baseline["cases"]
        if case["coverage_claim"] == "supported"
        and case["id"] in ADMITTED_MASK_CASES
    }
    if admitted_mask_cases != ADMITTED_MASK_CASES:
        raise ValueError(
            f"admitted mask fixtures are not all supported: "
            f"{sorted(ADMITTED_MASK_CASES - admitted_mask_cases)}"
        )
    for case_id in sorted(ADMITTED_MASK_CASES):
        source = (ROOT / fixtures[case_id]["source"]).resolve()
        report = compare_source(args.cli, source)
        mask_guards = sorted(
            diagnostic["code"]
            for diagnostic in report.get("limitations", [])
            if diagnostic["code"].startswith("mask_")
        )
        if report.get("analysis_status") != "complete" or mask_guards:
            raise ValueError(
                f"admitted mask case lost complete coverage: "
                f"{case_id} {mask_guards}"
            )

    admitted_filter_cases = {
        case["id"]
        for case in baseline["cases"]
        if case["coverage_claim"] == "supported"
        and case["id"] in ADMITTED_FILTER_CASES
    }
    if admitted_filter_cases != ADMITTED_FILTER_CASES:
        raise ValueError(
            "admitted filter fixtures are not all supported: "
            f"{sorted(ADMITTED_FILTER_CASES - admitted_filter_cases)}"
        )
    for case_id in sorted(ADMITTED_FILTER_CASES):
        source = (ROOT / fixtures[case_id]["source"]).resolve()
        report = compare_source(args.cli, source)
        filter_guards = sorted(
            diagnostic["code"]
            for diagnostic in report.get("limitations", [])
            if diagnostic["code"].startswith("filter_")
        )
        if report.get("analysis_status") != "complete" or filter_guards:
            raise ValueError(
                f"admitted filter case lost complete coverage: "
                f"{case_id} {filter_guards}"
            )

    admitted_blend_cases = {
        case["id"]
        for case in baseline["cases"]
        if case["coverage_claim"] == "supported"
        and case["id"] in ADMITTED_BLEND_CASES
    }
    if admitted_blend_cases != ADMITTED_BLEND_CASES:
        raise ValueError(
            "admitted blend fixtures are not all supported: "
            f"{sorted(ADMITTED_BLEND_CASES - admitted_blend_cases)}"
        )
    for case_id in sorted(ADMITTED_BLEND_CASES):
        source = (ROOT / fixtures[case_id]["source"]).resolve()
        report = compare_source(args.cli, source)
        blend_guards = sorted(
            diagnostic["code"]
            for diagnostic in report.get("limitations", [])
            if diagnostic["code"].startswith(("blend_", "isolation_"))
        )
        if report.get("analysis_status") != "complete" or blend_guards:
            raise ValueError(
                f"admitted blend case lost complete coverage: "
                f"{case_id} {blend_guards}"
            )

    print(
        f"Renderer dispositions: {len(divergent)} divergences disposed "
        f"({diagnostic_count} diagnostic, {normalizer_count} normalizer, "
        f"{compositor_count} compositor), "
        f"{len(exact_supported)} exact supported cases retain their prior coverage"
    )


if __name__ == "__main__":
    main()
