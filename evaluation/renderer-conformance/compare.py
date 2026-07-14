#!/usr/bin/env python3

import argparse
import hashlib
import json
import math
import re
import struct
import subprocess
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REQUIRED_CATEGORIES = {"geometry", "paint", "alpha", "clipping", "compositing"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare the pinned renderer with browser-oracle PNGs."
    )
    parser.add_argument("--oracle", required=True, type=Path)
    parser.add_argument("--adapter", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "evaluation/browser-oracle/manifest.json",
    )
    return parser.parse_args()


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    left_distance = abs(estimate - left)
    above_distance = abs(estimate - above)
    upper_left_distance = abs(estimate - upper_left)
    if left_distance <= above_distance and left_distance <= upper_left_distance:
        return left
    if above_distance <= upper_left_distance:
        return above
    return upper_left


def decode_png_rgba(path: Path) -> tuple[int, int, list[int]]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    position = 8
    ihdr = None
    compressed = bytearray()
    while position + 12 <= len(data):
        length = struct.unpack(">I", data[position : position + 4])[0]
        chunk_type = data[position + 4 : position + 8]
        payload = data[position + 8 : position + 8 + length]
        if position + 12 + length > len(data):
            raise ValueError(f"truncated PNG chunk: {path}")
        if chunk_type == b"IHDR":
            ihdr = payload
        elif chunk_type == b"IDAT":
            compressed.extend(payload)
        elif chunk_type == b"IEND":
            break
        position += 12 + length
    if ihdr is None or len(ihdr) != 13 or not compressed:
        raise ValueError(f"incomplete PNG: {path}")
    width, height, bit_depth, color_type, compression, filtering, interlace = (
        struct.unpack(">IIBBBBB", ihdr)
    )
    if (
        bit_depth != 8
        or color_type not in {2, 6}
        or compression != 0
        or filtering != 0
        or interlace != 0
    ):
        raise ValueError(f"unsupported oracle PNG encoding: {path}")
    channels = 3 if color_type == 2 else 4
    stride = width * channels
    raw = zlib.decompress(bytes(compressed))
    if len(raw) != height * (stride + 1):
        raise ValueError(f"unexpected oracle PNG data length: {path}")
    previous = bytearray(stride)
    rgba: list[int] = []
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        filtered = raw[offset + 1 : offset + 1 + stride]
        offset += stride + 1
        row = bytearray(stride)
        for index, value in enumerate(filtered):
            left = row[index - channels] if index >= channels else 0
            above = previous[index]
            upper_left = previous[index - channels] if index >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                predictor = paeth(left, above, upper_left)
            else:
                raise ValueError(f"unsupported PNG filter {filter_type}: {path}")
            row[index] = (value + predictor) & 0xFF
        for index in range(0, stride, channels):
            rgba.extend(row[index : index + 3])
            rgba.append(row[index + 3] if channels == 4 else 255)
        previous = row
    return width, height, rgba


def render_with_adapter(
    adapter: Path, source: Path, width: int, height: int
) -> list[int]:
    result = subprocess.run(
        [str(adapter), str(source), str(width), str(height)],
        check=True,
        capture_output=True,
        text=True,
    )
    rendered = json.loads(result.stdout)
    if rendered.get("width") != width or rendered.get("height") != height:
        raise ValueError(f"adapter dimensions mismatch: {source}")
    rgba = rendered.get("rgba")
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


def compare_pixels(left: list[int], right: list[int]) -> dict:
    if len(left) != len(right) or len(left) % 4 != 0:
        raise ValueError("RGBA buffers have different dimensions")
    left = premultiply(left)
    right = premultiply(right)
    changed_pixels = 0
    squared_error = 0
    max_channel_delta = 0
    for offset in range(0, len(left), 4):
        deltas = [abs(left[offset + channel] - right[offset + channel]) for channel in range(4)]
        if any(deltas):
            changed_pixels += 1
        max_channel_delta = max(max_channel_delta, *deltas)
        squared_error += sum(delta * delta for delta in deltas)
    pixel_count = len(left) // 4
    rmse = math.sqrt(squared_error / len(left)) / 255.0
    return {
        "comparison": "exact" if changed_pixels == 0 else "divergent",
        "changed_pixels": changed_pixels,
        "changed_pixel_fraction": round(changed_pixels / pixel_count, 12),
        "premultiplied_rgba8_rmse": round(rmse, 12),
        "max_channel_delta": max_channel_delta,
    }


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    oracle_report_path = args.oracle / "oracle-report.json"
    oracle_report = json.loads(oracle_report_path.read_text(encoding="utf-8"))
    oracle_cases = {case["id"]: case for case in oracle_report["cases"]}
    fixtures = manifest["fixtures"]
    categories = {fixture.get("category") for fixture in fixtures}
    if categories != REQUIRED_CATEGORIES:
        raise ValueError("conformance fixtures do not cover every required category")
    if any(
        fixture.get("coverage_claim") not in {"supported", "guarded", "exploratory"}
        for fixture in fixtures
    ):
        raise ValueError("invalid conformance fixture coverage claim")
    if set(oracle_cases) != {fixture["id"] for fixture in fixtures}:
        raise ValueError("browser oracle and conformance manifest cases differ")

    cases = []
    for fixture in fixtures:
        source = (ROOT / fixture["source"]).resolve()
        if ROOT not in source.parents or not source.is_file():
            raise ValueError(f"unsafe or missing fixture source: {fixture['source']}")
        oracle_case = oracle_cases[fixture["id"]]
        png = (args.oracle / oracle_case["png"]).resolve()
        if args.oracle.resolve() not in png.parents or not png.is_file():
            raise ValueError(f"unsafe or missing oracle PNG: {oracle_case['png']}")
        width, height, browser_rgba = decode_png_rgba(png)
        if (width, height) != (fixture["width"], fixture["height"]):
            raise ValueError(f"oracle dimensions mismatch: {fixture['id']}")
        renderer_rgba = render_with_adapter(args.adapter, source, width, height)
        cases.append(
            {
                "id": fixture["id"],
                "category": fixture["category"],
                "coverage_claim": fixture["coverage_claim"],
                **compare_pixels(renderer_rgba, browser_rgba),
            }
        )

    category_summary = {}
    for category in sorted(REQUIRED_CATEGORIES):
        selected = [case for case in cases if case["category"] == category]
        category_summary[category] = {
            "cases": len(selected),
            "exact": sum(case["comparison"] == "exact" for case in selected),
            "divergent": sum(case["comparison"] == "divergent" for case in selected),
        }
    browser_environment = oracle_report["environment"]
    browser_version_match = re.search(
        r"(?:HeadlessChrome|Chrome)/([^ ]+)", browser_environment["user_agent"]
    )
    if browser_version_match is None:
        raise ValueError("browser oracle user agent has no Chrome version")
    source_set = [
        {"id": case["id"], "source_sha256": case["source_sha256"]}
        for case in oracle_report["cases"]
    ]
    report = {
        "schema_version": "svgdiff-renderer-conformance/1",
        "conformance_profile_id": "svgdiff-renderer-conformance-profile/2",
        "renderer_id": "mizchi/svg@0.2.1",
        "raster_representation": "premultiplied_rgba8",
        "browser_environment": {
            "browser_engine": browser_environment["browser_engine"],
            "browser_version": browser_version_match.group(1),
            "device_pixel_ratio": browser_environment["device_pixel_ratio"],
            "playwright_cli_version": browser_environment["playwright_cli_version"],
        },
        "fixture_source_set_sha256": hashlib.sha256(
            json.dumps(source_set, separators=(",", ":"), sort_keys=True).encode("utf-8")
        ).hexdigest(),
        "summary": {
            "cases": len(cases),
            "supported": sum(case["coverage_claim"] == "supported" for case in cases),
            "exploratory": sum(
                case["coverage_claim"] == "exploratory" for case in cases
            ),
            "guarded": sum(case["coverage_claim"] == "guarded" for case in cases),
            "exact": sum(case["comparison"] == "exact" for case in cases),
            "divergent": sum(case["comparison"] == "divergent" for case in cases),
            "categories": category_summary,
        },
        "cases": cases,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        f"Renderer conformance: {len(cases)} cases, "
        f"{report['summary']['exact']} exact, "
        f"{report['summary']['divergent']} divergent"
    )


if __name__ == "__main__":
    main()
