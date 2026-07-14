#!/usr/bin/env python3

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PLACEHOLDER = "{{VALUE}}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate deterministic SVG mutation pairs."
    )
    parser.add_argument(
        "--spec",
        type=Path,
        default=ROOT / "specs.json",
        help="Mutation specification JSON.",
    )
    parser.add_argument("--output", type=Path, required=True, help="Output directory.")
    return parser.parse_args()


def safe_relative_path(base: Path, relative: str) -> Path:
    candidate = (base / relative).resolve()
    if base.resolve() not in candidate.parents:
        raise ValueError(f"template escapes mutation directory: {relative}")
    return candidate


def render(template: str, value: str, case_id: str) -> str:
    count = template.count(PLACEHOLDER)
    if count != 1:
        raise ValueError(
            f"{case_id}: expected exactly one {PLACEHOLDER} placeholder, found {count}"
        )
    return template.replace(PLACEHOLDER, value)


def main() -> None:
    args = parse_args()
    spec_path = args.spec.resolve()
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    if spec.get("schema_version") != "svgdiff-mutations/1":
        raise ValueError("unsupported mutation specification version")

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    generated_cases = []
    seen_ids = set()
    coverage_contract = spec.get("coverage_contract", {})
    required_subject_kinds = set(coverage_contract.get("subject_kinds", []))
    required_source_properties = set(
        coverage_contract.get("source_properties", [])
    )
    if not required_subject_kinds or not required_source_properties:
        raise ValueError("mutation specification requires a coverage contract")

    for case in spec.get("cases", []):
        case_id = case["id"]
        if case_id in seen_ids:
            raise ValueError(f"duplicate mutation case ID: {case_id}")
        seen_ids.add(case_id)

        template_path = safe_relative_path(spec_path.parent, case["template"])
        template = template_path.read_text(encoding="utf-8")
        before = render(template, case["before_value"], case_id)
        after = render(template, case["after_value"], case_id)
        if before == after:
            raise ValueError(f"{case_id}: before and after SVGs are identical")

        case_dir = output / "cases" / case_id
        case_dir.mkdir(parents=True, exist_ok=True)
        before_path = case_dir / "before.svg"
        after_path = case_dir / "after.svg"
        before_path.write_text(before, encoding="utf-8")
        after_path.write_text(after, encoding="utf-8")

        generated_cases.append(
            {
                "id": case_id,
                "before": str(before_path.relative_to(output)),
                "after": str(after_path.relative_to(output)),
                "before_sha256": hashlib.sha256(before.encode()).hexdigest(),
                "after_sha256": hashlib.sha256(after.encode()).hexdigest(),
                "expected_changed_fact": case["expected_changed_fact"],
                "viewport": case["viewport"],
                "expected_analysis_status": case["expected_analysis_status"],
            }
        )

    covered_subject_kinds = {
        case["expected_changed_fact"]["subject_kind"] for case in generated_cases
    }
    covered_source_properties = {
        case["expected_changed_fact"]["source_property"] for case in generated_cases
    }
    if covered_subject_kinds != required_subject_kinds:
        raise ValueError("mutation cases do not cover every required subject kind")
    if covered_source_properties != required_source_properties:
        raise ValueError("mutation cases do not cover every required source property")

    if not generated_cases:
        raise ValueError("mutation specification contains no cases")

    manifest = {
        "schema_version": "svgdiff-generated-mutations/1",
        "source_spec": spec_path.name,
        "coverage_contract": coverage_contract,
        "cases": generated_cases,
    }
    (output / "generated-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
