#!/usr/bin/env python3

import argparse
import hashlib
import json
import math
import platform
import subprocess
import sys
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "evaluation/lpips-experiment/manifest.v1.json"
RESULTS_PATH = ROOT / "evaluation/lpips-experiment/results.v1.json"
CORPUS_PATH = ROOT / "evaluation/corpus/manifest.json"
ANNOTATIONS_PATH = ROOT / "evaluation/annotations/main-changes.v1.json"
TIER_ORDER = ["none", "low", "medium", "high"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate or regenerate the optional LPIPS experiment."
    )
    parser.add_argument("--adapter", type=Path)
    parser.add_argument("--cli", type=Path)
    parser.add_argument("--update", action="store_true")
    args = parser.parse_args()
    if args.update and (args.adapter is None or args.cli is None):
        parser.error("--update requires --adapter and --cli")
    if not args.update and (args.adapter is not None or args.cli is not None):
        parser.error("--adapter and --cli are valid only with --update")
    return args


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def checked_source(relative: str) -> Path:
    corpus_root = CORPUS_PATH.parent.resolve()
    path = (corpus_root / relative).resolve()
    if corpus_root not in path.parents or not path.is_file():
        raise ValueError(f"unsafe or missing corpus source: {relative}")
    return path


def source_pair_hash(case: dict[str, Any]) -> str:
    records = []
    for side in ("before", "after"):
        path = checked_source(case[side])
        records.append(
            {
                "side": side,
                "path": case[side],
                "sha256": sha256_file(path),
            }
        )
    encoded = json.dumps(records, sort_keys=True, separators=(",", ":")).encode()
    return sha256_bytes(encoded)


def evaluator_implementation_hash() -> str:
    digest = hashlib.sha256()
    for relative in (
        "evaluation/lpips-experiment/evaluate.py",
        "evaluation/lpips-experiment/manifest.v1.json",
    ):
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update((ROOT / relative).read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def renderer_adapter_hash() -> str:
    digest = hashlib.sha256()
    for relative in (
        "modules/svgdiff/evaluation/renderer_adapter/main.mbt",
        "modules/svgdiff/evaluation/renderer_adapter/moon.pkg",
    ):
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update((ROOT / relative).read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def load_inputs() -> tuple[
    dict[str, Any], dict[str, Any], dict[str, Any]
]:
    manifest = load_json(MANIFEST_PATH)
    corpus = load_json(CORPUS_PATH)
    annotations = load_json(ANNOTATIONS_PATH)
    if manifest["corpus_version"] != corpus["schema_version"]:
        raise ValueError("LPIPS manifest corpus version drifted")
    if manifest["main_change_labels_version"] != annotations["schema_version"]:
        raise ValueError("LPIPS manifest annotation version drifted")
    corpus_ids = [case["id"] for case in corpus["cases"]]
    annotation_ids = [case["case_id"] for case in annotations["cases"]]
    if corpus_ids != manifest["case_ids"] or annotation_ids != corpus_ids:
        raise ValueError("LPIPS manifest must select the labeled corpus in order")
    profile_ids = [profile["id"] for profile in manifest["render_profiles"]]
    if len(profile_ids) != len(set(profile_ids)) or set(profile_ids) != {
        "scale4-white",
        "scale4-black",
        "scale16-white",
        "scale16-black",
    }:
        raise ValueError("LPIPS render profiles drifted")
    return manifest, corpus, annotations


def run_json(
    command: list[str], accepted_statuses: set[int]
) -> dict[str, Any]:
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode not in accepted_statuses or result.stderr:
        raise ValueError(
            f"command failed with status={result.returncode}, "
            f"stderr={result.stderr!r}: {command[0]}"
        )
    return json.loads(result.stdout)


def normalized_platform() -> str:
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "darwin":
        system = "macos"
    if machine in {"aarch64", "arm64"}:
        machine = "arm64"
    return f"{system}-{machine}"


def require_optional_runtime(manifest: dict[str, Any]) -> tuple[Any, Any, Any]:
    try:
        import lpips
        import numpy
        import torch
        import torchvision
    except ImportError as error:
        raise ValueError(
            "LPIPS regeneration requires the pinned optional Python stack"
        ) from error

    expected = manifest["runtime_profile"]
    actual = {
        "python": platform.python_version(),
        "torch": torch.__version__,
        "torchvision": torchvision.__version__,
        "numpy": numpy.__version__,
        "platform": normalized_platform(),
    }
    if actual != expected:
        raise ValueError(f"LPIPS runtime drifted: expected={expected}, actual={actual}")

    metric = manifest["metric_profile"]
    lpips_root = Path(lpips.__file__).resolve().parent
    metadata_files = list(
        lpips_root.parent.glob("lpips-*.dist-info/METADATA")
    )
    if len(metadata_files) != 1:
        raise ValueError("LPIPS distribution metadata is ambiguous")
    version_lines = [
        line.removeprefix("Version: ")
        for line in metadata_files[0].read_text(encoding="utf-8").splitlines()
        if line.startswith("Version: ")
    ]
    if version_lines != [metric["lpips_version"]]:
        raise ValueError("LPIPS package version drifted")
    calibration = (
        lpips_root
        / "weights"
        / f"v{metric['calibration_version']}"
        / f"{metric['network']}.pth"
    )
    if sha256_file(calibration) != metric["calibration_weights_sha256"]:
        raise ValueError("LPIPS calibration weights drifted")
    backbone = (
        Path(torch.hub.get_dir())
        / "checkpoints"
        / metric["backbone_filename"]
    )
    if not backbone.is_file():
        raise ValueError(
            "LPIPS backbone is absent from the offline Torch cache; "
            "implicit download is forbidden"
        )
    if sha256_file(backbone) != metric["backbone_weights_sha256"]:
        raise ValueError("LPIPS backbone weights drifted")

    torch.set_num_threads(metric["thread_count"])
    torch.set_num_interop_threads(metric["thread_count"])
    torch.manual_seed(0)
    torch.use_deterministic_algorithms(True)
    model = lpips.LPIPS(
        net=metric["network"],
        version=metric["calibration_version"],
        lpips=True,
        pretrained=True,
        pnet_rand=False,
        eval_mode=True,
        verbose=False,
    ).cpu().eval()
    return numpy, torch, model


def srgb_to_linear(values: Any, numpy: Any) -> Any:
    return numpy.where(
        values <= 0.04045,
        values / 12.92,
        ((values + 0.055) / 1.055) ** 2.4,
    )


def linear_to_srgb(values: Any, numpy: Any) -> Any:
    return numpy.where(
        values <= 0.0031308,
        values * 12.92,
        1.055 * (values ** (1.0 / 2.4)) - 0.055,
    )


def displayed_tensor(
    rgba: Any, background: dict[str, int], numpy: Any, torch: Any
) -> tuple[Any, str, bytes]:
    rgba64 = rgba.astype(numpy.float64).reshape((-1, 4))
    encoded_rgb = rgba64[:, :3] / 255.0
    alpha = rgba64[:, 3:4] / 255.0
    background_encoded = numpy.array(
        [background["red"], background["green"], background["blue"]],
        dtype=numpy.float64,
    ) / 255.0
    displayed_linear = srgb_to_linear(encoded_rgb, numpy) * alpha + (
        srgb_to_linear(background_encoded, numpy) * (1.0 - alpha)
    )
    displayed_encoded = linear_to_srgb(displayed_linear, numpy)
    srgb8 = numpy.rint(numpy.clip(displayed_encoded, 0.0, 1.0) * 255.0).astype(
        numpy.uint8
    )
    normalized = srgb8.astype(numpy.float32) / 127.5 - 1.0
    tensor = torch.from_numpy(normalized.T.copy())
    encoded = srgb8.tobytes()
    return tensor, sha256_bytes(encoded), encoded


def render_raster(
    adapter: Path, source: Path, width: int, height: int, numpy: Any
) -> Any:
    rendered = run_json(
        [str(adapter), str(source), str(width), str(height)], {0}
    )
    if rendered.get("width") != width or rendered.get("height") != height:
        raise ValueError("LPIPS renderer adapter dimensions drifted")
    rgba = rendered.get("rgba")
    if not isinstance(rgba, list) or len(rgba) != width * height * 4:
        raise ValueError("LPIPS renderer adapter pixel count drifted")
    if any(not isinstance(value, int) or not 0 <= value <= 255 for value in rgba):
        raise ValueError("LPIPS renderer adapter emitted an invalid channel")
    return numpy.array(rgba, dtype=numpy.uint8)


def scalar_values(value: Any) -> list[float]:
    return [float(item) for item in value.detach().cpu().reshape(-1).tolist()]


def ordinal_pair_evaluation(
    cases: list[dict[str, Any]], profile_id: str
) -> dict[str, Any]:
    selected = [
        {
            "case_id": case["case_id"],
            "tier": case["human_tier"],
            "score": next(
                observation["forward_distance"]
                for observation in case["observations"]
                if observation["profile_id"] == profile_id
            ),
        }
        for case in cases
    ]
    concordant = 0
    inverted = 0
    tied = 0
    examples = []
    for index, left in enumerate(selected):
        for right in selected[index + 1 :]:
            left_tier = TIER_ORDER.index(left["tier"])
            right_tier = TIER_ORDER.index(right["tier"])
            if left_tier == right_tier:
                continue
            expected = 1 if left_tier > right_tier else -1
            delta = left["score"] - right["score"]
            actual = 0 if abs(delta) <= 1e-12 else (1 if delta > 0 else -1)
            if actual == expected:
                concordant += 1
            elif actual == 0:
                tied += 1
            else:
                inverted += 1
                higher = left if expected == 1 else right
                lower = right if expected == 1 else left
                examples.append(
                    {
                        "higher_tier_case_id": higher["case_id"],
                        "lower_tier_case_id": lower["case_id"],
                        "higher_tier_distance": higher["score"],
                        "lower_tier_distance": lower["score"],
                    }
                )
    total = concordant + inverted + tied
    return {
        "different_tier_pair_count": total,
        "concordant_pair_count": concordant,
        "inverted_pair_count": inverted,
        "tied_pair_count": tied,
        "pair_accuracy": None if total == 0 else concordant / total,
        "inversion_examples": examples[:8],
    }


def observation(case: dict[str, Any], profile_id: str) -> dict[str, Any]:
    return next(
        value
        for value in case["observations"]
        if value["profile_id"] == profile_id
    )


def sensitivity_summary(
    cases: list[dict[str, Any]], pairs: list[tuple[str, str]]
) -> dict[str, float]:
    deltas = []
    for case in cases:
        for left, right in pairs:
            deltas.append(
                abs(
                    observation(case, left)["forward_distance"]
                    - observation(case, right)["forward_distance"]
                )
            )
    return {
        "absolute_delta_mean": sum(deltas) / len(deltas),
        "absolute_delta_maximum": max(deltas),
    }


def result_summary(
    cases: list[dict[str, Any]], manifest: dict[str, Any]
) -> dict[str, Any]:
    profile_ids = [profile["id"] for profile in manifest["render_profiles"]]
    zero_by_profile = {}
    for profile_id in profile_ids:
        zero_by_profile[profile_id] = [
            case["case_id"]
            for case in cases
            if case["human_tier"] != "none"
            and abs(observation(case, profile_id)["forward_distance"])
            <= manifest["metric_profile"]["identity_absolute_tolerance"]
        ]
    symmetry_gaps = [
        value["symmetry_absolute_gap"]
        for case in cases
        for value in case["observations"]
    ]
    tier_counts = Counter(case["human_tier"] for case in cases)
    return {
        "case_count": len(cases),
        "profile_count": len(profile_ids),
        "human_tier_case_counts": {
            tier: tier_counts[tier] for tier in TIER_ORDER
        },
        "human_non_none_zero_distance_case_ids_by_profile": zero_by_profile,
        "maximum_symmetry_absolute_gap": max(symmetry_gaps),
        "scale_sensitivity": sensitivity_summary(
            cases,
            [
                ("scale4-white", "scale16-white"),
                ("scale4-black", "scale16-black"),
            ],
        ),
        "background_sensitivity": sensitivity_summary(
            cases,
            [
                ("scale4-white", "scale4-black"),
                ("scale16-white", "scale16-black"),
            ],
        ),
        "ordering_by_profile": {
            profile_id: ordinal_pair_evaluation(cases, profile_id)
            for profile_id in profile_ids
        },
    }


def build_results(
    adapter: Path, cli: Path, manifest: dict[str, Any], corpus: dict[str, Any],
    annotations: dict[str, Any]
) -> dict[str, Any]:
    numpy, torch, model = require_optional_runtime(manifest)
    corpus_by_id = {case["id"]: case for case in corpus["cases"]}
    labels_by_id = {case["case_id"]: case for case in annotations["cases"]}
    scales = sorted(
        {profile["output_scale"] for profile in manifest["render_profiles"]}
    )
    rendered: dict[tuple[str, int, str], Any] = {}
    reports = {}
    for case_id in manifest["case_ids"]:
        case = corpus_by_id[case_id]
        reports[case_id] = run_json(
            [
                str(cli),
                str(checked_source(case["before"])),
                str(checked_source(case["after"])),
                "--width",
                str(case["viewport"]["width"]),
                "--height",
                str(case["viewport"]["height"]),
                "--agent-json",
            ],
            {0, 1},
        )
        for scale in scales:
            width = case["viewport"]["width"] * scale
            height = case["viewport"]["height"] * scale
            for side in ("before", "after"):
                rendered[(case_id, scale, side)] = render_raster(
                    adapter,
                    checked_source(case[side]),
                    width,
                    height,
                    numpy,
                )

    cases = [
        {
            "case_id": case_id,
            "human_tier": labels_by_id[case_id]["main_visual_changes"][0][
                "relative_importance"
            ]["tier"],
            "source_pair_sha256": source_pair_hash(corpus_by_id[case_id]),
            "production_analysis_status": reports[case_id]["analysis_status"],
            "production_renderer_capability_gaps": reports[case_id][
                "renderer_capability_gaps"
            ],
            "observations": [],
        }
        for case_id in manifest["case_ids"]
    ]

    with torch.inference_mode():
        for profile in manifest["render_profiles"]:
            before_tensors = []
            after_tensors = []
            before_hashes = []
            after_hashes = []
            before_bytes = []
            after_bytes = []
            scale = profile["output_scale"]
            for case_id in manifest["case_ids"]:
                left, left_hash, left_bytes = displayed_tensor(
                    rendered[(case_id, scale, "before")],
                    profile["background"],
                    numpy,
                    torch,
                )
                right, right_hash, right_bytes = displayed_tensor(
                    rendered[(case_id, scale, "after")],
                    profile["background"],
                    numpy,
                    torch,
                )
                width = corpus_by_id[case_id]["viewport"]["width"] * scale
                height = corpus_by_id[case_id]["viewport"]["height"] * scale
                before_tensors.append(left.reshape((3, height, width)))
                after_tensors.append(right.reshape((3, height, width)))
                before_hashes.append(left_hash)
                after_hashes.append(right_hash)
                before_bytes.append(left_bytes)
                after_bytes.append(right_bytes)
            before_batch = torch.stack(before_tensors)
            after_batch = torch.stack(after_tensors)
            forward = model(before_batch, after_batch)
            repeated = model(before_batch, after_batch)
            reverse = model(after_batch, before_batch)
            identity = model(before_batch, before_batch)
            forward_values = scalar_values(forward)
            repeated_values = scalar_values(repeated)
            reverse_values = scalar_values(reverse)
            identity_values = scalar_values(identity)
            repeat_bytes = repeated.detach().cpu().numpy().tobytes()
            forward_bytes = forward.detach().cpu().numpy().tobytes()
            repeat_bit_identical = repeat_bytes == forward_bytes
            for index, case in enumerate(cases):
                raw_before = rendered[(case["case_id"], scale, "before")]
                raw_after = rendered[(case["case_id"], scale, "after")]
                case["observations"].append(
                    {
                        "profile_id": profile["id"],
                        "output_width": before_tensors[index].shape[2],
                        "output_height": before_tensors[index].shape[1],
                        "raw_rgba8_equal": bool(numpy.array_equal(raw_before, raw_after)),
                        "displayed_srgb8_equal": before_bytes[index]
                        == after_bytes[index],
                        "before_displayed_srgb8_sha256": before_hashes[index],
                        "after_displayed_srgb8_sha256": after_hashes[index],
                        "forward_distance": forward_values[index],
                        "reverse_distance": reverse_values[index],
                        "symmetry_absolute_gap": abs(
                            forward_values[index] - reverse_values[index]
                        ),
                        "repeated_forward_distance": repeated_values[index],
                        "repeat_bit_identical": repeat_bit_identical
                        and forward_values[index] == repeated_values[index],
                        "identity_distance": identity_values[index],
                    }
                )

    return {
        "schema_version": "svgdiff-lpips-experiment-results/1",
        "input_version": manifest["schema_version"],
        "annotation_review_status": annotations["review_status"],
        "canonical_report_evidence": False,
        "accepted_role": "optional_offline_learned_perceptual_experiment",
        "production_integration": "rejected",
        "production_rejection_reasons": [
            "canonical_raster_is_below_the_network_input_scale",
            "scores_depend_on_output_scale_and_background",
            "renderer_coverage_gaps_can_create_false_identity",
            "learned_pooling_does_not_preserve_exact_svg_semantics",
            "scalar_scores_do_not_localize_or_attribute_causes",
            "human_importance_order_contains_inversions_and_ties",
            "runtime_and_weight_dependencies_are_not_portable_contracts",
        ],
        "raster_source_id": manifest["raster_source_id"],
        "production_renderer_id": manifest["production_renderer_id"],
        "renderer_conformance_profile_id": manifest[
            "renderer_conformance_profile_id"
        ],
        "evaluator_implementation_sha256": evaluator_implementation_hash(),
        "renderer_adapter_implementation_sha256": renderer_adapter_hash(),
        "metric_profile": manifest["metric_profile"],
        "runtime_profile": manifest["runtime_profile"],
        "render_profiles": manifest["render_profiles"],
        "summary": result_summary(cases, manifest),
        "cases": cases,
    }


def require_finite_number(value: Any, label: str) -> float:
    if not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"invalid LPIPS number: {label}")
    return float(value)


def validate_results(
    results: dict[str, Any], manifest: dict[str, Any], corpus: dict[str, Any],
    annotations: dict[str, Any]
) -> None:
    if results["schema_version"] != "svgdiff-lpips-experiment-results/1":
        raise ValueError("LPIPS result schema drifted")
    if results["input_version"] != manifest["schema_version"]:
        raise ValueError("LPIPS result input identity drifted")
    if results["canonical_report_evidence"] is not False:
        raise ValueError("LPIPS result became canonical evidence")
    if results["accepted_role"] != "optional_offline_learned_perceptual_experiment":
        raise ValueError("LPIPS accepted role drifted")
    if results["production_integration"] != "rejected":
        raise ValueError("LPIPS production decision drifted")
    if results["annotation_review_status"] != annotations["review_status"]:
        raise ValueError("LPIPS annotation review status drifted")
    if results["metric_profile"] != manifest["metric_profile"]:
        raise ValueError("LPIPS metric profile drifted")
    if results["runtime_profile"] != manifest["runtime_profile"]:
        raise ValueError("LPIPS runtime profile drifted")
    if results["render_profiles"] != manifest["render_profiles"]:
        raise ValueError("LPIPS render profiles drifted")
    if results["evaluator_implementation_sha256"] != evaluator_implementation_hash():
        raise ValueError("LPIPS evaluator implementation drifted")
    if results["renderer_adapter_implementation_sha256"] != renderer_adapter_hash():
        raise ValueError("LPIPS renderer adapter implementation drifted")

    corpus_by_id = {case["id"]: case for case in corpus["cases"]}
    labels_by_id = {case["case_id"]: case for case in annotations["cases"]}
    cases = results["cases"]
    if [case["case_id"] for case in cases] != manifest["case_ids"]:
        raise ValueError("LPIPS result case order drifted")
    profile_ids = [profile["id"] for profile in manifest["render_profiles"]]
    tolerance = manifest["metric_profile"]["symmetry_absolute_tolerance"]
    identity_tolerance = manifest["metric_profile"]["identity_absolute_tolerance"]
    for case in cases:
        case_id = case["case_id"]
        expected_tier = labels_by_id[case_id]["main_visual_changes"][0][
            "relative_importance"
        ]["tier"]
        if case["human_tier"] != expected_tier:
            raise ValueError(f"{case_id}: human tier drifted")
        if case["source_pair_sha256"] != source_pair_hash(corpus_by_id[case_id]):
            raise ValueError(f"{case_id}: source pair drifted")
        observations = case["observations"]
        if [value["profile_id"] for value in observations] != profile_ids:
            raise ValueError(f"{case_id}: LPIPS profile coverage drifted")
        for value in observations:
            profile_id = value["profile_id"]
            forward = require_finite_number(
                value["forward_distance"], f"{case_id}/{profile_id}/forward"
            )
            reverse = require_finite_number(
                value["reverse_distance"], f"{case_id}/{profile_id}/reverse"
            )
            repeated = require_finite_number(
                value["repeated_forward_distance"],
                f"{case_id}/{profile_id}/repeat",
            )
            identity = require_finite_number(
                value["identity_distance"], f"{case_id}/{profile_id}/identity"
            )
            gap = require_finite_number(
                value["symmetry_absolute_gap"], f"{case_id}/{profile_id}/gap"
            )
            if abs(forward - reverse) != gap or gap > tolerance:
                raise ValueError(f"{case_id}/{profile_id}: LPIPS symmetry failed")
            if not value["repeat_bit_identical"] or forward != repeated:
                raise ValueError(f"{case_id}/{profile_id}: LPIPS repeat drifted")
            if abs(identity) > identity_tolerance:
                raise ValueError(f"{case_id}/{profile_id}: LPIPS identity failed")
            if value["displayed_srgb8_equal"] and abs(forward) > identity_tolerance:
                raise ValueError(f"{case_id}/{profile_id}: equal tensors were nonzero")
            if value["output_width"] not in {64, 256} or value[
                "output_height"
            ] not in {64, 256}:
                raise ValueError(f"{case_id}/{profile_id}: output scale drifted")
            for side in ("before", "after"):
                digest = value[f"{side}_displayed_srgb8_sha256"]
                if not isinstance(digest, str) or len(digest) != 64:
                    raise ValueError(f"{case_id}/{profile_id}: invalid tensor hash")

    summary = result_summary(cases, manifest)
    if results["summary"] != summary:
        raise ValueError("LPIPS result summary drifted")
    false_identity = summary["human_non_none_zero_distance_case_ids_by_profile"]
    if any("embedded-raster-change" not in values for values in false_identity.values()):
        raise ValueError("LPIPS artifact lost the renderer-gap false identity")
    if summary["scale_sensitivity"]["absolute_delta_maximum"] <= 0.0:
        raise ValueError("LPIPS artifact did not measure scale sensitivity")
    if summary["background_sensitivity"]["absolute_delta_maximum"] <= 0.0:
        raise ValueError("LPIPS artifact did not measure background sensitivity")
    if any(
        value["inverted_pair_count"] + value["tied_pair_count"] == 0
        for value in summary["ordering_by_profile"].values()
    ):
        raise ValueError("LPIPS artifact lost tier disagreement evidence")


def encoded_json(value: dict[str, Any]) -> str:
    return json.dumps(value, indent=2, sort_keys=True) + "\n"


def main() -> None:
    args = parse_args()
    manifest, corpus, annotations = load_inputs()
    if args.update:
        results = build_results(
            args.adapter.resolve(),
            args.cli.resolve(),
            manifest,
            corpus,
            annotations,
        )
        validate_results(results, manifest, corpus, annotations)
        RESULTS_PATH.write_text(encoded_json(results), encoding="utf-8")
    else:
        if not RESULTS_PATH.is_file():
            raise ValueError("LPIPS result artifact is missing")
        results = load_json(RESULTS_PATH)
        validate_results(results, manifest, corpus, annotations)
    summary = results["summary"]
    print(
        "LPIPS experiment: "
        f"{summary['case_count']} cases x {summary['profile_count']} profiles, "
        "renderer-gap false identity retained, profile sensitivity measured; "
        "production integration rejected"
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, IndexError, TypeError) as error:
        print(f"LPIPS experiment failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
