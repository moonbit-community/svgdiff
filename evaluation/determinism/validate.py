#!/usr/bin/env python3

import argparse
import copy
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "evaluation/determinism/manifest.v1.json"
REQUIRED_CATEGORIES = {
    "equivalent",
    "changed",
    "inserted",
    "deleted",
    "resource-mediated",
    "unsupported",
    "multi-event",
    "non-default-viewport",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate deterministic reports and report-local references."
    )
    parser.add_argument("--cli", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH)
    parser.add_argument(
        "--bundle",
        type=Path,
        help="write platform-neutral canonical report bytes for later comparison",
    )
    return parser.parse_args()


def checked_source(relative_path: str) -> Path:
    source = (ROOT / relative_path).resolve()
    if ROOT not in source.parents or not source.is_file():
        raise ValueError(f"unsafe or missing determinism source: {relative_path}")
    return source


def run_report(cli: Path, case: dict[str, Any], compact: bool) -> bytes:
    command = [
        str(cli),
        str(checked_source(case["before"])),
        str(checked_source(case["after"])),
        "--width",
        str(case["viewport"]["width"]),
        "--height",
        str(case["viewport"]["height"]),
        *case.get("cli_args", []),
    ]
    if compact:
        command.append("--agent-json")
    result = subprocess.run(command, check=False, capture_output=True)
    if result.returncode != 0 or result.stderr:
        raise ValueError(
            f"{case['id']}: CLI failed with status {result.returncode}: "
            f"{result.stderr.decode(errors='replace')!r}"
        )
    return result.stdout


def require_reference_list(
    owner: str, field: str, references: Any, targets: set[str]
) -> None:
    if not isinstance(references, list) or any(
        not isinstance(reference, str) or not reference for reference in references
    ):
        raise ValueError(f"{owner}.{field}: references must be nonempty strings")
    if len(references) != len(set(references)):
        raise ValueError(f"{owner}.{field}: duplicate report-local reference")
    missing = [reference for reference in references if reference not in targets]
    if missing:
        raise ValueError(f"{owner}.{field}: dangling references {missing!r}")


def validate_report_local_ids(report: dict[str, Any]) -> dict[str, int]:
    objects: list[tuple[str, dict[str, Any]]] = []
    for kind, field in (
        ("subject_alignment", "subject_alignments"),
        ("changed_fact", "changed_facts"),
        ("atomic_difference", "atomic_differences"),
        ("visual_event", "events"),
        ("diagnostic", "diagnostics"),
    ):
        objects.extend((kind, item) for item in report[field])
    objects.extend(
        ("difference_region", region)
        for event in report["events"]
        for region in event["difference_regions"]
    )

    owners: dict[str, str] = {}
    ids_by_kind: dict[str, set[str]] = {}
    for kind, item in objects:
        identifier = item.get("id")
        if not isinstance(identifier, str) or not identifier:
            raise ValueError(f"{kind}: report-local ID must be a nonempty string")
        if identifier in owners:
            raise ValueError(
                f"duplicate report-local ID {identifier!r}: "
                f"{owners[identifier]} and {kind}"
            )
        owners[identifier] = kind
        ids_by_kind.setdefault(kind, set()).add(identifier)

    alignments_by_id = {
        alignment["id"]: alignment for alignment in report["subject_alignments"]
    }
    if any(
        alignment.get("subject_role") not in {"entity", "resource"}
        for alignment in alignments_by_id.values()
    ):
        raise ValueError("every Subject Alignment must declare a valid role")
    alignment_ids = ids_by_kind.get("subject_alignment", set())
    fact_ids = ids_by_kind.get("changed_fact", set())
    difference_ids = ids_by_kind.get("atomic_difference", set())
    diagnostic_ids = ids_by_kind.get("diagnostic", set())

    for difference in report["atomic_differences"]:
        owner = difference["id"]
        alignment_id = difference["subject_alignment_id"]
        if alignment_id is not None:
            require_reference_list(
                owner, "subject_alignment_id", [alignment_id], alignment_ids
            )
        if difference.get("subject_role") == "resource" and (
            alignment_id is None
            or alignments_by_id[alignment_id]["subject_role"] != "resource"
        ):
            raise ValueError(
                f"{owner}: resource difference lacks a resource-role alignment"
            )
        require_reference_list(
            owner, "changed_fact_ids", difference["changed_fact_ids"], fact_ids
        )
        require_reference_list(
            owner,
            "computed_relation.diagnostic_ids",
            difference["computed_relation"]["diagnostic_ids"],
            diagnostic_ids,
        )

    event_membership = {identifier: 0 for identifier in difference_ids}
    for event in report["events"]:
        require_reference_list(
            event["id"],
            "atomic_difference_ids",
            event["atomic_difference_ids"],
            difference_ids,
        )
        for identifier in event["atomic_difference_ids"]:
            event_membership[identifier] += 1
        for region in event["difference_regions"]:
            envelope = region["cause_envelope"]
            require_reference_list(
                region["id"],
                "cause_envelope.candidate_changed_fact_ids",
                envelope["candidate_changed_fact_ids"],
                fact_ids,
            )
            require_reference_list(
                region["id"],
                "cause_envelope.diagnostic_ids",
                envelope["diagnostic_ids"],
                diagnostic_ids,
            )
    wrong_membership = {
        identifier: count
        for identifier, count in event_membership.items()
        if count != 1
    }
    if wrong_membership:
        raise ValueError(
            "every Atomic Difference must belong to exactly one Visual Event: "
            f"{wrong_membership!r}"
        )

    for index, row in enumerate(report.get("coverage_matrix", [])):
        require_reference_list(
            f"coverage_matrix[{index}]",
            "diagnostic_ids",
            row["diagnostic_ids"],
            diagnostic_ids,
        )
    for gap in report.get("renderer_capability_gaps", []):
        require_reference_list(
            f"renderer_capability_gap:{gap['capability_id']}",
            "diagnostic_ids",
            gap["diagnostic_ids"],
            diagnostic_ids,
        )

    return {
        kind: len(ids_by_kind.get(kind, set()))
        for kind in (
            "subject_alignment",
            "changed_fact",
            "atomic_difference",
            "visual_event",
            "difference_region",
            "diagnostic",
        )
    }


def validate_causal_fallback(report: dict[str, Any]) -> None:
    fact_ids = {fact["id"] for fact in report["changed_facts"]}
    diagnostic_ids = {diagnostic["id"] for diagnostic in report["diagnostics"]}
    for event in report["events"]:
        event_fact_ids = {
            fact_id
            for difference_id in event["atomic_difference_ids"]
            for difference in report["atomic_differences"]
            if difference["id"] == difference_id
            for fact_id in difference["changed_fact_ids"]
        }
        for region in event["difference_regions"]:
            envelope = region["cause_envelope"]
            candidates = set(envelope["candidate_changed_fact_ids"])
            referenced_diagnostics = set(envelope["diagnostic_ids"])
            if envelope["guarantee"] == "sound_overapproximation":
                if report["analysis_status"] != "complete":
                    raise ValueError(
                        f"{region['id']}: partial report retained causal guarantee"
                    )
                if envelope["coverage"] != "complete":
                    raise ValueError(f"{region['id']}: sound envelope is not complete")
                if envelope["fallback_scope"] == "event_region":
                    if not event_fact_ids or candidates != event_fact_ids:
                        raise ValueError(
                            f"{region['id']}: event-region candidates are contaminated"
                        )
                elif envelope["fallback_scope"] == "comparison":
                    if candidates != fact_ids:
                        raise ValueError(
                            f"{region['id']}: comparison fallback omitted facts"
                        )
                else:
                    raise ValueError(
                        f"{region['id']}: unknown fallback scope "
                        f"{envelope['fallback_scope']!r}"
                    )
            elif envelope["guarantee"] == "not_established":
                if envelope["coverage"] != "partial":
                    raise ValueError(f"{region['id']}: revoked envelope is not partial")
                if envelope["fallback_scope"] != "comparison":
                    raise ValueError(
                        f"{region['id']}: revoked envelope did not widen scope"
                    )
                if candidates != fact_ids:
                    raise ValueError(
                        f"{region['id']}: revoked envelope omitted Changed Facts"
                    )
                if not referenced_diagnostics or not referenced_diagnostics <= diagnostic_ids:
                    raise ValueError(
                        f"{region['id']}: revoked envelope lacks valid Diagnostics"
                    )
            else:
                raise ValueError(
                    f"{region['id']}: unknown causal guarantee "
                    f"{envelope['guarantee']!r}"
                )


def expect_integrity_rejection(report: dict[str, Any], label: str) -> None:
    try:
        validate_report_local_ids(report)
    except ValueError:
        return
    raise ValueError(f"integrity negative control unexpectedly accepted: {label}")


def expect_causal_rejection(report: dict[str, Any], label: str) -> None:
    try:
        validate_causal_fallback(report)
    except ValueError:
        return
    raise ValueError(f"causal negative control unexpectedly accepted: {label}")


def validate_manifest(manifest: dict[str, Any]) -> tuple[list[dict[str, Any]], int]:
    if manifest.get("schema_version") != "svgdiff-determinism-corpus/1":
        raise ValueError("unsupported determinism manifest schema")
    repetitions = manifest.get("repetitions")
    if not isinstance(repetitions, int) or repetitions < 2:
        raise ValueError("determinism repetitions must be an integer of at least two")
    cases = manifest.get("cases")
    if not isinstance(cases, list) or not cases:
        raise ValueError("determinism manifest has no cases")
    ids = [case.get("id") for case in cases]
    if any(not isinstance(identifier, str) or not identifier for identifier in ids):
        raise ValueError("determinism case IDs must be nonempty strings")
    if len(ids) != len(set(ids)):
        raise ValueError("determinism case IDs must be unique")
    if any(not re.fullmatch(r"[a-z0-9][a-z0-9-]*", identifier) for identifier in ids):
        raise ValueError("determinism case IDs must be safe lowercase file stems")
    categories = {
        category
        for case in cases
        for category in case.get("categories", [])
    }
    if categories != REQUIRED_CATEGORIES:
        raise ValueError(
            "determinism categories must exactly cover the contract: "
            f"expected={sorted(REQUIRED_CATEGORIES)!r}, actual={sorted(categories)!r}"
        )
    for case in cases:
        checked_source(case["before"])
        checked_source(case["after"])
        viewport = case.get("viewport", {})
        if any(
            not isinstance(viewport.get(dimension), int)
            or viewport[dimension] <= 0
            for dimension in ("width", "height")
        ):
            raise ValueError(f"{case['id']}: viewport must contain positive integers")
    return cases, repetitions


def main() -> None:
    args = parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    cases, repetitions = validate_manifest(manifest)
    cli = args.cli.resolve()
    if not cli.is_file():
        raise ValueError(f"missing CLI: {cli}")
    bundle = args.bundle.resolve() if args.bundle is not None else None
    if bundle is not None:
        bundle.mkdir(parents=True, exist_ok=True)
        if any(bundle.iterdir()):
            raise ValueError(f"determinism bundle directory is not empty: {bundle}")

    reports: dict[str, dict[str, Any]] = {}
    results = []
    bundled_reports = []
    for case in cases:
        pretty_runs = [run_report(cli, case, False) for _ in range(repetitions)]
        compact_runs = [run_report(cli, case, True) for _ in range(repetitions)]
        if any(encoded != pretty_runs[0] for encoded in pretty_runs[1:]):
            raise ValueError(f"{case['id']}: default JSON is not byte-deterministic")
        if any(encoded != compact_runs[0] for encoded in compact_runs[1:]):
            raise ValueError(f"{case['id']}: compact JSON is not byte-deterministic")
        pretty_report = json.loads(pretty_runs[0])
        compact_report = json.loads(compact_runs[0])
        if pretty_report != compact_report:
            raise ValueError(f"{case['id']}: compact JSON changed report evidence")
        if pretty_report["profile"]["viewport_width"] != case["viewport"]["width"]:
            raise ValueError(f"{case['id']}: report lost viewport width")
        if pretty_report["profile"]["viewport_height"] != case["viewport"]["height"]:
            raise ValueError(f"{case['id']}: report lost viewport height")
        reports[case["id"]] = pretty_report
        validate_causal_fallback(pretty_report)
        if bundle is not None:
            reports_dir = bundle / "reports"
            reports_dir.mkdir(exist_ok=True)
            for mode, encoded in (("pretty", pretty_runs[0]), ("compact", compact_runs[0])):
                relative_path = f"reports/{case['id']}.{mode}.json"
                (bundle / relative_path).write_bytes(encoded)
                bundled_reports.append(
                    {
                        "case_id": case["id"],
                        "mode": mode,
                        "path": relative_path,
                        "sha256": hashlib.sha256(encoded).hexdigest(),
                    }
                )
        results.append(
            {
                "id": case["id"],
                "status": "passed",
                "pretty_sha256": hashlib.sha256(pretty_runs[0]).hexdigest(),
                "compact_sha256": hashlib.sha256(compact_runs[0]).hexdigest(),
                "report_local_id_counts": validate_report_local_ids(pretty_report),
            }
        )

    control = reports["multi-event-ordering"]
    duplicate_id = copy.deepcopy(control)
    duplicate_id["events"][1]["id"] = duplicate_id["events"][0]["id"]
    expect_integrity_rejection(duplicate_id, "duplicate report-local ID")
    dangling_reference = copy.deepcopy(control)
    dangling_reference["events"][0]["atomic_difference_ids"][0] = "diff:missing"
    expect_integrity_rejection(dangling_reference, "dangling report-local reference")
    duplicate_reference = copy.deepcopy(control)
    first_reference = duplicate_reference["events"][0]["atomic_difference_ids"][0]
    duplicate_reference["events"][0]["atomic_difference_ids"].append(first_reference)
    expect_integrity_rejection(duplicate_reference, "duplicate report-local reference")
    wrong_resource_role = copy.deepcopy(reports["resource-gradient-change"])
    entity_alignment_id = next(
        alignment["id"]
        for alignment in wrong_resource_role["subject_alignments"]
        if alignment["subject_role"] == "entity"
    )
    resource_difference = next(
        difference
        for difference in wrong_resource_role["atomic_differences"]
        if difference["subject_role"] == "resource"
    )
    resource_difference["subject_alignment_id"] = entity_alignment_id
    expect_integrity_rejection(
        wrong_resource_role, "resource difference references an entity alignment"
    )
    incomplete_fallback = copy.deepcopy(reports["resource-gradient-change"])
    del incomplete_fallback["events"][0]["difference_regions"][0][
        "cause_envelope"
    ]["candidate_changed_fact_ids"][0]
    expect_causal_rejection(
        incomplete_fallback, "revoked envelope omitted a Changed Fact"
    )
    contaminated_region = copy.deepcopy(reports["multi-event-ordering"])
    first_event = contaminated_region["events"][0]
    second_event = contaminated_region["events"][1]
    second_difference_id = second_event["atomic_difference_ids"][0]
    unrelated_fact_id = next(
        fact_id
        for difference in contaminated_region["atomic_differences"]
        if difference["id"] == second_difference_id
        for fact_id in difference["changed_fact_ids"]
    )
    first_event["difference_regions"][0]["cause_envelope"][
        "candidate_changed_fact_ids"
    ].append(unrelated_fact_id)
    expect_causal_rejection(
        contaminated_region, "event-region envelope contains a cross-event fact"
    )

    output = {
        "schema_version": "svgdiff-determinism-results/1",
        "manifest_version": manifest["schema_version"],
        "repetitions_per_mode": repetitions,
        "cases": results,
        "negative_controls": [
            "duplicate_report_local_id",
            "dangling_report_local_reference",
            "duplicate_report_local_reference",
            "resource_alignment_role_mismatch",
            "incomplete_revoked_cause_envelope",
            "cross_event_cause_contamination",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    if bundle is not None:
        bundle_manifest = {
            "schema_version": "svgdiff-determinism-bundle/1",
            "corpus_version": manifest["schema_version"],
            "reports": bundled_reports,
        }
        (bundle / "bundle.v1.json").write_text(
            json.dumps(bundle_manifest, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    main()
