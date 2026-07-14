#!/usr/bin/env python3

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


BUNDLE_SCHEMA = "svgdiff-determinism-bundle/1"
RESULT_SCHEMA = "svgdiff-cross-platform-determinism-results/1"
SUPPORTED_PLATFORMS = {"linux-x64", "windows-x64", "macos-arm64"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare canonical Structured Report bundles across platforms."
    )
    parser.add_argument(
        "--platform",
        action="append",
        required=True,
        metavar="KEY=DIR",
        help="platform key and bundle directory; repeat for every supported platform",
    )
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def parse_platforms(values: list[str]) -> dict[str, Path]:
    platforms: dict[str, Path] = {}
    for value in values:
        key, separator, raw_path = value.partition("=")
        if not separator or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", key):
            raise ValueError(f"invalid platform argument: {value!r}")
        if key in platforms:
            raise ValueError(f"duplicate platform key: {key}")
        path = Path(raw_path).resolve()
        if not path.is_dir():
            raise ValueError(f"missing platform bundle: {key}={path}")
        platforms[key] = path
    if set(platforms) != SUPPORTED_PLATFORMS:
        missing = sorted(SUPPORTED_PLATFORMS - set(platforms))
        extra = sorted(set(platforms) - SUPPORTED_PLATFORMS)
        raise ValueError(
            f"platform matrix mismatch: missing={missing!r} extra={extra!r}"
        )
    return platforms


def checked_relative_path(bundle: Path, raw_path: Any) -> tuple[str, Path]:
    if not isinstance(raw_path, str) or not raw_path:
        raise ValueError(f"{bundle}: report path must be a nonempty string")
    relative = Path(raw_path)
    resolved = (bundle / relative).resolve()
    if relative.is_absolute() or bundle not in resolved.parents:
        raise ValueError(f"{bundle}: unsafe report path {raw_path!r}")
    return relative.as_posix(), resolved


def validate_bundle(bundle: Path) -> tuple[list[str], dict[str, bytes]]:
    manifest_path = bundle / "bundle.v1.json"
    if not manifest_path.is_file():
        raise ValueError(f"{bundle}: missing bundle.v1.json")
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    if manifest.get("schema_version") != BUNDLE_SCHEMA:
        raise ValueError(f"{bundle}: unsupported bundle schema")
    reports = manifest.get("reports")
    if not isinstance(reports, list) or not reports:
        raise ValueError(f"{bundle}: bundle has no reports")

    declared_paths = []
    files = {"bundle.v1.json": manifest_bytes}
    identities = set()
    for report in reports:
        if not isinstance(report, dict):
            raise ValueError(f"{bundle}: report entry must be an object")
        case_id = report.get("case_id")
        mode = report.get("mode")
        identity = (case_id, mode)
        if (
            not isinstance(case_id, str)
            or not case_id
            or mode not in {"pretty", "compact"}
            or identity in identities
        ):
            raise ValueError(f"{bundle}: invalid or duplicate report identity {identity!r}")
        identities.add(identity)
        relative, resolved = checked_relative_path(bundle, report.get("path"))
        if relative in files or not resolved.is_file():
            raise ValueError(f"{bundle}: missing or duplicate report path {relative!r}")
        encoded = resolved.read_bytes()
        digest = hashlib.sha256(encoded).hexdigest()
        if report.get("sha256") != digest:
            raise ValueError(f"{bundle}: digest mismatch for {relative}")
        declared_paths.append(relative)
        files[relative] = encoded

    actual_paths = {
        path.relative_to(bundle).as_posix() for path in bundle.rglob("*") if path.is_file()
    }
    expected_paths = set(files)
    if actual_paths != expected_paths:
        missing = sorted(expected_paths - actual_paths)
        extra = sorted(actual_paths - expected_paths)
        raise ValueError(f"{bundle}: inventory mismatch missing={missing!r} extra={extra!r}")
    return sorted(files), files


def bundle_digest(paths: list[str], files: dict[str, bytes]) -> str:
    digest = hashlib.sha256()
    for path in paths:
        digest.update(path.encode("utf-8"))
        digest.update(b"\0")
        digest.update(files[path])
        digest.update(b"\0")
    return digest.hexdigest()


def main() -> None:
    args = parse_args()
    platforms = parse_platforms(args.platform)
    loaded = {key: validate_bundle(path) for key, path in platforms.items()}
    reference = sorted(platforms)[0]
    reference_paths, reference_files = loaded[reference]
    for key in sorted(platforms):
        paths, files = loaded[key]
        if paths != reference_paths:
            raise ValueError(
                f"platform inventory differs: reference={reference}, platform={key}"
            )
        for path in reference_paths:
            if files[path] != reference_files[path]:
                raise ValueError(
                    f"platform bytes differ: reference={reference}, platform={key}, file={path}"
                )

    output = {
        "schema_version": RESULT_SCHEMA,
        "platforms": sorted(platforms),
        "reference_platform": reference,
        "file_count": len(reference_paths),
        "bundle_sha256": bundle_digest(reference_paths, reference_files),
        "status": "passed",
    }
    encoded = json.dumps(output, indent=2, sort_keys=True) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(
        f"Cross-platform determinism: {len(platforms)} platforms, "
        f"{len(reference_paths)} files, byte-identical"
    )


if __name__ == "__main__":
    main()
