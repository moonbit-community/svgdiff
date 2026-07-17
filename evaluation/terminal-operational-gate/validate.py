#!/usr/bin/env python3

import argparse
import json
from pathlib import Path
import sys


EXPECTED_OBLIGATIONS = {
    "deterministic",
    "installable",
    "hostile_input_security",
    "versioned",
    "supported_environment_reproducibility",
}
EXPECTED_ENVIRONMENTS = {
    "linux-x64": ("ubuntu-24.04", "X64", "svgdiff"),
    "windows-x64": ("windows-2025", "X64", "svgdiff.exe"),
    "macos-arm64": ("macos-15", "ARM64", "svgdiff"),
}
EXPECTED_NON_GUARANTEES = {
    "not_process_or_multi_tenant_isolation",
    "not_a_hard_deadline_or_peak_memory_limit_for_arbitrary_inputs",
    "not_exhaustive_or_coverage_guided_fuzz_proof",
    "not_safe_for_an_unauthenticated_hostile_upload_service",
    "not_signed_notarized_or_slsa_attested",
    "not_bit_identical_executables_or_cross_toolchain_reproducibility",
}
EXPECTED_SUITES = {
    "sh scripts/test-report-determinism.sh",
    "sh scripts/test-cross-platform-determinism.sh",
    "sh scripts/test-install.sh",
    "sh scripts/test-release-bundle.sh",
    "sh scripts/test-module-package.sh",
    "sh scripts/test-versioning.sh",
    "sh scripts/test-compatibility.sh",
    "sh scripts/test-cli.sh",
    "sh scripts/test-fuzz-smoke.sh",
    "sh scripts/test-adversarial.sh",
    "sh scripts/test-html-security.sh",
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def nonempty_strings(value, field: str) -> None:
    require(isinstance(value, list) and value, f"{field} must be a nonempty array")
    require(
        all(isinstance(item, str) and item for item in value),
        f"{field} must contain nonempty strings",
    )
    require(len(value) == len(set(value)), f"{field} must not contain duplicates")


def matrix_block(platform: str, runner: str, arch: str, executable: str | None) -> str:
    lines = [
        f"          - platform: {platform}",
        f"            runner: {runner}",
        f"            expected_arch: {arch}",
    ]
    if executable is not None:
        lines.append(f"            executable: {executable}")
    return "\n".join(lines)


def validate_workflows(ci: str, release: str, environments: dict, bindings: dict) -> None:
    for platform, item in environments.items():
        runner, arch, executable = EXPECTED_ENVIRONMENTS[platform]
        require(
            matrix_block(platform, runner, arch, None) in ci,
            f"CI matrix binding missing: {platform}",
        )
        require(
            matrix_block(platform, runner, arch, executable) in release,
            f"release matrix binding missing: {platform}",
        )
        require(item == (runner, arch, executable), f"environment mismatch: {platform}")

    required_ci = (
        "name: Determinism bundle (${{ matrix.platform }})",
        "name: Compare cross-platform determinism bundles",
        "python-version: \"3.13\"",
        bindings["native_release_executable"],
        "sh scripts/test-fuzz-smoke.sh",
        "--platform linux-x64=",
        "--platform windows-x64=",
        "--platform macos-arm64=",
    )
    for token in required_ci:
        require(token in ci, f"CI workflow binding missing: {token}")

    required_release = (
        "name: Build release (${{ matrix.platform }})",
        "name: Publish GitHub Release",
        "sh scripts/check-release-tag.sh",
        "sh scripts/test-release-bundle.sh",
        "sh scripts/package-release.sh --archive",
        "python evaluation/determinism/compare_platforms.py",
        "sha256sum svgdiff-*.tar.gz >SHA256SUMS",
        "gh release create",
        "test \"$(jq -r '.source.dirty'",
        "test \"$(jq -r '.source.revision'",
    )
    for token in required_release:
        require(token in release, f"release workflow binding missing: {token}")


def validate(root: Path, manifest: dict, ci_override: Path | None, release_override: Path | None) -> None:
    require(
        manifest.get("schema_version") == "svgdiff-terminal-operational-gate/1",
        "gate identity mismatch",
    )
    require(
        manifest.get("claim_scope")
        == "documented_local_product_and_supported_native_matrix",
        "claim scope mismatch",
    )

    obligations = manifest.get("obligations")
    require(isinstance(obligations, list), "obligations must be an array")
    by_id = {item.get("id"): item for item in obligations if isinstance(item, dict)}
    require(set(by_id) == EXPECTED_OBLIGATIONS, "obligation inventory mismatch")
    require(len(by_id) == len(obligations), "obligation IDs must be unique")
    for identifier, item in by_id.items():
        for field in ("controls", "authorities", "suites"):
            values = item.get(field)
            nonempty_strings(values, f"{identifier}.{field}")
            if field in ("authorities", "suites"):
                for path in values:
                    require((root / path).is_file(), f"{identifier}: missing {field} path {path}")

    environment_items = manifest.get("supported_environments")
    require(isinstance(environment_items, list), "supported_environments must be an array")
    environments = {
        item.get("platform"): (
            item.get("runner"),
            item.get("expected_arch"),
            item.get("executable"),
        )
        for item in environment_items
        if isinstance(item, dict)
    }
    require(set(environments) == set(EXPECTED_ENVIRONMENTS), "environment inventory mismatch")
    require(len(environments) == len(environment_items), "environment IDs must be unique")

    non_guarantees = manifest.get("security_non_guarantees")
    nonempty_strings(non_guarantees, "security_non_guarantees")
    require(set(non_guarantees) == EXPECTED_NON_GUARANTEES, "security boundary mismatch")

    bindings = manifest.get("workflow_bindings")
    require(isinstance(bindings, dict), "workflow_bindings missing")
    require(
        bindings.get("native_release_executable")
        == "_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe",
        "native release executable binding mismatch",
    )
    require(
        bindings.get("determinism_bundle_version") == "svgdiff-determinism-bundle/1",
        "determinism bundle identity mismatch",
    )
    require(
        bindings.get("release_provenance_version") == "svgdiff-release-provenance/2",
        "release provenance identity mismatch",
    )
    ci_path = ci_override or root / bindings.get("ci", "")
    release_path = release_override or root / bindings.get("release", "")
    validate_workflows(
        ci_path.read_text(encoding="utf-8"),
        release_path.read_text(encoding="utf-8"),
        environments,
        bindings,
    )

    suites = manifest.get("suite_commands")
    nonempty_strings(suites, "suite_commands")
    require(set(suites) == EXPECTED_SUITES, "suite inventory mismatch")
    for command in suites:
        shell, path = command.split()
        require(shell == "sh" and (root / path).is_file(), f"invalid suite command: {command}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate terminal operational readiness.")
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--ci-workflow", type=Path)
    parser.add_argument("--release-workflow", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent.parent
    try:
        manifest = load_json(args.manifest)
        require(isinstance(manifest, dict), "manifest must contain a JSON object")
        validate(root, manifest, args.ci_workflow, args.release_workflow)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1) from error
    print("Terminal operational readiness gate: passed")


if __name__ == "__main__":
    main()
