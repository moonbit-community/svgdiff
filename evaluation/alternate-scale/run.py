#!/usr/bin/env python3

import argparse
import hashlib
import json
import math
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure pinned-renderer behavior across QA-only output scales."
    )
    parser.add_argument("--adapter", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "evaluation/alternate-scale/manifest.v1.json",
    )
    return parser.parse_args()


def checked_source(relative_path: str) -> Path:
    source = (ROOT / relative_path).resolve()
    if ROOT not in source.parents or not source.is_file():
        raise ValueError(f"unsafe or missing fixture source: {relative_path}")
    return source


def render(adapter: Path, source: Path, width: int, height: int) -> list[int]:
    result = subprocess.run(
        [str(adapter), str(source), str(width), str(height)],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    rgba = payload.get("rgba")
    if payload.get("width") != width or payload.get("height") != height:
        raise ValueError(f"adapter dimensions mismatch: {source}")
    if not isinstance(rgba, list) or len(rgba) != width * height * 4:
        raise ValueError(f"adapter RGBA buffer mismatch: {source}")
    if any(not isinstance(value, int) or not 0 <= value <= 255 for value in rgba):
        raise ValueError(f"adapter emitted an invalid channel: {source}")
    return rgba


def premultiply(rgba: list[int]) -> list[int]:
    result: list[int] = []
    for index in range(0, len(rgba), 4):
        alpha = rgba[index + 3]
        result.extend(
            [
                (rgba[index] * alpha + 127) // 255,
                (rgba[index + 1] * alpha + 127) // 255,
                (rgba[index + 2] * alpha + 127) // 255,
                alpha,
            ]
        )
    return result


def compare_pixels(before: list[int], after: list[int]) -> dict:
    before = premultiply(before)
    after = premultiply(after)
    if len(before) != len(after):
        raise ValueError("rendered buffers have different dimensions")
    changed_pixels = 0
    squared_error = 0
    max_channel_delta = 0
    for offset in range(0, len(before), 4):
        deltas = [
            abs(before[offset + channel] - after[offset + channel])
            for channel in range(4)
        ]
        if any(deltas):
            changed_pixels += 1
        squared_error += sum(delta * delta for delta in deltas)
        max_channel_delta = max(max_channel_delta, *deltas)
    pixel_count = len(before) // 4
    return {
        "changed_pixels": changed_pixels,
        "changed_pixel_fraction": round(changed_pixels / pixel_count, 12),
        "premultiplied_rgba8_rmse": round(
            math.sqrt(squared_error / len(before)) / 255.0, 12
        ),
        "max_channel_delta": max_channel_delta,
    }


def source_set_hash(pairs: list[dict]) -> str:
    sources = []
    for pair in pairs:
        for side in ("before", "after"):
            source = checked_source(pair[side])
            sources.append(
                {
                    "pair": pair["id"],
                    "side": side,
                    "path": pair[side],
                    "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                }
            )
    encoded = json.dumps(sources, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "svgdiff-alternate-scale-input/1":
        raise ValueError("unsupported alternate-scale manifest schema")
    if manifest.get("renderer_id") != "mizchi/svg@0.2.1":
        raise ValueError("manifest does not identify the pinned renderer")
    if (
        manifest.get("conformance_profile_id")
        != "svgdiff-renderer-conformance-profile/23"
    ):
        raise ValueError("unsupported renderer conformance profile")
    scales = manifest.get("scales")
    if (
        not isinstance(scales, list)
        or not scales
        or scales != sorted(set(scales))
        or any(not isinstance(scale, int) or scale <= 0 for scale in scales)
    ):
        raise ValueError("scales must be unique sorted positive integers")
    pairs = manifest.get("pairs")
    if not isinstance(pairs, list) or not pairs:
        raise ValueError("manifest contains no pairs")
    if len({pair.get("id") for pair in pairs}) != len(pairs):
        raise ValueError("pair IDs must be unique")

    results = []
    for pair in pairs:
        before = checked_source(pair["before"])
        after = checked_source(pair["after"])
        measurements = []
        for scale in scales:
            width = pair["width"] * scale
            height = pair["height"] * scale
            measurement = compare_pixels(
                render(args.adapter, before, width, height),
                render(args.adapter, after, width, height),
            )
            measurements.append(
                {
                    "scale": scale,
                    "output_width": width,
                    "output_height": height,
                    **measurement,
                }
            )
        if pair.get("expectation") == "exact_at_all_scales" and any(
            measurement["changed_pixels"] != 0 for measurement in measurements
        ):
            raise ValueError(f"exact pair diverged: {pair['id']}")
        if pair.get("expectation") not in {"exact_at_all_scales", "observe"}:
            raise ValueError(f"invalid expectation: {pair['id']}")
        results.append(
            {
                "id": pair["id"],
                "expectation": pair["expectation"],
                "measurements": measurements,
            }
        )

    by_id = {pair["id"]: pair for pair in results}
    directional_results = []
    for check in manifest.get("directional_checks", []):
        negative = by_id[check["negative_pair"]]["measurements"]
        positive = by_id[check["positive_pair"]]["measurements"]
        comparisons = []
        for negative_scale, positive_scale in zip(negative, positive):
            if negative_scale["scale"] != positive_scale["scale"]:
                raise ValueError(f"directional scale mismatch: {check['id']}")
            delta = abs(
                negative_scale["changed_pixel_fraction"]
                - positive_scale["changed_pixel_fraction"]
            )
            comparisons.append(
                {
                    "scale": negative_scale["scale"],
                    "changed_pixel_fraction_delta": round(delta, 12),
                    "classification": "symmetric" if delta == 0 else "asymmetric",
                }
            )
        directional_results.append({"id": check["id"], "scales": comparisons})

    report = {
        "schema_version": "svgdiff-alternate-scale-renderer-qa/1",
        "renderer_id": manifest["renderer_id"],
        "conformance_profile_id": manifest["conformance_profile_id"],
        "canonical_report_evidence": False,
        "raster_representation": "premultiplied_rgba8",
        "fixture_source_set_sha256": source_set_hash(pairs),
        "pairs": results,
        "directional_checks": directional_results,
    }
    args.output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    asymmetric = sum(
        scale["classification"] == "asymmetric"
        for check in directional_results
        for scale in check["scales"]
    )
    print(
        f"Alternate-scale renderer QA: {len(results)} pairs, "
        f"{len(scales)} scales, {asymmetric} asymmetric directional observations"
    )


if __name__ == "__main__":
    main()
