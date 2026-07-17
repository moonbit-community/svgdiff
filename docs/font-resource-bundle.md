# Deterministic Font Resource Bundle Contract

Status: accepted input contract; loading and font execution are not implemented

Contract version: `svgdiff-font-bundle/1`

Fingerprint version: `svgdiff-font-bundle-fingerprint/1`

Last verified: 2026-07-17

This contract defines the immutable font bytes that a future deterministic text profile may consume. It does not make font-dependent text analysis complete. Current comparisons still emit `font_analysis_deferred`, keep affected Computed Appearance and Rendered Evidence limited, and never consult system fonts or this manifest.

The governing decision is [ADR 0097](adr/0097-separate-font-bundle-rendering-identity-from-legal-metadata.md). Format, security, and licensing evidence comes from the [primary-source research note](research/font-resource-bundle.md). Executable examples live under [`evaluation/font-bundle-contract`](../evaluation/font-bundle-contract/).

## Boundary

A Font Bundle is a closed caller-supplied set of encoded Font Resources. The caller supplies the manifest, exact resource bytes keyed by `resource_id`, and legal-text bytes keyed by their declared hashes. A filesystem path may transport bytes to the CLI in a later implementation, but it is never resource identity or report evidence.

The v1 contract forbids:

- system-font discovery, `local()` sources, generic-family fallback, and implicit network access;
- treating file extensions, family names, PostScript names, localized names, or OpenType version strings as identity;
- silently selecting face zero when a declared collection face is missing;
- canonicalizing, subsetting, repacking, or otherwise rewriting font binaries during admission;
- inferring redistribution permission from OpenType metadata or an SPDX expression alone;
- claiming that an admitted bundle fixes family matching, fallback, variations, shaping, SVG text layout, hinting, rasterization, color-font behavior, or pixels.

Those execution choices require a separately versioned Font Execution Profile. The accepted [Font Runtime dependency contract](font-runtime-dependencies.md) selects a future implementation seam, but it does not weaken this resource boundary or add current execution support.

Supplying the same closed bundle to CoreText, DirectWrite, or a browser can support an external [Platform Font Observation](platform-native-font-modes.md), but exact resource bytes do not make that platform stack canonical or portable.

The future [general Resource Snapshot Bundle](general-resource-snapshot-bundles.md) may carry an external font response and acquisition evidence, but it does not replace `svgdiff-font-bundle/1` face inventory, legal manifest, fingerprint, or Font Execution Profile. URL response identity and admitted font-resource identity remain separate contracts.

## Manifest

The manifest is strict UTF-8 JSON with exactly five top-level fields. Every string is ASCII in v1, object fields are closed, resource and provenance arrays are ordered by `resource_id`, license records are ordered by `license_id`, and face indices are ascending and contiguous from zero.

| Field | Contract |
| --- | --- |
| `schema_version` | Exactly `svgdiff-font-bundle/1`. |
| `bundle_id` | Human-facing lowercase ASCII identifier of at most 128 bytes. It is not rendering identity. |
| `resources` | Zero to 64 Font Resource records in canonical identifier order. An empty bundle explicitly provides no font. |
| `licenses` | Exactly the referenced license-evidence records in canonical identifier order. Every resource refers to one present record and unused records are rejected. |
| `provenance` | Exactly one provenance record for every resource, in the same identifier order. |

A Font Resource record contains:

| Field | Contract |
| --- | --- |
| `resource_id` | Bundle-local stable identifier of at most 128 bytes matching `[a-z0-9]+([._-][a-z0-9]+)*`. |
| `encoded_format` | `opentype_sfnt`, `opentype_collection`, `woff1`, or `woff2`. Admission of a container does not imply execution support for every feature it can contain. |
| `byte_length` | Exact positive encoded length, at most 32 MiB. |
| `sha256` | Lowercase SHA-256 of the exact encoded bytes. Duplicate byte hashes are rejected. |
| `face_indices` | Every contained face index, exactly `[0, ..., n-1]`. `opentype_sfnt` and `woff1` require `[0]`. A future decoder must verify this declaration against the container. |
| `license_id` | Reference to one license-evidence record. Excluded from the rendering fingerprint. |

The v1 bundle admits at most 128 declared faces and 128 MiB of encoded resource bytes in total. The manifest's canonical encoding is limited to 1 MiB. These are pre-parser admission limits, not sufficient decoder limits.

A license-evidence record contains `license_id`, a caller-asserted `spdx_expression`, one to sixteen sorted unique `license_text_sha256s`, nullable `notice_sha256`, and `distribution_review`. The array can retain every license and exception text named by a compound SPDX expression. `distribution_review` is either `not_reviewed` or `reviewed_for_distribution`. `NOASSERTION` may describe a local-only resource, but it cannot pass a distribution review.

A provenance record contains `resource_id`, `source_ref`, `upstream_version`, `copyright_notice_sha256`, `reserved_font_names_sha256`, `derivation`, and nullable `derivation_tool`. The Reserved Font Name hash addresses an exact UTF-8 evidence document, including an explicit empty document when none are declared, so legal text is not forced into the manifest's ASCII-only metadata. `derivation` is `unmodified`, `subset`, `modified`, or `repacked`; only `unmodified` requires a null tool. These fields preserve evidence. They do not automate a legal conclusion.

## Admission order

A future loader must fail closed in this order, before shaping or rasterization:

1. bound the manifest bytes, parse strict JSON, reject duplicate keys, unknown fields, non-ASCII strings, and a mismatched contract version;
2. enforce canonical array order, identifier uniqueness, raw byte/count limits, face-index form, and complete license/provenance references;
3. resolve caller-supplied bytes by exact `resource_id` without interpreting paths or URLs;
4. compare encoded byte length and SHA-256 before calling a font or compression parser;
5. detect the container from its header and require it to match `encoded_format`; an extension is irrelevant;
6. parse inside independent decoded-size, table, glyph, axis, nesting, time, and memory limits, then require the declared face indices to cover the actual collection exactly;
7. verify supplied license, notice, and copyright bytes by hash whenever the bundle is packaged or distributed;
8. construct a later Font Execution Profile only after every required resource and runtime capability is accepted.

Missing bytes, hash mismatch, length mismatch, undeclared or out-of-range faces, unsupported containers or tables, decompression-limit exhaustion, and runtime-profile drift are errors. They must never fall back to a system font or a different bundle resource. Until loading is implemented, all such work remains outside the comparison engine and current `font_analysis_deferred` behavior is unchanged.

WOFF and WOFF2 declared decoded sizes are untrusted hints. A future decoder must count actual output and separately bound decompression, OpenType tables, composite glyph recursion, embedded bitmaps, and SVG glyph content. SVG-in-OpenType must use a secure static profile with scripts, external resources, animation, and interaction disabled.

## Two identities

The Font Bundle Fingerprint identifies only rendering-relevant resource inputs. Build this projection without adding or omitting fields:

```json
{
  "fingerprint_version": "svgdiff-font-bundle-fingerprint/1",
  "resources": [
    {
      "resource_id": "...",
      "encoded_format": "...",
      "byte_length": 0,
      "sha256": "...",
      "face_indices": [0]
    }
  ]
}
```

Canonical JSON v1 recursively sorts object keys, preserves already canonical arrays, emits no insignificant whitespace, uses decimal integers, and JSON-escapes every ASCII string. The fingerprint is lowercase `SHA-256(canonical UTF-8 bytes)`. The version field domain-separates later algorithms.

The Font Bundle Manifest Digest is lowercase SHA-256 over the same canonical encoding of the complete manifest. It covers `bundle_id`, legal evidence, and provenance as well as rendering fields. Neither digest is stored inside the manifest, avoiding a self-reference.

This separation is intentional:

- changing encoded font bytes, container kind, byte length, declared faces, or resource identity changes both digests;
- correcting a license text hash, review status, source reference, or bundle label changes the manifest digest but not the Font Bundle Fingerprint;
- identical glyph appearance from differently encoded resources is not assumed; raw resources remain distinct;
- OpenType table checksums are format checks, not substitutes for the external SHA-256 identity.

The checked-in vectors fix these rules with a base fingerprint of `2ecf86f620a238899af85b3a6a802573332c2ed58e893ce338212cd580a44b76`. A legal-only mutation retains that fingerprint and changes manifest integrity; a font-byte mutation changes both.

## Font Execution Profile

A Font Bundle alone cannot make pixels reproducible. Before implementation, a separate Font Execution Profile must identify at least:

- the Font Bundle Fingerprint and manifest digest;
- accepted container decoders and their versions;
- family matching, explicit ordered bundle-only fallback, missing-glyph behavior, and synthetic-style policy;
- complete effective variable-axis coordinates, optical-sizing behavior, and feature selection;
- Unicode, script, language, direction, bidirectional, and shaping data/implementation versions;
- SVG text-layout policy;
- rasterizer version and build features, hinting/interpreter mode, antialiasing, subpixel, bitmap, COLR/CPAL, and secure SVG-glyph policies;
- all decoded-size, work, time, and memory limits plus any platform identity still capable of changing output.

Named instances and internal font names may be provenance or matching inputs, never Font Face identity. A Font Face Locator is only `(resource_id, face_index)`. Variation coordinates and CSS descriptors belong to selection/execution evidence and are deliberately absent from the bundle fingerprint.

## Versioning and distribution

Any change to required fields, canonicalization, fingerprint projection, admitted container semantics, or validation behavior requires a new contract or fingerprint ID. Old manifests remain interpretable only by their recorded version; no reader may silently migrate an input and preserve its old fingerprint.

A release may distribute a Font Resource only when exact license, notice, copyright, Reserved Font Name, source, derivation, and review evidence has been checked for that exact raw hash. `reviewed_for_distribution` records that external review; it is not produced automatically by the validator and is not legal advice. Local experiments may use `not_reviewed`, but their font bytes and legal texts must remain outside svgdiff release assets.

Run the dependency-free contract vectors with:

```sh
sh scripts/test-font-bundle-contract.sh
```

The validator exercises fingerprint separation, canonical order, strict fields, resource identity, face declarations, license references, limits, and representative reject paths. It intentionally does not parse or load a font.
