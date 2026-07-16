#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import subprocess
import sys


def expect_rejected(validator, report, path):
    result = subprocess.run(
        [
            sys.executable,
            str(validator),
            "--report",
            str(report),
            "--projection",
            str(path),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode == 0:
        raise ValueError(f"validator accepted negative control {path.name}")


def write_records(path, records):
    path.write_text(
        "\n".join(json.dumps(record, separators=(",", ":")) for record in records)
        + "\n",
        encoding="utf-8",
    )


def main():
    parser = argparse.ArgumentParser(
        description="Exercise Agent projection integrity negative controls."
    )
    parser.add_argument("--validator", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--projection", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    records = [
        json.loads(line)
        for line in args.projection.read_text(encoding="utf-8").splitlines()
    ]
    if len(records) < 3:
        raise SystemExit("projection fixture needs at least two item records")
    args.output_dir.mkdir(parents=True, exist_ok=True)

    controls = {}
    controls["missing.jsonl"] = records[:-1]
    controls["duplicate.jsonl"] = records[:2] + [records[1]] + records[2:]
    controls["reordered.jsonl"] = [records[0], records[2], records[1], *records[3:]]

    miscounted = json.loads(json.dumps(records))
    first_section = next(iter(miscounted[0]["section_counts"]))
    miscounted[0]["section_counts"][first_section] += 1
    controls["miscounted.jsonl"] = miscounted

    wrong_section = json.loads(json.dumps(records))
    wrong_section[1]["section"] = "diagnostics"
    controls["wrong-section.jsonl"] = wrong_section

    for name, control in controls.items():
        path = args.output_dir / name
        write_records(path, control)
        expect_rejected(args.validator, args.report, path)

    print(f"Agent projection negative controls: {len(controls)} rejected")


if __name__ == "__main__":
    main()
