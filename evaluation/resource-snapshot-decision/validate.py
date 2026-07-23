#!/usr/bin/env python3
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


decision = json.loads((HERE / "decision.v1.json").read_text(encoding="utf-8"))
require(
    decision["schema_version"] == "svgdiff-resource-snapshot-decision/1",
    "unexpected decision schema",
)
require(
    decision["future_bundle_identity_format"]
    == "svgdiff-resource-snapshot-bundle/1",
    "resource snapshot bundle identity drifted",
)
require(
    decision["future_resolution_policy_identity_format"]
    == "svgdiff-resource-resolution-policy/1",
    "resource resolution policy identity drifted",
)
require(
    decision["future_prefetch_profile_identity_format"]
    == "svgdiff-resource-prefetch-profile/1",
    "prefetch profile identity drifted",
)
require(
    decision["future_prefetch_transcript_identity_format"]
    == "svgdiff-resource-prefetch-transcript/1",
    "prefetch transcript identity drifted",
)
require(
    decision["initial_slice_identity_format"]
    == "svgdiff-resource-snapshot-http-image-slice/1",
    "resource snapshot initial slice drifted",
)
for field in [
    "before_after_use_separate_snapshots",
    "same_url_may_have_different_side_bytes",
    "recursive_closure_required_for_admitted_families",
    "future_prefetch_is_separate_user_invoked_artifact",
]:
    require(decision[field] is True, f"required resource boundary lost: {field}")
for field in [
    "current_opaque_raster_bundle_changed",
    "comparison_time_filesystem_io",
    "comparison_time_network_io",
    "lookup_key_is_url_only",
    "acquisition_provenance_is_rendering_identity",
    "unused_entry_is_svg_difference",
    "content_interpretation_is_bundle_assertion",
]:
    require(decision[field] is False, f"unsafe resource inference enabled: {field}")
require(len(decision["required_occurrence_layers"]) == 9, "resource layers incomplete")
require(len(decision["logical_request_identity_fields"]) == 8, "request identity incomplete")
require(len(decision["response_snapshot_fields"]) == 6, "response snapshot incomplete")
require(len(decision["initial_slice_constraints"]) == 6, "initial slice incomplete")
require(
    set(decision["required_digest_boundaries"])
    == {
        "blob_sha256",
        "resolution_snapshot_digest",
        "reachable_render_inputs_digest",
        "acquisition_transcript_digest",
        "compliance_evidence_digest",
        "package_digest",
    },
    "resource digest boundaries were collapsed",
)
require(
    set(decision["typed_outcomes"])
    == {
        "access_blocked",
        "acquisition_failure_recorded",
        "base_url_unavailable",
        "content_invalid",
        "insufficient_evidence",
        "integrity_failed",
        "invalid_bundle",
        "media_type_mismatch",
        "nested_closure_incomplete",
        "redirect_unavailable",
        "request_variant_ambiguous",
        "resolved",
        "resource_cycle_or_family_loop",
        "resource_family_unsupported",
        "resource_limit_exceeded",
        "snapshot_entry_missing",
        "url_invalid",
    },
    "resource outcome vocabulary drifted",
)
for field in [
    "prefetch_implemented",
    "general_bundle_implemented",
    "report_schema_change",
    "public_api_change",
    "module_dependency_change",
    "diagnostic_change",
    "fixture_change",
    "default_ci_change",
]:
    require(decision[field] is False, f"unexpected current change: {field}")

for directory in [
    ROOT / "modules" / "svgdiff" / "engine",
    ROOT / "schema",
    ROOT / "modules" / "svgdiff" / "cmd",
    ROOT / ".github",
]:
    if directory.exists():
        for path in directory.rglob("*"):
            if path.is_file():
                text = path.read_text(encoding="utf-8", errors="ignore").lower()
                for identity in [
                    "svgdiff-resource-snapshot-bundle",
                    "svgdiff-resource-resolution-policy",
                    "svgdiff-resource-prefetch-profile",
                    "svgdiff-resource-prefetch-transcript",
                    "svgdiff-resource-snapshot-http-image-slice",
                ]:
                    require(
                        identity not in text,
                        f"future resource snapshot identity leaked into {path.relative_to(ROOT)}",
                    )

print(
    "Resource snapshot decision: side-qualified offline responses preserve URL, "
    "content, and provenance distinctions with zero comparison-time I/O"
)
