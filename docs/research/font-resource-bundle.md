# Deterministic Font Resource Bundle Contract

Status: decision research; not an implemented product contract

Last verified: 2026-07-17

## Question

What must an explicitly supplied font bundle identify so that a later text pipeline can shape and rasterize the same SVG without consulting the host font environment, while preserving exact resource, collection-face, variable-instance, licensing, and reproducibility evidence?

## Recommendation

Adopt a content-addressed, manifest-first bundle with three separate identities:

1. an **asset** is the exact supplied byte sequence;
2. a **face** is one zero-based face index inside one asset;
3. a **font instance** is one face plus a complete, explicit user-coordinate value for every variation axis.

Use SHA-256 of the unmodified supplied bytes as the only v1 asset identity. Do not infer identity from filenames, MIME declarations, family names, PostScript names, version strings, internal checksums, or named-instance names. Do not invent a cross-container “same visual font” hash in v1. A WOFF2 decoder is allowed to reconstruct functionally equivalent but bytewise different `sfnt` output, so any decoded hash would be meaningful only together with one pinned decoder implementation and configuration, not as a format-independent identity ([WOFF2 reconstruction](https://www.w3.org/TR/WOFF2/#conform-mustNotRejectWrongGlyfLength), [WOFF2 transform effects](https://www.w3.org/TR/WOFF2/#glyf_table_format)).

Supply one independently validated bundle for each comparison side. Equal bundle render-input digests establish a shared explicit font environment. Different digests are permitted only when a font-resource change is part of the comparison and must be reported as such. Neither case grants the SVG filesystem or network authority.

The bundle alone cannot guarantee identical pixels. A separate versioned text-execution profile must pin font matching, fallback, shaping, Unicode data, font decoding, variation resolution, hinting, rasterization, color-glyph handling, and every relevant build option. The roadmap item that selects those dependencies remains a separate decision.

## 2026-07-17 adopted boundary

The accepted [`svgdiff-font-bundle/1`](../font-resource-bundle.md) contract deliberately takes a narrower first slice than the complete candidate below. It identifies exact encoded resources and every collection face, while variable-axis inventories, named instances, CSS descriptors, family catalogs, and selected coordinates remain in the later Font Execution Profile. The raw resource hash already commits to the tables from which those facts must be derived, and the roadmap keeps their selection semantics separate.

The accepted manifest also follows the project's existing no-path resource boundary: a caller supplies bytes by opaque `resource_id`; bundle member paths and URLs are provenance, never comparison-time locators. V1 restricts manifest strings to ASCII and uses the executable `canonical_json/v1` test vectors instead of introducing a general RFC 8785 dependency. License, notice, copyright, and provenance content remains byte-exact outside the manifest and is referenced by SHA-256, so this restriction does not discard its original text.

The accepted Font Bundle Fingerprint corresponds to the `render_inputs_digest` discussed here. The accepted Font Bundle Manifest Digest corresponds to `package_digest`; because the complete manifest contains every resource and legal-content hash, it transitively identifies those external bytes without embedding either digest into a self-referential manifest. The richer face/instance catalog below remains research input for the subsequent matching and execution decisions, not an implemented or accepted schema.

## Primary-source findings

### Containers and face identity

OpenType uses the `sfnt` table wrapper. `.ttf` and `.otf` are filename conventions; actual outline and rendering technologies are determined by tables such as `glyf`, `CFF `, `CFF2`, `COLR`, bitmap tables, or `SVG `. A single OpenType collection (`.ttc` or `.otc`) contains multiple font resources and can share tables between them ([OpenType font file and collections](https://learn.microsoft.com/en-us/typography/opentype/spec/otff)). RFC 8081 likewise registers distinct `font/ttf`, `font/otf`, `font/collection`, `font/woff`, and `font/woff2` media types while warning that font data can contain multiple outline or layout technologies ([RFC 8081](https://www.rfc-editor.org/rfc/rfc8081.html#section-4.4)).

WOFF 1.0 repackages `sfnt` tables with optional per-table compression. Its optional metadata and private blocks do not affect rendering ([WOFF 1.0](https://www.w3.org/TR/WOFF/#OverallStructure), [WOFF metadata](https://www.w3.org/TR/WOFF/#Metadata)). WOFF2 adds whole-stream Brotli compression, table transforms, and an explicit collection directory. A conforming WOFF2 decoder preserves collection face order but can reorder tables and reconstruct different binary layouts ([WOFF2 collection directory](https://www.w3.org/TR/WOFF2/#collection_dir_format), [WOFF2 reconstructed data](https://www.w3.org/TR/WOFF2/#table_format)). Format support must therefore be capability-gated by the accepted decoder profile rather than inferred from a suffix or media type alone.

Collection selection is intrinsically indexed. HarfBuzz constructs a face from a blob plus a zero-based face index, and FreeType exposes the number of faces and the selected zero-based face in the low 16 bits of its API-level `face_index` ([HarfBuzz face API](https://harfbuzz.github.io/harfbuzz-hb-face.html), [FreeType face creation](https://freetype.org/freetype2/docs/reference/ft2-face_creation.html)). FreeType and HarfBuzz also overload upper index bits for named variable instances. That packing is an implementation detail: the bundle must keep `face_index` and variation-instance selection in separate fields.

Internal names are not identity. OpenType `name` records are keyed by platform, encoding, language, and name ID, can be localized, and can expose several different family groupings. Even PostScript name ID 6 can differ from the CFF Name INDEX and can occur in collection-sharing arrangements ([OpenType `name`](https://learn.microsoft.com/en-us/typography/opentype/spec/name)). RFC 8081 defines a PostScript-name fragment convention for collections, but also warns that collection order can change between revisions ([RFC 8081 collection fragments](https://www.rfc-editor.org/rfc/rfc8081.html#section-4.2)). For svgdiff, names are matching inputs or provenance only; exact bytes plus face index are the stable resource identity.

### Fingerprints and normalization boundaries

Use lowercase hexadecimal SHA-256 over the exact supplied asset bytes. FIPS 180-4 defines SHA-256 as a message-digest algorithm for detecting message changes ([FIPS 180-4](https://csrc.nist.gov/pubs/fips/180-4/upd1/final)). The manifest must verify the declared byte count and digest before parsing the asset.

OpenType table checksums and `head.checkSumAdjustment` are structural integrity fields, not asset identifiers. `checkSumAdjustment` depends on the complete binary layout and must be ignored for a face used inside a collection; `head` also carries timestamps and manufacturer revision metadata ([OpenType `head`](https://learn.microsoft.com/en-us/typography/opentype/spec/head)). WOFF decoders can reorder tables and invalidate checksums or signatures. WOFF2 explicitly permits different decoders to reconstruct output that is functionally equivalent but not a bitwise match, and requires WOFF2 encoders to remove an invalidated `DSIG` table ([WOFF2 transformed font data](https://www.w3.org/TR/WOFF2/#table_format)).

Consequently, v1 must not:

- zero timestamps, reorder tables, strip metadata, subset glyphs, convert containers, or rebuild a font before hashing;
- equate assets using OpenType unique-name, version, PostScript-name, checksum, or signature fields;
- hash an unspecified decoder's reconstructed `sfnt` and call it a semantic fingerprint;
- treat equal asset hashes as proof of equal selected faces or instances.

The bundle needs two aggregate digests with different meanings:

- `package_digest` hashes the canonical full manifest, including license-text hashes and provenance, and identifies the distributable bundle package;
- `render_inputs_digest` hashes only the ordered bundle inputs that can reach rendering: policy ID, exact locator mappings, asset SHA-256 values, exposed face indices, verified axis and named-instance inventories, and catalog order. Later matching and execution profiles add their own identities rather than being folded invisibly into this bundle digest.

Canonical manifest bytes should use RFC 8785 JCS with the digest fields themselves omitted. JCS supplies deterministic property sorting and UTF-8 serialization, preserves JSON strings without Unicode normalization, and leaves array order intact ([RFC 8785](https://www.rfc-editor.org/rfc/rfc8785.html)). This makes resource and face arrays intentionally ordered inputs rather than accidental map iteration order.

### Variable fonts and instances

The `fvar` table defines axes by four-byte tag, minimum, default, maximum, and font-defined order. It also defines named instances, but an instance record for the default coordinates is optional. When an axis value is omitted, the font's default applies ([OpenType `fvar`](https://learn.microsoft.com/en-us/typography/opentype/spec/fvar)). The `avar` table can remap default-normalized coordinates through font-specific piecewise-linear segments, so two equal user-coordinate deltas need not have equal visual effects ([OpenType `avar`](https://learn.microsoft.com/en-us/typography/opentype/spec/avar)).

An instance identity must therefore contain the final user-coordinate value for every `fvar` axis in the font-defined axis order, including defaulted axes. Record each value as its signed 16.16 fixed-point integer, not as an unqualified JSON binary64 value or localized string. FreeType exposes OpenType variation design coordinates in that 16.16 form ([FreeType variation coordinates](https://freetype.org/freetype2/docs/reference/ft2-multiple_masters.html)). The bundle inventories the available variation space and named instances; the later text pipeline derives a selected instance per shaped run from SVG/CSS and records that complete vector in the report.

Named-instance index and localized name remain provenance only. Resolve either form to a complete coordinate vector during bundle validation. The validator should reject manifest coordinates outside the declared `fvar` interval instead of silently clamping them. CSS itself defines clamping and a resolution order among high-level weight, width, style, optical-size properties, named instances, and low-level variation settings; that CSS behavior belongs in the later text-execution profile and must not be guessed by the bundle parser ([CSS Fonts 4 variation settings](https://www.w3.org/TR/css-fonts-4/#font-variation-settings-def), [CSS Fonts 4 feature and variation resolution](https://www.w3.org/TR/css-fonts-4/#feature-variation-precedence)).

### Metadata is evidence, not authority

Preserve exact asset bytes and separately expose parsed facts needed for validation. Do not rewrite the `name` table or choose one localized name as a canonical identifier. If names are recorded, retain their full `(platform_id, encoding_id, language_id, name_id)` key and decoded value, because the OpenType specification explicitly permits platform-, encoding-, and language-specific variants ([OpenType `name`](https://learn.microsoft.com/en-us/typography/opentype/spec/name)).

WOFF metadata is optional, localized, and non-rendering. A WOFF metadata license string can be retained as embedded evidence, but it must not replace explicit distribution metadata in the bundle manifest. Likewise, OpenType name IDs 0, 13, and 14 can corroborate copyright and licensing facts but must not be treated as a legal grant or silently override the supplied license record.

Runtime normalization is prohibited. Subsetting, format conversion, table deletion, or reconstruction changes the asset identity and can change layout features, hinting, glyph programs, names, or license obligations. Under the Open Font License, even subsetting and format-changing rebuilds can be Modified Versions and can trigger Reserved Font Name requirements ([OFL FAQ](https://openfontlicense.org/ofl-faq/)).

### No ambient fonts or implicit I/O

CSS Fonts deliberately leaves the installed-font set undefined and allows it to vary by user agent, platform, locale, privacy policy, and user configuration ([CSS Fonts 4 matching environment](https://www.w3.org/TR/css-fonts-4/#font-matching-algorithm)). A deterministic svgdiff profile cannot use that environment.

The future loader must:

- accept asset bytes from the already validated bundle only;
- match SVG-authored font locators against exact, case-sensitive opaque bundle locators;
- never treat a locator or manifest path as a filesystem path at comparison time;
- never fetch a URL, follow a redirect, call CSS `local()`, scan installed fonts, or consult platform generic-family mappings;
- load bytes through an in-memory interface and keep their lifetime explicit; FreeType provides `FT_New_Memory_Face`, while HarfBuzz constructs faces directly from blobs ([FreeType memory face](https://freetype.org/freetype2/docs/reference/ft2-face_creation.html), [HarfBuzz face API](https://harfbuzz.github.io/harfbuzz-hb-face.html));
- expose only explicitly listed faces, even if an asset contains additional collection faces;
- treat missing or invalid assets, out-of-range face indices, and unlisted fallback as precise unavailable/partial evidence rather than falling back to face zero or the host.

Generic-family mapping, family matching, fallback order, missing-glyph behavior, synthetic bold/oblique, and `font-display` timing are not bundle-format rules. The later deterministic matching contract must make each explicit. Until it does, text that needs any of those decisions remains font-dependent and partial.

### Security and bounded admission

Font files are untrusted interpreted programs and data. RFC 8081 notes that TrueType hinting instructions are executable by the rasterizer and that malicious fonts can consume excessive CPU or memory; the extensible table structure can also hide arbitrary data ([RFC 8081 security considerations](https://www.rfc-editor.org/rfc/rfc8081.html#section-3)). A valid WOFF container does not establish that its contained font is safe or usable ([WOFF 1.0 general requirements](https://www.w3.org/TR/WOFF/#OverallStructure)).

All budgets must be checked with overflow-safe arithmetic before allocation and enforced against actual decoded output. In particular, WOFF2 says `totalSfntSize` is reference information and that transformed `glyf`/`loca` output can differ substantially from it; it is not a trustworthy decompression ceiling ([WOFF2 header](https://www.w3.org/TR/WOFF2/#woff20Header)).

The first font-bundle policy should version fixed limits for at least:

| Dimension | Required accounting boundary |
| --- | --- |
| Asset count and exposed-face count | Per side before any font parse |
| Encoded bytes | Per asset and cumulative per side |
| Decoded bytes | Actual WOFF/WOFF2 output per asset and cumulative per side, independent of declared header size |
| Container structure | Face count, table count, table offset/length bounds, overlap, duplicate tags, and collection sharing references |
| Face structure | Glyph count, variation-axis count, named-instance count, palette/strike count, and composite-glyph depth |
| Embedded content | Bitmap bytes/pixels, OpenType `SVG ` compressed and expanded bytes, XML depth/elements, and path segments |
| Execution | Shaped glyph count, glyph-program operations when hinting is enabled, raster pixels, cumulative work, cancellation, and elapsed-time budget |

Numeric values should be accepted only after a representative multilingual, CJK, emoji, variable-font, and collection corpus demonstrates that they admit intended inputs. The contract must nevertheless require hard policy constants before implementation; “limited by available memory” is not a reproducibility rule.

Parsing and rasterization should occur behind a memory-, CPU-, filesystem-, and network-constrained boundary. If OpenType `SVG ` glyphs are later admitted, their nested SVG must use a separate secure-static profile that disables script, animation, interaction, external references, and implicit resources. If TrueType hinting is admitted, the execution profile must pin the interpreter version and build features; FreeType documents multiple interpreter behaviors and build-time availability ([FreeType driver properties](https://freetype.org/freetype2/docs/reference/ft2-properties.html)). Disabling hinting is a possible later profile decision, not something this bundle contract may assume silently.

### Licensing and redistribution metadata

Every asset must carry a valid SPDX license expression, verbatim copyright notices, and a content-addressed license text. SPDX license expressions represent single, conjunctive, disjunctive, exception, and custom-license cases without inventing project-specific syntax ([SPDX 3.0.1 license expressions](https://spdx.github.io/spdx-spec/v3.0.1/annexes/spdx-license-expressions/)). REUSE 3.3 requires licensing information for binary files and a license file for every referenced license or `LicenseRef` ([REUSE 3.3](https://reuse.software/spec/)).

For OFL-licensed fonts, the official terms permit bundling and redistribution only with the applicable copyright notice and license, and Modified Versions may not use declared Reserved Font Names without permission ([OFL 1.1 official text](https://openfontlicense.org/open-font-license-official-text/)). The manifest must therefore retain Reserved Font Names and whether the asset is an unmodified upstream binary, subset, format conversion, or other modified build.

This metadata is reproducibility and compliance evidence, not legal advice. The validator can prove that a declared expression parses, the referenced license bytes exist and hash correctly, and required fields are present. It cannot determine whether the declaration is legally correct. The first contract should reject absent or unknown licensing declarations instead of treating them as permission to redistribute.

## Recommended manifest contract

The manifest is declarative. Font payloads and license texts are separate bundle members; runtime code receives their verified bytes, not paths. Paths below are acquisition/package keys only and must be bundle-root-relative UTF-8 strings with no absolute prefix, empty segment, `.` or `..` segment, backslash alias, NUL, or symlink escape.

```json
{
  "schema": "svgdiff-font-resource-bundle/1",
  "policy_id": "svgdiff-font-resource-policy/1",
  "package_digest": "sha256:<computed-over-full-manifest-with-digests-omitted>",
  "render_inputs_digest": "sha256:<computed-over-rendering-subset>",
  "assets": [
    {
      "asset_id": "font-0001",
      "member": "fonts/example.woff2",
      "locators": ["fonts/example.woff2"],
      "declared_media_type": "font/woff2",
      "detected_container": "woff2",
      "byte_length": 123456,
      "sha256": "<64 lowercase hex digits>",
      "container_face_count": 1,
      "license": {
        "spdx_expression": "OFL-1.1",
        "copyright_notices": ["Copyright 2026 Example Authors"],
        "license_member": "LICENSES/OFL-1.1.txt",
        "license_sha256": "<64 lowercase hex digits>",
        "upstream_source": "https://example.invalid/font-release",
        "upstream_version": "1.2.3",
        "reserved_font_names": ["Example"],
        "modification": {
          "kind": "unmodified_upstream_binary",
          "tool_id": null,
          "source_asset_sha256": null
        }
      }
    }
  ],
  "faces": [
    {
      "face_id": "face-0001",
      "asset_id": "font-0001",
      "face_index": 0,
      "axis_inventory": [
        {
          "tag": "opsz",
          "minimum_fixed16_16": 524288,
          "default_fixed16_16": 917504,
          "maximum_fixed16_16": 4718592
        },
        {
          "tag": "wght",
          "minimum_fixed16_16": 6553600,
          "default_fixed16_16": 26214400,
          "maximum_fixed16_16": 58982400
        }
      ],
      "named_instance_inventory": [
        {
          "instance_index": 0,
          "coordinates_fixed16_16": [917504, 26214400]
        }
      ],
      "name_provenance": {
        "postscript_name": "Example-Regular",
        "typographic_family": "Example",
        "typographic_subfamily": "Regular"
      }
    }
  ],
  "catalog_face_order": ["face-0001"]
}
```

Contract rules:

1. `asset_id` and `face_id` are manifest-local opaque IDs. They are not content identities and may not be used across bundles without the corresponding digest.
2. Every locator is an exact opaque lookup key. Duplicate locators, duplicate IDs, missing members, undeclared payload members, and media-type/signature mismatch reject the bundle before SVG analysis.
3. The detected container comes from validated magic/header and table structure. File extension, member name, and declared media type are corroborating input only.
4. A single-face asset still declares `face_index = 0`. An out-of-range index rejects the face; it never selects face zero as a fallback.
5. `container_face_count` must equal the bounded parser result. Only listed faces become eligible inputs; unlisted collection faces stay inaccessible.
6. `axis_inventory` must exactly match `fvar` tag order and 16.16 bounds. A non-variable face uses empty arrays. Each named-instance record must have exactly one in-range coordinate per axis; the index and localized name are provenance, while the full vector is the reproducible value. The manifest does not preselect one instance for all text.
7. `name_provenance` is optional diagnostic evidence and is excluded from face identity. A future matching contract may consume names only under an explicit, versioned localization and comparison policy.
8. `catalog_face_order` is meaningful and supplies deterministic input order to the future matcher. It does not itself define CSS family matching or fallback.
9. The rendering-subset digest includes ordered locators, asset hashes, face indices, axis and named-instance inventories, and catalog order. It excludes paths used only to acquire members and non-rendering license/provenance fields. Per-run selected coordinates are derived execution evidence, not a bundle field.
10. The package digest includes every manifest field plus the hashes of all payload and license members. Any attribution or distribution-metadata change therefore changes package identity without falsely claiming a rendering change.

## Required report and profile evidence

When font execution is eventually implemented, each report must retain, for both sides:

- `font_resource_policy_id`;
- `package_digest` and `render_inputs_digest`;
- every selected `(asset_sha256, face_index)` pair;
- the complete selected variation coordinate vector;
- exact font matching and fallback policy ID;
- shaping modules/svgdiff/engine/version/build, shaper choice, Unicode data version, script, language, direction, and feature policy;
- WOFF/WOFF2 decoder identity;
- rasterizer version/build, scale, hinting interpreter and flags, antialiasing/subpixel mode, stem darkening, bitmap/color/SVG-glyph policies, and synthetic-style policy;
- precise missing, invalid, unsupported, or budget-exceeded diagnostics and affected evidence layers.

Changing accepted containers, validation rules, resource budgets, manifest canonicalization, digest inputs, locator behavior, face exposure, coordinate encoding, or licensing requirements requires a new font-resource policy ID. Changing matching, fallback, shaping, variation resolution, Unicode data, rasterization, or color-glyph behavior requires a new text-execution profile ID. Adding or replacing an asset under an unchanged policy changes bundle digests, not the policy version.

## Explicit non-goals for the first contract

- No system-font discovery, CSS `local()`, implicit generic-family mapping, filesystem lookup, or network fetching.
- No cross-container or cross-rebuild visual-equivalence fingerprint for TTF, OTF, TTC/OTC, WOFF, or WOFF2.
- No binary rewriting, subsetting, table stripping, timestamp normalization, container conversion, or license-metadata repair during comparison.
- No family-name, PostScript-name, version-string, internal-checksum, collection-first-face, or named-instance-name identity.
- No choice of shaping or rasterization dependency; that is the next Phase 8 decision.
- No complete CSS family matching, fallback, synthetic style, missing-glyph, optical-sizing, feature-resolution, or text-layout policy.
- No promise that different HarfBuzz, FreeType, browser, operating-system, compiler, or build configurations produce bit-identical glyphs.
- No automatic support claim for Graphite, AAT, bitmap strikes, COLR/CPAL versions, CBDT/CBLC, `sbix`, OpenType `SVG ` glyphs, WOFF2 collections, or any other capability not admitted by a conformance-tested text-execution profile.
- No legal conclusion about redistribution rights; the contract preserves and validates declared evidence only.

## Decision consequence

This contract is sufficient to make the future font input closed, content-addressed, collection-safe, variable-instance-explicit, and auditable. It is deliberately insufficient to mark text Rendered Evidence complete. That requires the subsequent dependency, matching, shaping, layout, rasterization, and conformance decisions, all operating under a separately versioned text-execution profile.
