#!/usr/bin/env python3

import argparse
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
NEW_CONFORMANCE_CODES = {
    "renderer_fractional_geometry_unproven",
    "renderer_gradient_raster_unproven",
    "renderer_fractional_opacity_unproven",
    "renderer_transform_raster_unproven",
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


def compare_source(cli: Path, source: Path) -> dict:
    result = subprocess.run(
        [str(cli), str(source), str(source), "--agent-json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0 or result.stderr:
        raise ValueError(
            f"CLI failed for {source}: status={result.returncode}, stderr={result.stderr!r}"
        )
    return json.loads(result.stdout)


def main() -> None:
    args = parse_args()
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    dispositions = json.loads(args.dispositions.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    expected_profile = "svgdiff-renderer-conformance-profile/3"
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

    for case_id in sorted(divergent):
        mapping = mappings[case_id]
        if mapping.get("disposition") != "diagnostic":
            raise ValueError(f"unsupported disposition for {case_id}")
        code = mapping.get("diagnostic_code")
        if not isinstance(code, str) or not code:
            raise ValueError(f"missing diagnostic code for {case_id}")
        source = (ROOT / fixtures[case_id]["source"]).resolve()
        report = compare_source(args.cli, source)
        if report.get("analysis_status") != "partial":
            raise ValueError(f"divergent case remained complete: {case_id}")
        if code not in {diagnostic["code"] for diagnostic in report["diagnostics"]}:
            raise ValueError(f"disposition diagnostic missing for {case_id}: {code}")
        if not any(
            row["feature_id"] == f"guard.{code}"
            and row["rendered_evidence"] == "limited"
            for row in report["coverage_matrix"]
        ):
            raise ValueError(f"rendered guard coverage missing for {case_id}: {code}")

    exact_supported = [
        case
        for case in baseline["cases"]
        if case["comparison"] == "exact" and case["coverage_claim"] == "supported"
    ]
    for case in exact_supported:
        source = (ROOT / fixtures[case["id"]]["source"]).resolve()
        report = compare_source(args.cli, source)
        emitted = {diagnostic["code"] for diagnostic in report["diagnostics"]}
        unexpected = emitted & NEW_CONFORMANCE_CODES
        if unexpected:
            raise ValueError(
                f"exact supported case acquired a conformance guard: "
                f"{case['id']} {sorted(unexpected)}"
            )

    print(
        f"Renderer dispositions: {len(divergent)} divergences guarded, "
        f"{len(exact_supported)} exact supported cases retain their prior coverage"
    )


if __name__ == "__main__":
    main()
