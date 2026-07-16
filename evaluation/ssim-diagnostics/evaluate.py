#!/usr/bin/env python3

import argparse
import hashlib
import json
import math
import subprocess
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "evaluation/ssim-diagnostics/manifest.v1.json"
RESULTS_PATH = ROOT / "evaluation/ssim-diagnostics/results.v1.json"
TIER_ORDER = ["none", "low", "medium", "high"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Evaluate QA-only SSIM diagnostics on the curated corpus."
    )
    parser.add_argument("--adapter", required=True, type=Path)
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--update", action="store_true")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def checked_source(relative: str) -> Path:
    path = (ROOT / "evaluation/corpus" / relative).resolve()
    if ROOT not in path.parents or not path.is_file():
        raise ValueError(f"unsafe or missing corpus source: {relative}")
    return path


def run_json(command: list[str], accepted_statuses: set[int]) -> dict[str, Any]:
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode not in accepted_statuses or result.stderr:
        raise ValueError(
            f"command failed with status={result.returncode}, "
            f"stderr={result.stderr!r}: {command[0]}"
        )
    return json.loads(result.stdout)


def source_hash(case: dict[str, Any]) -> str:
    records = []
    for side in ("before", "after"):
        path = checked_source(case[side])
        records.append(
            {
                "side": side,
                "path": case[side],
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            }
        )
    encoded = json.dumps(records, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def adapter_implementation_hash() -> str:
    digest = hashlib.sha256()
    for relative in (
        "evaluation/ssim_adapter/metric.mbt",
        "evaluation/ssim_adapter/main.mbt",
        "evaluation/ssim_adapter/moon.pkg",
    ):
        path = ROOT / relative
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def validate_adapter_result(case_id: str, result: dict[str, Any]) -> None:
    expected_keys = {
        "canonical_exact_rgba8",
        "canonical_ssim",
        "enlarged_exact_rgba8",
        "enlarged_ssim",
        "ms_ssim",
        "ms_ssim_reason_code",
    }
    if set(result) != expected_keys:
        raise ValueError(f"{case_id}: unexpected adapter result fields")
    for key in ("canonical_ssim", "enlarged_ssim"):
        value = result[key]
        if not isinstance(value, (int, float)) or not math.isfinite(value):
            raise ValueError(f"{case_id}: invalid {key}")
        if value > 1.0 + 1e-12:
            raise ValueError(f"{case_id}: {key} exceeds the identity maximum")
    if result["ms_ssim"] is None:
        if result["ms_ssim_reason_code"] not in {
            "non_positive_contrast_structure_mean",
            "non_positive_final_ssim",
        }:
            raise ValueError(f"{case_id}: invalid unavailable MS-SSIM reason")
    elif (
        not isinstance(result["ms_ssim"], (int, float))
        or not math.isfinite(result["ms_ssim"])
        or not 0.0 <= result["ms_ssim"] <= 1.0 + 1e-12
        or result["ms_ssim_reason_code"] is not None
    ):
        raise ValueError(f"{case_id}: invalid computed MS-SSIM")


def ordinal_pair_evaluation(
    cases: list[dict[str, Any]], score_field: str
) -> dict[str, Any]:
    selected = [case for case in cases if case[score_field] is not None]
    concordant = 0
    inverted = 0
    tied = 0
    examples = []
    for left_index, left in enumerate(selected):
        for right in selected[left_index + 1 :]:
            left_tier = TIER_ORDER.index(left["human_tier"])
            right_tier = TIER_ORDER.index(right["human_tier"])
            if left_tier == right_tier:
                continue
            expected = 1 if left_tier > right_tier else -1
            delta = left[score_field] - right[score_field]
            actual = 0 if abs(delta) <= 1e-12 else (1 if delta > 0 else -1)
            if actual == expected:
                concordant += 1
            elif actual == 0:
                tied += 1
            else:
                inverted += 1
                examples.append(
                    {
                        "higher_tier_case_id": (
                            left["case_id"] if expected == 1 else right["case_id"]
                        ),
                        "lower_tier_case_id": (
                            right["case_id"] if expected == 1 else left["case_id"]
                        ),
                        "higher_tier_score": (
                            left[score_field] if expected == 1 else right[score_field]
                        ),
                        "lower_tier_score": (
                            right[score_field] if expected == 1 else left[score_field]
                        ),
                    }
                )
    total = concordant + inverted + tied
    return {
        "measured_case_count": len(selected),
        "different_tier_pair_count": total,
        "concordant_pair_count": concordant,
        "inverted_pair_count": inverted,
        "tied_pair_count": tied,
        "pair_accuracy": None if total == 0 else concordant / total,
        "inversion_examples": examples[:8],
    }


def build_results(adapter: Path, cli: Path) -> dict[str, Any]:
    manifest = load_json(MANIFEST_PATH)
    corpus = load_json(ROOT / "evaluation/corpus/manifest.json")
    annotations = load_json(ROOT / "evaluation/annotations/main-changes.v1.json")
    if manifest["corpus_version"] != corpus["schema_version"]:
        raise ValueError("SSIM manifest corpus version drifted")
    if manifest["main_change_labels_version"] != annotations["schema_version"]:
        raise ValueError("SSIM manifest annotation version drifted")
    corpus_by_id = {case["id"]: case for case in corpus["cases"]}
    labels_by_id = {case["case_id"]: case for case in annotations["cases"]}
    if set(labels_by_id) != set(corpus_by_id):
        raise ValueError("SSIM corpus and human labels differ")
    if set(manifest["case_ids"]) != set(corpus_by_id) or len(
        manifest["case_ids"]
    ) != len(set(manifest["case_ids"])):
        raise ValueError("SSIM manifest must select every corpus case exactly once")

    results = []
    for case_id in manifest["case_ids"]:
        case = corpus_by_id[case_id]
        label = labels_by_id[case_id]
        if len(label["main_visual_changes"]) != 1:
            raise ValueError(f"{case_id}: expected one versioned main-change label")
        importance = label["main_visual_changes"][0]["relative_importance"]
        if importance["rank"] != 1 or importance["tier"] not in TIER_ORDER:
            raise ValueError(f"{case_id}: invalid human importance label")
        before = checked_source(case["before"])
        after = checked_source(case["after"])
        width = case["viewport"]["width"]
        height = case["viewport"]["height"]
        metric = run_json(
            [str(adapter), str(before), str(after), str(width), str(height)], {0}
        )
        validate_adapter_result(case_id, metric)
        report = run_json(
            [
                str(cli),
                str(before),
                str(after),
                "--width",
                str(width),
                "--height",
                str(height),
                "--agent-json",
            ],
            {0, 1},
        )
        if report["schema_version"] != manifest["report_schema_version"]:
            raise ValueError(f"{case_id}: production report schema drifted")
        if (
            report["profile"]["renderer_id"]
            != manifest["production_renderer_id"]
        ):
            raise ValueError(f"{case_id}: renderer identity drifted")
        if (
            report["profile"]["renderer_conformance_profile_id"]
            != manifest["renderer_conformance_profile_id"]
        ):
            raise ValueError(f"{case_id}: conformance identity drifted")
        results.append(
            {
                "case_id": case_id,
                "human_tier": importance["tier"],
                "source_pair_sha256": source_hash(case),
                "production_analysis_status": report["analysis_status"],
                "production_renderer_capability_gaps": report[
                    "renderer_capability_gaps"
                ],
                **metric,
                "canonical_dissimilarity": 1.0 - metric["canonical_ssim"],
                "enlarged_dissimilarity": 1.0 - metric["enlarged_ssim"],
                "ms_ssim_dissimilarity": (
                    None if metric["ms_ssim"] is None else 1.0 - metric["ms_ssim"]
                ),
                "ssim_scale_absolute_delta": abs(
                    metric["canonical_ssim"] - metric["enlarged_ssim"]
                ),
            }
        )

    tier_counts = Counter(case["human_tier"] for case in results)
    false_identity = [
        case["case_id"]
        for case in results
        if case["human_tier"] != "none" and case["canonical_exact_rgba8"]
    ]
    scale_deltas = [case["ssim_scale_absolute_delta"] for case in results]
    unavailable_ms = [
        case["case_id"] for case in results if case["ms_ssim"] is None
    ]
    return {
        "schema_version": "svgdiff-ssim-diagnostic-results/1",
        "input_version": manifest["schema_version"],
        "annotation_review_status": annotations["review_status"],
        "canonical_report_evidence": False,
        "accepted_role": "qa_only_secondary_structural_observation",
        "production_integration": "rejected",
        "production_rejection_reasons": [
            "global_scores_do_not_localize_or_attribute_causes",
            "scores_depend_materially_on_output_scale",
            "renderer_coverage_gaps_can_create_false_identity",
            "ms_ssim_product_can_be_unavailable_for_non_positive_components",
            "human_importance_order_contains_inversions_and_ties",
        ],
        "raster_source_id": manifest["raster_source_id"],
        "production_renderer_id": manifest["production_renderer_id"],
        "renderer_conformance_profile_id": manifest[
            "renderer_conformance_profile_id"
        ],
        "adapter_implementation_sha256": adapter_implementation_hash(),
        "grayscale_profile": manifest["grayscale_profile"],
        "ssim_profile": manifest["ssim_profile"],
        "ms_ssim_profile": manifest["ms_ssim_profile"],
        "summary": {
            "case_count": len(results),
            "human_tier_case_counts": {
                tier: tier_counts[tier] for tier in TIER_ORDER
            },
            "human_non_none_false_exact_case_ids": false_identity,
            "ms_ssim_unavailable_case_ids": unavailable_ms,
            "ssim_scale_absolute_delta_mean": sum(scale_deltas)
            / len(scale_deltas),
            "ssim_scale_absolute_delta_maximum": max(scale_deltas),
            "canonical_ssim_ordering": ordinal_pair_evaluation(
                results, "canonical_dissimilarity"
            ),
            "enlarged_ssim_ordering": ordinal_pair_evaluation(
                results, "enlarged_dissimilarity"
            ),
            "ms_ssim_ordering": ordinal_pair_evaluation(
                results, "ms_ssim_dissimilarity"
            ),
        },
        "cases": results,
    }


def encoded_json(value: dict[str, Any]) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def main() -> None:
    args = parse_args()
    results = build_results(args.adapter.resolve(), args.cli.resolve())
    encoded = encoded_json(results)
    if args.update:
        RESULTS_PATH.write_text(encoded, encoding="utf-8")
    elif not RESULTS_PATH.is_file() or RESULTS_PATH.read_text(encoding="utf-8") != encoded:
        raise ValueError("SSIM diagnostic artifact drifted")
    print(
        "SSIM diagnostics: "
        f"{results['summary']['case_count']} cases, "
        f"{len(results['summary']['human_non_none_false_exact_case_ids'])} "
        "non-none false identity, "
        f"{len(results['summary']['ms_ssim_unavailable_case_ids'])} "
        "MS-SSIM unavailable; production integration rejected"
    )


if __name__ == "__main__":
    main()
