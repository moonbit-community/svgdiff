#!/usr/bin/env python3

import argparse
import hashlib
import html
import json
import random
import re
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from evaluation.schema_validation import audit_schema, validate_instance


SCHEMA_PATH = ROOT / "schema/svgdiff-report.schema.json"
RESULTS_VERSION = "svgdiff-fuzz-smoke-results/1"
DEFAULT_SEED = 20260714
DEFAULT_CASES = 24


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run reproducible generative fuzz cases through the production CLI."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--cases", type=int, default=DEFAULT_CASES)
    parser.add_argument("--case-index", type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.cases <= 0:
        parser.error("--cases must be positive")
    if args.case_index is not None and not 0 <= args.case_index < args.cases:
        parser.error("--case-index must be within the generated case range")
    return args


def document(body: str) -> str:
    return f"<svg width='16' height='16'>{body}</svg>"


def supported_case(rng: random.Random, index: int) -> tuple[str, str, list[str]]:
    colors = ["red", "blue", "green", "#ff0000", "#00ff00", "#0000ff"]
    before_color = rng.choice(colors)
    after_color = rng.choice([color for color in colors if color != before_color])
    x = rng.randrange(0, 9)
    y = rng.randrange(0, 9)
    width = rng.randrange(1, 8)
    height = rng.randrange(1, 8)
    sibling = (
        f"<rect id='stable-{index}' x='{rng.randrange(2, 14)}' "
        f"y='{rng.randrange(2, 14)}' width='1' height='1' fill='black'/>"
    )
    before = document(
        f"<rect id='subject-{index}' x='{x}' y='{y}' width='{width}' "
        f"height='{height}' fill='{before_color}'/>{sibling}"
    )
    if rng.randrange(2) == 0:
        after_rect = (
            f"<rect id='renamed-{index}' x='{x}' y='{y}' width='{width}' "
            f"height='{height}' fill='{after_color}'/>"
        )
    else:
        after_rect = (
            f"<rect id='renamed-{index}' x='{min(x + 1, 15)}' y='{y}' "
            f"width='{width}' height='{height}' fill='{before_color}'/>"
        )
    return before, document(f"{sibling}{after_rect}"), []


def limited_case(rng: random.Random, index: int) -> tuple[str, str, list[str]]:
    if rng.randrange(2) == 0:
        before = document(
            f"<path id='path-{index}' d='M 1 1 L {rng.randrange(4, 12)} 1' "
            "stroke='red'/>"
        )
        after = document(
            f"<path id='path-{index}' d='M 1 1 L {rng.randrange(4, 12)} 2' "
            "stroke='blue'/>"
        )
    else:
        before = document(
            f"<rect id='box-{index}' x='2' y='2' width='6' height='6' "
            "fill='red' transform='skewX(20)'/>"
        )
        after = document(
            f"<rect id='box-{index}' x='2' y='2' width='6' height='6' "
            "fill='blue' transform='skewX(21)'/>"
        )
    return before, after, []


def malformed_case(rng: random.Random, index: int) -> tuple[str, str, list[str]]:
    malformed = [
        "<svg><rect></svg>",
        "<svg width='16' height='16'><g><rect/></svg>",
        "<svg width='16' height='16'><rect fill='red></rect></svg>",
        "<svg width='16' height='16'><rect/><",
    ]
    noise = "".join(rng.choice("<>'\"=/ abcXYZ012") for _ in range(8))
    before = malformed[index % len(malformed)] + noise
    after = document("<rect width='4' height='4' fill='blue'/>")
    return before, after, []


def hostile_case(rng: random.Random, index: int) -> tuple[str, str, list[str]]:
    marker = f"FUZZ_MARKER_{index}_{rng.randrange(1_000_000)}"
    payloads = [
        f"</textarea><script>{marker}</script>",
        f"</iframe><script>{marker}</script>",
    ]
    comment = "".join(payloads)
    authored_id = f"hostile-&quot;-&amp;-{index}"
    before = document(
        f"<!-- {comment} --><rect id='{authored_id}' x='1' y='1' "
        "width='6' height='6' fill='red'/>"
    )
    after = document(
        f"<!-- {comment} --><rect id='{authored_id}' x='1' y='1' "
        "width='6' height='6' fill='blue'/>"
    )
    return before, after, payloads


def generate_case(seed: int, index: int) -> dict[str, Any]:
    rng = random.Random(seed ^ (index * 0x9E3779B1))
    generators = [supported_case, limited_case, malformed_case, hostile_case]
    generator = generators[index % len(generators)]
    before, after, hostile_payloads = generator(rng, index)
    return {
        "id": f"seed-{seed}-case-{index}",
        "index": index,
        "category": generator.__name__.removesuffix("_case"),
        "before": before,
        "after": after,
        "hostile_payloads": hostile_payloads,
    }


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_html(
    case: dict[str, Any], rendered_html: str, report: dict[str, Any]
) -> None:
    if not rendered_html.startswith("<!doctype html>"):
        raise ValueError(f"{case['id']}: HTML has no doctype")
    if rendered_html.count("<iframe") != 2 or rendered_html.count('sandbox=""') != 2:
        raise ValueError(f"{case['id']}: preview sandbox boundary changed")
    if rendered_html.count("<script>") != 1:
        raise ValueError(f"{case['id']}: hostile source created a script boundary")
    if rendered_html.count('srcdoc="&lt;!doctype html&gt;') != 2:
        raise ValueError(f"{case['id']}: preview source is not attribute escaped")
    for payload in case["hostile_payloads"]:
        if payload in rendered_html:
            raise ValueError(f"{case['id']}: hostile payload escaped its sandbox")
    match = re.search(
        r'<textarea\b(?=[^>]*\bid="report-data")(?=[^>]*\breadonly\b)[^>]*>'
        r"(.*?)</textarea>",
        rendered_html,
        flags=re.DOTALL,
    )
    if match is None:
        raise ValueError(f"{case['id']}: report JSON textarea is missing")
    embedded = json.loads(html.unescape(match.group(1)))
    if embedded != report:
        raise ValueError(f"{case['id']}: embedded report differs from CLI JSON")


def run_case(cli: Path, schema: dict[str, Any], case: dict[str, Any]) -> dict[str, Any]:
    with tempfile.TemporaryDirectory(prefix="svgdiff-fuzz-") as directory:
        root = Path(directory)
        before_path = root / "before.svg"
        after_path = root / "after.svg"
        html_path = root / "report.html"
        before_path.write_text(case["before"], encoding="utf-8")
        after_path.write_text(case["after"], encoding="utf-8")
        result = subprocess.run(
            [
                str(cli),
                str(before_path),
                str(after_path),
                "--agent-json",
                "--html",
                str(html_path),
            ],
            check=False,
            capture_output=True,
        )
        if result.returncode not in {0, 1} or result.stderr:
            raise ValueError(
                f"{case['id']}: CLI status={result.returncode}, "
                f"stderr={result.stderr.decode(errors='replace')!r}"
            )
        report = json.loads(result.stdout)
        validate_instance(report, schema, schema)
        expected_status = 1 if report["analysis_status"] == "failed" else 0
        if result.returncode != expected_status:
            raise ValueError(
                f"{case['id']}: analysis/exit mismatch "
                f"{report['analysis_status']}/{result.returncode}"
            )
        if case["category"] == "supported" and report["analysis_status"] != "complete":
            raise ValueError(f"{case['id']}: supported case lost complete coverage")
        if case["category"] == "limited" and report["analysis_status"] != "partial":
            raise ValueError(f"{case['id']}: limited case did not report partial coverage")
        if case["category"] == "malformed" and report["analysis_status"] != "failed":
            raise ValueError(f"{case['id']}: malformed XML did not fail analysis")
        if case["category"] == "hostile" and report["analysis_status"] == "failed":
            raise ValueError(f"{case['id']}: well-formed hostile source failed parsing")
        html_bytes = html_path.read_bytes()
        validate_html(case, html_bytes.decode("utf-8"), report)
        input_bytes = (case["before"] + "\0" + case["after"]).encode()
        return {
            "id": case["id"],
            "index": case["index"],
            "category": case["category"],
            "analysis_status": report["analysis_status"],
            "input_sha256": digest(input_bytes),
            "report_sha256": digest(result.stdout),
            "html_sha256": digest(html_bytes),
        }


def main() -> None:
    args = parse_args()
    cli = args.cli.resolve()
    if not cli.is_file():
        raise ValueError(f"CLI does not exist: {cli}")
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    audit_schema(schema)
    indices = (
        [args.case_index]
        if args.case_index is not None
        else list(range(args.cases))
    )
    results = []
    for index in indices:
        case = generate_case(args.seed, index)
        try:
            results.append(run_case(cli, schema, case))
        except Exception as error:
            raise ValueError(
                f"{case['id']} failed; replay with --seed {args.seed} "
                f"--cases {args.cases} --case-index {index}: {error}"
            ) from error
    categories = Counter(result["category"] for result in results)
    output = {
        "schema_version": RESULTS_VERSION,
        "seed": args.seed,
        "configured_case_count": args.cases,
        "selected_case_index": args.case_index,
        "executed_case_count": len(results),
        "categories": dict(sorted(categories.items())),
        "cases": results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        f"Fuzz smoke: seed={args.seed}, cases={len(results)}, "
        f"categories={dict(sorted(categories.items()))}"
    )


if __name__ == "__main__":
    main()
