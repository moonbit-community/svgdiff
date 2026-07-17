# ADR 0097: Separate font-bundle rendering identity from legal metadata

- Status: accepted
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

Deterministic text requires exact font bytes, but an exact font package also needs provenance, copyright, license, notice, Reserved Font Name, derivation, and redistribution-review evidence. Treating a family name as identity is ambiguous across localized name records and collections. Hashing the entire legal manifest as rendering identity would instead make a corrected notice look like a visual-profile change. Hashing decoded or normalized font output would require choosing a decoder before the separate dependency decision and could erase meaningful container inputs.

## Decision

Adopt the caller-supplied [`svgdiff-font-bundle/1`](../font-resource-bundle.md) contract with two content identities.

The Font Bundle Fingerprint hashes a closed canonical projection containing each bundle-local resource ID, encoded container kind, exact encoded byte length and SHA-256, and complete zero-based face-index range. It excludes bundle labels, license references, legal review, and provenance. The Font Bundle Manifest Digest hashes the complete canonical manifest and therefore covers those non-rendering records as package-integrity evidence.

Keep a Font Face Locator as `(resource_id, face_index)`. Do not use family, PostScript, localized, version, or named-instance names as identity, and do not normalize across TTF, OTF, WOFF, WOFF2, or collection encodings. Variable coordinates, family matching, fallback, shaping, text layout, rasterization, runtime versions, and capability limits belong to a later Font Execution Profile rather than this bundle fingerprint.

Font bytes must be resolved from an explicit caller mapping, verified by length and SHA-256 before parsing, and never acquired through system-font lookup, `local()`, generic fallback, a serialized filesystem path, or the network. Admission of a manifest is not font execution support and does not change current partial text analysis.

## Consequences

A legal or provenance correction changes package integrity without invalidating known rendering inputs. Any encoded font-byte, face, or container change changes rendering identity even if a human expects similar glyphs. Pixel reproducibility remains unclaimed until a separate execution profile and conformance evidence are accepted.

The bundle carries licensing evidence but makes no legal determination. Distribution requires explicit review for each exact raw hash; local-only fonts and all font dependencies remain outside current module and release assets.

## Rejected alternatives

- Use CSS family or PostScript names as identity: names are neither unique nor stable and do not identify a collection face.
- Hash the whole manifest as the rendering profile: legal metadata is not a visual input.
- Hash a normalized decoded font: this preselects decoding/canonicalization behavior and invents cross-container equivalence.
- Permit system fallback when a bundle is incomplete: the result would depend on an undeclared machine environment.
