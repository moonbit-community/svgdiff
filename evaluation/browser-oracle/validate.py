#!/usr/bin/env python3

import argparse
import hashlib
import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_header(path: Path) -> tuple[int, int, int]:
    data = path.read_bytes()[:26]
    if len(data) != 26 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"not a PNG: {path}")
    if data[12:16] != b"IHDR":
        raise ValueError(f"missing PNG IHDR: {path}")
    width, height = struct.unpack(">II", data[16:24])
    return width, height, data[25]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate browser oracle output.")
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=ROOT / "evaluation/browser-oracle/manifest.json",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output = args.output.resolve()
    input_manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    report = json.loads((output / "oracle-report.json").read_text(encoding="utf-8"))
    if report.get("schema_version") != "svgdiff-browser-oracle-output/1":
        raise ValueError("unsupported oracle output version")
    environment = report.get("environment", {})
    if environment.get("browser_engine") != "chromium":
        raise ValueError("oracle did not record Chromium")
    if environment.get("device_pixel_ratio") != 1:
        raise ValueError("oracle DPR is not 1")
    if "Chrome/" not in environment.get("user_agent", ""):
        raise ValueError("oracle user agent does not identify Chrome")

    expected = {fixture["id"]: fixture for fixture in input_manifest["fixtures"]}
    actual = {case["id"]: case for case in report.get("cases", [])}
    if set(actual) != set(expected):
        raise ValueError("oracle case IDs do not match the input manifest")
    color_types = set()
    for case_id, fixture in expected.items():
        case = actual[case_id]
        source = (ROOT / fixture["source"]).resolve()
        if ROOT not in source.parents or not source.is_file():
            raise ValueError(f"unsafe or missing source: {fixture['source']}")
        image = (output / case["png"]).resolve()
        if output not in image.parents or not image.is_file():
            raise ValueError(f"unsafe or missing oracle PNG: {case['png']}")
        if case["source_sha256"] != sha256(source):
            raise ValueError(f"source hash mismatch: {case_id}")
        if case["png_sha256"] != sha256(image):
            raise ValueError(f"PNG hash mismatch: {case_id}")
        width, height, color_type = png_header(image)
        if (width, height) != (fixture["width"], fixture["height"]):
            raise ValueError(f"PNG dimensions mismatch: {case_id}")
        if color_type not in {2, 6}:
            raise ValueError(f"PNG is not RGB or RGBA: {case_id}")
        color_types.add(color_type)
        if case["width"] != width or case["height"] != height:
            raise ValueError(f"reported dimensions mismatch: {case_id}")

    if 6 not in color_types:
        raise ValueError("oracle fixture set did not exercise RGBA output")
    print(
        f"Browser oracle: {len(actual)} fixtures, Chromium DPR 1, RGB/RGBA PNGs: ok"
    )


if __name__ == "__main__":
    main()
