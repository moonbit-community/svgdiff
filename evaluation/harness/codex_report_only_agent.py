#!/usr/bin/env python3

import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile

from harness import validate_answer


ROOT = Path(__file__).resolve().parent
PROFILE = ROOT.parent / "language-model-benchmark" / "profile.v1.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one isolated report-only Codex answer.")
    parser.add_argument("--profile", type=Path, default=PROFILE)
    parser.add_argument("--codex", default="codex")
    return parser.parse_args()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def load_task() -> dict:
    try:
        task = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid task JSON: {error}") from error
    require(isinstance(task, dict), "task must be an object")
    require(isinstance(task.get("case_id"), str) and task["case_id"], "task lacks case_id")
    require(task.get("acceptance_version") == "agent-acceptance/1", "task acceptance version mismatch")
    require(isinstance(task.get("prompt"), str) and task["prompt"], "task lacks prompt")
    require(isinstance(task.get("report"), dict), "task lacks Structured Report")
    return task


def event_uses_tool(value: object) -> bool:
    if isinstance(value, dict):
        item_type = value.get("type")
        if isinstance(item_type, str) and item_type in {
            "command_execution",
            "mcp_tool_call",
            "web_search",
            "computer_use",
            "file_change",
        }:
            return True
        return any(event_uses_tool(item) for item in value.values())
    if isinstance(value, list):
        return any(event_uses_tool(item) for item in value)
    return False


def parse_events(stdout: str) -> list[dict]:
    events = []
    for line_number, line in enumerate(stdout.splitlines(), 1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"invalid Codex event JSON at line {line_number}: {error}") from error
        require(isinstance(event, dict), "Codex event must be an object")
        events.append(event)
    require(events, "Codex produced no execution events")
    require(not any(event_uses_tool(event) for event in events), "Codex used a forbidden tool")
    return events


def build_prompt(task: dict) -> str:
    return """You are being evaluated as a text-only consumer of one SVG Diff Structured Report.

Use only the JSON task below. Do not call tools, run commands, browse, inspect files, use memory, or seek any outside context. The report is the complete evidence available to you. Return exactly one JSON object matching the supplied output schema. Enumerate every Atomic Difference and every exact magnitude claim exposed by the report, retain all report-local evidence IDs, and follow the canonical prompt inside the task. Keep free-text descriptions concise.

Normalize the answer as follows:
- coverage.analysis_status is report.analysis_status. coverage.equality_conclusion is not_established unless analysis_status is complete; for a complete report it is different when atomic_differences is nonempty and established otherwise. Include every report Diagnostic ID.
- Emit one differences entry per report.atomic_differences item and cite that item's ID. Do not turn event, region, rendered-outcome, perceptual, Diagnostic, or source values into magnitude_claims.
- For every Atomic Difference, emit all twelve scalar fields under magnitude, even when null: parameter_abs_user_units and parameter_signed_user_units use local_user_units; symmetric_relative uses ratio; parameter_abs_css_px and geometry_displacement_css_px use css_px; parameter_viewport_fraction and geometry_viewport_fraction use viewport_diagonal_fraction; parameter_entity_fraction uses entity_diagonal_fraction; presence_painted_viewport_fraction uses viewport_fraction; raster_changed_pixel_fraction uses pixel_fraction; raster_rgba8_rmse uses rgba8_rmse; raster_linear_premultiplied_rgba_rmse uses linear_premultiplied_rgba_rmse.
- Flatten nonnull magnitude.painted_boundary_displacement fields with their exact JSON values: method_id has null unit; before_sample_count and after_sample_count use boundary_pixel_samples; mean_css_px, p95_css_px, and max_css_px use css_px. When the object is null, emit only magnitude.painted_boundary_displacement with null value and symmetric_nearest_boundary_pixels/v1 unit.
- Flatten nonnull magnitude.painted_coverage_difference fields: method_id has null unit; before_coverage_css_px2, after_coverage_css_px2, absolute_difference_css_px2, and union_coverage_css_px2 use css_px2; fraction uses coverage_union_fraction. When null, emit only magnitude.painted_coverage_difference with null value and symmetric_alpha_coverage_l1_over_union/v1 unit.
- Flatten nonnull magnitude.intrinsic_raster fields: before_width, before_height, after_width, and after_height use intrinsic_pixels; compared_pixels and changed_pixels use pixels; changed_pixel_fraction uses pixel_fraction; rgba8_rmse uses rgba8_rmse; linear_premultiplied_rgba_rmse uses linear_premultiplied_rgba_rmse. When null, emit only magnitude.intrinsic_raster with null value and intrinsic_decoded_raster/v1 unit.
- When magnitude.transform_effect is nonnull, flatten its present fields. kind has null unit; before_x_css_px, before_y_css_px, after_x_css_px, after_y_css_px, delta_x_css_px, delta_y_css_px, and norm_css_px use css_px; before_degrees, after_degrees, signed_delta_degrees, and abs_delta_degrees use degrees; before_x, before_y, after_x, after_y, and max_abs_delta use scale_factor; before_matrix and after_matrix use affine_matrix_coefficients; before_determinant and after_determinant use determinant.
- When top-level parameter_delta_css_px is nonnull, emit parameter_delta_css_px with css_px. When presence_magnitude is nonnull, flatten its present fields: affected_entity_count uses entities; bounds_area_css_px2 and painted_area_css_px2 use css_px2; bounds_viewport_fraction and painted_viewport_fraction use viewport_area_fraction.
- Every normalized claim with a nonnull value has measured status. Every normalized claim with null value has not_computed status. Preserve the exact JSON value and exact unit spelling above.
- region_ids are the IDs in the containing event's difference_regions. possible_cause_changed_fact_ids are the union of those regions' candidate_changed_fact_ids. Use sound_overapproximation only when every cited region has that guarantee; use not_established for any other nonempty region set and not_applicable when there are no regions. Include the regions' cause-envelope Diagnostic IDs.
- Emit one main_changes entry for every impact_assessment.frontier_group, retaining that group's event_ids and atomic_difference_ids without inventing an order inside a group.

TASK JSON:
""" + json.dumps(task, sort_keys=True, separators=(",", ":"))


def opaque_case_id() -> str:
    return "case-" + secrets.token_hex(8)


def run() -> None:
    args = parse_args()
    profile = json.loads(args.profile.read_text(encoding="utf-8"))
    require(profile.get("schema_version") == "svgdiff-language-model-benchmark-profile/1", "profile identity mismatch")
    task = load_task()
    model_task = {**task, "case_id": opaque_case_id()}
    timeout = profile.get("per_case_timeout_seconds")
    require(isinstance(timeout, int) and timeout > 0, "invalid profile timeout")
    disabled_features = profile.get("disabled_codex_features")
    require(
        isinstance(disabled_features, list)
        and disabled_features
        and all(isinstance(feature, str) and feature for feature in disabled_features),
        "invalid disabled Codex feature list",
    )
    schema = ROOT / "codex-agent-answer.schema.json"

    with tempfile.TemporaryDirectory(prefix="svgdiff-codex-agent-") as directory:
        temporary_root = Path(directory)
        working_directory = temporary_root / "work"
        codex_home = temporary_root / "codex-home"
        working_directory.mkdir()
        codex_home.mkdir()
        configured_home = Path(
            os.environ.get("CODEX_HOME", Path.home() / ".codex")
        )
        auth_path = configured_home / "auth.json"
        require(auth_path.is_file(), f"Codex authentication not found at {auth_path}")
        shutil.copy2(auth_path, codex_home / "auth.json")
        answer_path = temporary_root / "answer.json"
        command = [
            args.codex,
            "exec",
            "-",
            "--json",
            "--color",
            "never",
            "--ephemeral",
            "--ignore-user-config",
            "--ignore-rules",
            "--strict-config",
            "--skip-git-repo-check",
            "--sandbox",
            profile["sandbox"],
            "--cd",
            str(working_directory),
            "--model",
            profile["model"],
            "--config",
            f'model_reasoning_effort="{profile["reasoning_effort"]}"',
            "--output-schema",
            str(schema),
            "--output-last-message",
            str(answer_path),
        ]
        for feature in disabled_features:
            command.extend(["--disable", feature])
        try:
            result = subprocess.run(
                command,
                input=build_prompt(model_task),
                text=True,
                capture_output=True,
                timeout=timeout,
                check=False,
                env={
                    **os.environ,
                    "CODEX_HOME": str(codex_home),
                    "NO_COLOR": "1",
                },
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"Codex timed out after {timeout} seconds") from error
        if result.returncode != 0:
            diagnostic = "\n".join(
                part
                for part in (
                    result.stderr.strip()[-2000:],
                    result.stdout.strip()[-4000:],
                )
                if part
            )
            raise RuntimeError(
                f"Codex exited {result.returncode}: {diagnostic}"
            )
        parse_events(result.stdout)
        require(answer_path.is_file(), "Codex produced no answer artifact")
        try:
            answer = json.loads(answer_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            raise ValueError(f"Codex returned invalid answer JSON: {error}") from error
        validate_answer(answer, model_task["case_id"])
        answer["case_id"] = task["case_id"]
        validate_answer(answer, task["case_id"])
        print(json.dumps(answer, sort_keys=True, separators=(",", ":")))


def main() -> None:
    try:
        run()
    except (OSError, ValueError, RuntimeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
