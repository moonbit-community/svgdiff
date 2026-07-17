# Deterministic Font Runtime Dependency Contract

Status: accepted dependency direction; runtime and font execution are not implemented

Runtime API identity: `svgdiff-font-runtime-api/1`

Build identity format: `svgdiff-font-runtime-build/1`

Initial execution slice: `svgdiff-font-execution-slice/1`

Last verified: 2026-07-17

This contract selects the dependency stack and ownership boundary for future deterministic shaping, outline extraction, and glyph coverage. It does not load a Font Bundle, shape product text, implement SVG text layout, emit glyph evidence, or change current `font_analysis_deferred` behavior.

The governing decision is [ADR 0098](adr/0098-own-a-pinned-font-runtime-module.md). The package and upstream audit is recorded in the [research note](research/font-runtime-dependencies.md), and the exact-source build/FFI feasibility result lives under [`evaluation/font-runtime-selection`](../evaluation/font-runtime-selection/).

## Selected ownership

A future separately versioned workspace module at `modules/font_runtime`, published as `Milky2018/svgdiff-font-runtime`, will own:

- statically vendored HarfBuzz `14.2.1` for single-run OpenType shaping;
- statically vendored FreeType `2.14.3` for face validation, outline extraction, and grayscale coverage;
- project-owned C shim, MoonBit facade, resource limits, lifetime rules, error translation, and fixed output records;
- exact source, patch, configuration, toolchain, target, archive, shim, and linked-artifact identities.

The root module will eventually depend only on the facade. HarfBuzz and FreeType handles, enums, structs, callbacks, borrowed arrays, allocators, and error values must remain private. No community package, upstream source, native library, module dependency, or public interface is added by this decision.

The current Mooncakes font stack is retained as an independent conformance candidate. It is not the canonical runtime because no inspected package jointly supplies the required strict-toolchain state, source parity, fixtures, security limits, and terminal-script evidence. `Milky2018/moon_cosmic` is specifically too broad: it also owns matching, fallback, BiDi, wrapping, layout, synthetic styles, caching, and platform fallback policy that svgdiff must decide in later roadmap items.

## Exact upstream sources

| Component | Required source | Selected distribution license |
| --- | --- | --- |
| HarfBuzz | Release `14.2.1`, peeled commit `56feae4035bdd48f62ba2b8d8c16232d4d89b3a4`, release archive SHA-256 `a54a5d8e9380a41fbb762ce367bcbf7704792dfca0d93f1bbca86c5a57902e0e` | Upstream Old MIT, with complete notices retained |
| FreeType | Release `VER-2-14-3`, peeled commit `0a0221a1347e2f1e07c395263540026e9a0aa7c7`, release archive SHA-256 `36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f` | FreeType License option, with required attribution and complete text retained |

This license selection is packaging guidance, not legal advice. Runtime-library licensing remains separate from the per-font legal evidence in a Font Bundle.

An implementation must vendor and hash these sources rather than discover Homebrew, `pkg-config`, system dynamic libraries, or a network dependency. Any upgrade, patch, build-option change, or implementation replacement creates a new Font Runtime Build Identity and requires conformance evidence; it cannot silently retain an earlier Font Execution Profile identity.

## Narrow facade

The facade consumes Font Resources only after the bundle layer has verified their exact bytes and Font Face Locator. Provisional operation names illustrate the boundary, not a committed root-module API:

```text
create_runtime(build_profile) -> Runtime
open_face(runtime, verified_bytes, face_index) -> Face
shape(face, explicit_run) -> owned ShapedRun
outline(face, glyph_id) -> owned GlyphOutline
raster_gray(face, glyph_id, exact_scale, exact_phase) -> owned GrayGlyphMask
```

`open_face` copies bounded bytes into module-owned native memory. A face owns that copy and all upstream objects until one idempotent close path releases them. No MoonBit-managed pointer is retained by C, and no upstream pointer escapes. Output arrays and masks are copied into project-owned storage before return.

An explicit shaping run contains UTF-8 bytes, direction, script, language, cluster policy, and an ordered feature set. Run segmentation, BiDi, line breaking, fallback, matching, and SVG layout remain higher-layer responsibilities. A Shaped Run retains glyph IDs, UTF-8 cluster offsets, and integer advances/offsets in units-per-em; it is not a positioned SVG text subject or raster result.

A Glyph Outline uses project-owned move, line, quadratic, cubic, and close verbs under a versioned fixed-coordinate format. A Gray Glyph Mask carries dimensions, signed origin, stride, coverage bytes, and raster-profile identity. Source text, selected face, Shaped Run, positioned glyphs, outlines, masks, composited pixels, Difference Regions, and Cause Envelopes remain distinct evidence.

The facade returns a closed project error domain such as invalid font, invalid face, unsupported profile feature, limit exceeded, shaping failure, outline unavailable, raster failure, and internal runtime failure. Upstream numeric codes may be retained as private diagnostic detail but are never stable product semantics.

## Initial execution slice

`svgdiff-font-execution-slice/1` admits only:

- verified raw `opentype_sfnt` or `opentype_collection` bytes and an exact zero-based face index;
- caller-segmented, single-direction runs with explicit direction, script, language, cluster policy, and ordered OpenType features;
- HarfBuzz built-in Unicode data, `hb-ot-font`, units-per-em scale, and `hb_shape_full` restricted to the `ot` shaper;
- ordinary static TrueType `glyf` and CFF1 outlines;
- unhinted outline extraction; and
- unhinted non-LCD `FT_RENDER_MODE_NORMAL` grayscale coverage at an exact fixed-point scale and phase, followed by project-owned compositing.

HarfBuzz opens the verified bytes directly and uses its OpenType font functions. FreeType independently opens the same bytes and face. Production shaping must not use `hb-ft`, so FreeType size, load flags, hinting, or mutable face state cannot alter shaping advances.

Outline loading uses `NO_SCALE`, `NO_HINTING`, `NO_AUTOHINT`, `NO_BITMAP`, and `NO_SVG`, requires outline format, and rejects tricky faces for unscaled evidence. Grayscale loading uses the same exclusions without `NO_SCALE`, requires outline format even when a bitmap-only driver ignores `NO_BITMAP`, and renders only normal grayscale.

The initial slice rejects or gates WOFF/WOFF2, variable fonts including CFF2, AAT, Graphite, fallback shapers, legacy encodings, vertical layout, TrueType bytecode, auto-hinting, stem darkening, LCD/subpixel output, synthetic styles, embedded bitmap strikes, COLR/CPAL, CBDT/CBLC, `sbix`, SVG glyphs, system fonts, platform backends, and every implicit fallback. Their presence produces an explicit unsupported-profile result, never substitution.

## Static build profile

The selected HarfBuzz build is static and disables FreeType integration plus GLib, GObject, Cairo, Chafa, PNG, zlib, ICU, Graphite2, Fontations, GDI, DirectWrite, CoreText, HarfRust, `kb_text_shape`, WASM, raster, vector, GPU, subset, tests, utilities, docs, introspection, benchmarks, and experimental APIs. A hashed project override header also disables ambient file/environment/locale behavior, AAT, and the fallback shaper while retaining built-in Unicode and OpenType shaping.

The selected FreeType build is static and disables external zlib, bzip2, PNG, HarfBuzz auto-hinter, and Brotli integration. The maintained module must additionally hash project-owned `ftoption.h` and `ftmodule.h` files that remove ambient properties, hint interpreters, SVG/color/bitmap paths, unused drivers, and unused renderers while retaining only raw SFNT/collection, TrueType/CFF1 outline dependencies, and smooth grayscale rendering.

The feasibility build used upstream release defaults plus the dependency-disable switches. It therefore proves the seam and static linkage, not the final reduced FreeType module set. The reduced configuration remains an implementation acceptance gate.

## Build and execution identity

A `svgdiff-font-runtime-build/1` record must include:

- release, peeled commit, archive hash, vendored-tree hash, local patch hashes, and license/notices;
- complete configure arguments and hashes of generated or override headers;
- Meson, CMake, compiler, standard library, linker, archiver, target triple, flags, and MoonBit C-ABI/toolchain identities;
- exact optional-feature matrix and absence or identity of every compression/image dependency;
- static archive, C shim source/header, runtime-module, and final linked-binary hashes; and
- runtime HarfBuzz and FreeType version checks matching the manifest.

The future Font Execution Profile must reference this build identity, the Font Bundle Fingerprint and manifest digest, `svgdiff-font-execution-slice/1`, all matching/shaping/layout/raster options and limits, and the target identity whenever cross-target output equality has not been proven. Pinning source does not by itself promise cross-compiler, cross-platform, or cross-version pixel equality.

## Acceptance before product use

Implementation remains blocked on all of the following:

1. offline source/build closure, license evidence, artifact hashes, and no ambient dynamic dependency;
2. checked ABI ownership plus ASan/UBSan, repeated lifecycle, bounds, and allocator-failure tests;
3. malformed-font, table, collection, recursion, outline, mask, time, and memory limits;
4. exact shaping conformance across representative scripts, clusters, directions, languages, features, and missing glyphs;
5. exact static outline and repeated grayscale-mask conformance on every supported target/profile;
6. preservation of every text evidence layer and stable no-fallback errors; and
7. differential comparison against at least one independent MoonBit implementation or browser oracle.

Until those gates pass and later matching, shaping, layout, and report decisions are implemented, deterministic text remains unsupported in the current product. Run the dependency-decision evidence gate with:

```sh
sh scripts/test-font-runtime-selection.sh
```
