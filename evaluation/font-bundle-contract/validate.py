#!/usr/bin/env python3

import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
VECTORS_PATH = ROOT / "evaluation/font-bundle-contract/vectors.v1.json"
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:[._-][a-z0-9]+)*$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
MANIFEST_FIELDS = {
    "schema_version",
    "bundle_id",
    "resources",
    "licenses",
    "provenance",
}
RESOURCE_FIELDS = {
    "resource_id",
    "encoded_format",
    "byte_length",
    "sha256",
    "face_indices",
    "license_id",
}
LICENSE_FIELDS = {
    "license_id",
    "spdx_expression",
    "license_text_sha256s",
    "notice_sha256",
    "distribution_review",
}
PROVENANCE_FIELDS = {
    "resource_id",
    "source_ref",
    "upstream_version",
    "copyright_notice_sha256",
    "reserved_font_names_sha256",
    "derivation",
    "derivation_tool",
}
ENCODED_FORMATS = {
    "opentype_sfnt",
    "opentype_collection",
    "woff1",
    "woff2",
}
SINGLE_FACE_FORMATS = {"opentype_sfnt", "woff1"}
REVIEW_STATES = {"not_reviewed", "reviewed_for_distribution"}
DERIVATION_STATES = {"unmodified", "subset", "modified", "repacked"}
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_RESOURCES = 64
MAX_FACES = 128
MAX_RESOURCE_BYTES = 32 * 1024 * 1024
MAX_TOTAL_RESOURCE_BYTES = 128 * 1024 * 1024


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(
        path.read_text(encoding="utf-8"), object_pairs_hook=strict_object
    )


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("ascii")


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def require_fields(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        raise ValueError(f"{label} fields")


def require_ascii(value: Any) -> None:
    if isinstance(value, str):
        try:
            value.encode("ascii")
        except UnicodeEncodeError as error:
            raise ValueError("ASCII") from error
    elif isinstance(value, list):
        for item in value:
            require_ascii(item)
    elif isinstance(value, dict):
        for key, item in value.items():
            require_ascii(key)
            require_ascii(item)


def require_id(value: Any, label: str) -> str:
    if (
        not isinstance(value, str)
        or not 1 <= len(value) <= 128
        or ID_PATTERN.fullmatch(value) is None
    ):
        raise ValueError(label)
    return value


def require_sha256(value: Any, label: str, nullable: bool = False) -> None:
    if nullable and value is None:
        return
    if not isinstance(value, str) or SHA256_PATTERN.fullmatch(value) is None:
        raise ValueError(label)


def validate_manifest(manifest: dict[str, Any]) -> None:
    if len(canonical_bytes(manifest)) > MAX_MANIFEST_BYTES:
        raise ValueError("manifest byte limit")
    require_ascii(manifest)
    require_fields(manifest, MANIFEST_FIELDS, "manifest")
    if manifest["schema_version"] != "svgdiff-font-bundle/1":
        raise ValueError("schema_version")
    require_id(manifest["bundle_id"], "bundle_id")

    resources = manifest["resources"]
    if not isinstance(resources, list) or not 0 <= len(resources) <= MAX_RESOURCES:
        raise ValueError("resource count")
    resource_ids = []
    resource_hashes = []
    face_count = 0
    total_bytes = 0
    for resource in resources:
        if not isinstance(resource, dict):
            raise ValueError("resource")
        require_fields(resource, RESOURCE_FIELDS, "resource")
        resource_id = require_id(resource["resource_id"], "resource_id")
        resource_ids.append(resource_id)
        encoded_format = resource["encoded_format"]
        if encoded_format not in ENCODED_FORMATS:
            raise ValueError("encoded_format")
        byte_length = resource["byte_length"]
        if (
            not isinstance(byte_length, int)
            or isinstance(byte_length, bool)
            or not 0 < byte_length <= MAX_RESOURCE_BYTES
        ):
            raise ValueError("resource byte limit")
        total_bytes += byte_length
        require_sha256(resource["sha256"], "resource sha256")
        resource_hashes.append(resource["sha256"])
        faces = resource["face_indices"]
        if (
            not isinstance(faces, list)
            or not faces
            or any(
                not isinstance(index, int)
                or isinstance(index, bool)
                or index < 0
                for index in faces
            )
            or faces != list(range(len(faces)))
        ):
            raise ValueError("face_indices")
        if encoded_format in SINGLE_FACE_FORMATS and faces != [0]:
            raise ValueError("single-face container")
        face_count += len(faces)
        require_id(resource["license_id"], "license_id")
    if resource_ids != sorted(resource_ids):
        raise ValueError("resource order")
    if len(resource_ids) != len(set(resource_ids)):
        raise ValueError("resource_id uniqueness")
    if len(resource_hashes) != len(set(resource_hashes)):
        raise ValueError("resource sha256 uniqueness")
    if face_count > MAX_FACES:
        raise ValueError("face count")
    if total_bytes > MAX_TOTAL_RESOURCE_BYTES:
        raise ValueError("total resource byte limit")

    licenses = manifest["licenses"]
    if not isinstance(licenses, list):
        raise ValueError("licenses")
    license_ids = []
    for license_record in licenses:
        if not isinstance(license_record, dict):
            raise ValueError("license")
        require_fields(license_record, LICENSE_FIELDS, "license")
        license_id = require_id(license_record["license_id"], "license_id")
        license_ids.append(license_id)
        expression = license_record["spdx_expression"]
        if not isinstance(expression, str) or not 1 <= len(expression) <= 256:
            raise ValueError("spdx_expression")
        license_texts = license_record["license_text_sha256s"]
        if (
            not isinstance(license_texts, list)
            or not 1 <= len(license_texts) <= 16
            or license_texts != sorted(set(license_texts))
        ):
            raise ValueError("license text sha256s")
        for digest in license_texts:
            require_sha256(digest, "license text sha256")
        require_sha256(
            license_record["notice_sha256"], "notice sha256", nullable=True
        )
        if license_record["distribution_review"] not in REVIEW_STATES:
            raise ValueError("distribution review")
        if (
            expression == "NOASSERTION"
            and license_record["distribution_review"]
            == "reviewed_for_distribution"
        ):
            raise ValueError("distribution review")
    if license_ids != sorted(license_ids):
        raise ValueError("license order")
    if len(license_ids) != len(set(license_ids)):
        raise ValueError("license_id uniqueness")
    used_license_ids = {resource["license_id"] for resource in resources}
    if used_license_ids - set(license_ids):
        raise ValueError("license reference")
    if set(license_ids) - used_license_ids:
        raise ValueError("license coverage")

    provenance = manifest["provenance"]
    if not isinstance(provenance, list):
        raise ValueError("provenance")
    provenance_ids = []
    for record in provenance:
        if not isinstance(record, dict):
            raise ValueError("provenance record")
        require_fields(record, PROVENANCE_FIELDS, "provenance")
        provenance_ids.append(require_id(record["resource_id"], "resource_id"))
        for field in ("source_ref", "upstream_version"):
            if not isinstance(record[field], str) or not 1 <= len(record[field]) <= 512:
                raise ValueError(field)
        require_sha256(
            record["copyright_notice_sha256"], "copyright notice sha256"
        )
        require_sha256(
            record["reserved_font_names_sha256"],
            "reserved font names sha256",
        )
        derivation = record["derivation"]
        tool = record["derivation_tool"]
        if derivation not in DERIVATION_STATES:
            raise ValueError("derivation")
        if derivation == "unmodified":
            if tool is not None:
                raise ValueError("derivation tool")
        elif not isinstance(tool, str) or not 1 <= len(tool) <= 256:
            raise ValueError("derivation tool")
    if provenance_ids != sorted(provenance_ids):
        raise ValueError("provenance order")
    if provenance_ids != resource_ids:
        raise ValueError("provenance coverage")


def rendering_projection(manifest: dict[str, Any]) -> dict[str, Any]:
    return {
        "fingerprint_version": "svgdiff-font-bundle-fingerprint/1",
        "resources": [
            {
                "resource_id": resource["resource_id"],
                "encoded_format": resource["encoded_format"],
                "byte_length": resource["byte_length"],
                "sha256": resource["sha256"],
                "face_indices": resource["face_indices"],
            }
            for resource in manifest["resources"]
        ],
    }


def font_bundle_fingerprint(manifest: dict[str, Any]) -> str:
    validate_manifest(manifest)
    return sha256(canonical_bytes(rendering_projection(manifest)))


def manifest_digest(manifest: dict[str, Any]) -> str:
    validate_manifest(manifest)
    return sha256(canonical_bytes(manifest))


def legal_variant(base: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(base)
    change = vectors["legal_metadata_variant"]
    license_record = next(
        value
        for value in result["licenses"]
        if value["license_id"] == change["license_id"]
    )
    license_record["license_text_sha256s"] = change[
        "replacement_license_text_sha256s"
    ]
    license_record["distribution_review"] = change[
        "replacement_distribution_review"
    ]
    provenance = next(
        value
        for value in result["provenance"]
        if value["resource_id"] == "latin-regular"
    )
    provenance["source_ref"] = change["replacement_source_ref"]
    return result


def rendering_variant(base: dict[str, Any], vectors: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(base)
    change = vectors["rendering_variant"]
    resource = next(
        value
        for value in result["resources"]
        if value["resource_id"] == change["resource_id"]
    )
    resource["sha256"] = change["replacement_sha256"]
    return result


def invalid_variant(base: dict[str, Any], mutation_id: str) -> dict[str, Any]:
    result = copy.deepcopy(base)
    if mutation_id == "unknown-schema":
        result["schema_version"] = "svgdiff-font-bundle/2"
    elif mutation_id == "unknown-top-level-field":
        result["unexpected"] = True
    elif mutation_id == "resource-order":
        result["resources"].reverse()
    elif mutation_id == "duplicate-resource-id":
        result["resources"][1]["resource_id"] = "latin-regular"
        result["resources"].sort(key=lambda value: value["resource_id"])
    elif mutation_id == "duplicate-resource-bytes":
        result["resources"][1]["sha256"] = result["resources"][0]["sha256"]
    elif mutation_id == "uppercase-sha256":
        result["resources"][0]["sha256"] = "A" * 64
    elif mutation_id == "noncontiguous-faces":
        result["resources"][1]["face_indices"] = [0, 2]
    elif mutation_id == "single-face-container-multiple-faces":
        result["resources"][0]["face_indices"] = [0, 1]
    elif mutation_id == "missing-license-reference":
        result["resources"][0]["license_id"] = "missing"
    elif mutation_id == "license-order":
        result["licenses"].reverse()
    elif mutation_id == "license-text-order":
        result["licenses"][0]["license_text_sha256s"] = ["f" * 64, "a" * 64]
    elif mutation_id == "noassertion-distribution":
        result["licenses"][0]["spdx_expression"] = "NOASSERTION"
        result["licenses"][0]["distribution_review"] = (
            "reviewed_for_distribution"
        )
    elif mutation_id == "provenance-order":
        result["provenance"].reverse()
    elif mutation_id == "resource-byte-limit":
        result["resources"][0]["byte_length"] = MAX_RESOURCE_BYTES + 1
    elif mutation_id == "non-ascii-metadata":
        result["provenance"][0]["upstream_version"] = "版本-1"
    else:
        raise ValueError(f"unknown mutation: {mutation_id}")
    return result


def main() -> None:
    vectors = load_json(VECTORS_PATH)
    if vectors["schema_version"] != "svgdiff-font-bundle-contract-vectors/1":
        raise ValueError("vector schema drifted")
    base = vectors["base_manifest"]
    legal = legal_variant(base, vectors)
    rendering = rendering_variant(base, vectors)
    actual = {
        "base_font_bundle_fingerprint": font_bundle_fingerprint(base),
        "base_manifest_digest": manifest_digest(base),
        "legal_variant_font_bundle_fingerprint": font_bundle_fingerprint(legal),
        "legal_variant_manifest_digest": manifest_digest(legal),
        "rendering_variant_font_bundle_fingerprint": font_bundle_fingerprint(
            rendering
        ),
        "rendering_variant_manifest_digest": manifest_digest(rendering),
    }
    if "PENDING" in vectors["expected"].values():
        print(json.dumps(actual, indent=2, sort_keys=True))
        return
    if actual != vectors["expected"]:
        raise ValueError("font bundle fingerprint vectors drifted")
    if actual["base_font_bundle_fingerprint"] != actual[
        "legal_variant_font_bundle_fingerprint"
    ]:
        raise ValueError("legal metadata changed rendering identity")
    if actual["base_manifest_digest"] == actual["legal_variant_manifest_digest"]:
        raise ValueError("legal metadata did not change manifest integrity")
    if actual["base_font_bundle_fingerprint"] == actual[
        "rendering_variant_font_bundle_fingerprint"
    ]:
        raise ValueError("font byte change did not change rendering identity")

    for mutation in vectors["invalid_mutations"]:
        try:
            validate_manifest(invalid_variant(base, mutation["id"]))
        except ValueError as error:
            if str(error) != mutation["expected_error"]:
                raise ValueError(
                    f"{mutation['id']}: expected {mutation['expected_error']!r}, "
                    f"received {str(error)!r}"
                ) from error
        else:
            raise ValueError(f"{mutation['id']}: invalid manifest was accepted")

    for invalid_json in vectors["invalid_json"]:
        try:
            json.loads(
                invalid_json["text"], object_pairs_hook=strict_object
            )
        except ValueError as error:
            if str(error) != invalid_json["expected_error"]:
                raise ValueError(
                    f"{invalid_json['id']}: expected "
                    f"{invalid_json['expected_error']!r}, received {str(error)!r}"
                ) from error
        else:
            raise ValueError(
                f"{invalid_json['id']}: invalid JSON was accepted"
            )

    print(
        "Font bundle contract: 3 valid identities, "
        f"{len(vectors['invalid_mutations']) + len(vectors['invalid_json'])} "
        "invalid manifests rejected; "
        "legal metadata separated from rendering identity"
    )


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Font bundle contract failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
