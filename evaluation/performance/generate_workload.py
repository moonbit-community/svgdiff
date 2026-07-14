#!/usr/bin/env python3

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a performance SVG pair.")
    parser.add_argument("--workload", required=True)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def render_svg(workload: dict, fill: str) -> str:
    width = workload["viewport_width"]
    height = workload["viewport_height"]
    columns = workload["columns"]
    cell = workload["cell_size"]
    rect = workload["rect_size"]
    elements = []
    for index in range(workload["subjects_per_input"]):
        x = (index % columns) * cell
        y = (index // columns) * cell
        elements.append(
            f'<rect id="r{index}" x="{x}" y="{y}" '
            f'width="{rect}" height="{rect}" fill="{fill}"/>'
        )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}">\n'
        + "\n".join(elements)
        + "\n</svg>\n"
    )


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    matches = [item for item in manifest["workloads"] if item["id"] == args.workload]
    if len(matches) != 1:
        raise ValueError(f"unknown or duplicate workload: {args.workload}")
    workload = matches[0]
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "before.svg").write_text(
        render_svg(workload, "red"), encoding="utf-8"
    )
    (args.output / "after.svg").write_text(
        render_svg(workload, "blue"), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
