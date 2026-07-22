#!/usr/bin/env python3

import argparse
from copy import deepcopy
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.schema_validation import audit_schema, validate_instance


RECORD_SCHEMA = ROOT / "schema" / "svgdiff-agent-projection.schema.json"
REPORT_SCHEMA = ROOT / "schema" / "svgdiff-report.schema.json"
SECTIONS = (
    "difference_groups",
    "events",
    "limitations",
)


def load_records(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or any(not line.strip() for line in lines):
        raise ValueError("projection must contain non-empty JSONL records")
    records = []
    for index, line in enumerate(lines):
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError as error:
            raise ValueError(f"projection line {index + 1} is invalid JSON") from error
    return lines, records


def reconstruct(report, lines, records, record_schema, report_schema):
    validate_instance(report, report_schema, report_schema)
    for index, record in enumerate(records):
        validate_instance(record, record_schema, record_schema, f"$line[{index + 1}]")
        if record["sequence"] != index:
            raise ValueError(
                f"projection sequence {record['sequence']} does not match position {index}"
            )
        if record["source_schema_version"] != report["schema_version"]:
            raise ValueError("projection source schema does not match report")

    header = records[0]
    if header["record_type"] != "header":
        raise ValueError("projection must begin with one header record")
    expected_record_count = 1 + sum(header["section_counts"].values())
    if len(records) != expected_record_count:
        raise ValueError(
            f"projection record count {len(records)} does not match header {expected_record_count}"
        )

    reconstructed = deepcopy(header["value"])
    for section in SECTIONS:
        reconstructed[section] = []

    cursor = 1
    for section in SECTIONS:
        expected_count = header["section_counts"][section]
        for section_index in range(expected_count):
            record = records[cursor]
            if record["record_type"] != "item":
                raise ValueError(f"projection record {cursor} is not an item")
            if record["section"] != section or record["index"] != section_index:
                raise ValueError(
                    f"projection record {cursor} does not match {section}[{section_index}]"
                )
            reconstructed[section].append(record["value"])
            cursor += 1

    if reconstructed != report:
        raise ValueError("projection does not reconstruct the canonical report exactly")
    validate_instance(reconstructed, report_schema, report_schema)

    compact_size = len(
        json.dumps(report, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    )
    largest_record_size = max(len(line.encode("utf-8")) for line in lines)
    return largest_record_size, compact_size


def build_parser():
    parser = argparse.ArgumentParser(
        description="Validate and reconstruct SVG Diff Agent projection JSONL."
    )
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--projection", type=Path, required=True)
    return parser


def main():
    args = build_parser().parse_args()
    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
        record_schema = json.loads(RECORD_SCHEMA.read_text(encoding="utf-8"))
        report_schema = json.loads(REPORT_SCHEMA.read_text(encoding="utf-8"))
        audit_schema(record_schema)
        audit_schema(report_schema)
        lines, records = load_records(args.projection)
        largest, compact = reconstruct(
            report, lines, records, record_schema, report_schema
        )
        print(
            f"Agent projection: {len(records)} records, largest={largest}, compact={compact}"
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
