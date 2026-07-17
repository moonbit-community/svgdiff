# Deterministic Font Runtime Dependencies

Status: dependency decision research; no product font runtime is implemented

Last verified: 2026-07-17

## Question

Which shaping and glyph-rasterization dependencies can support svgdiff's terminal goal: a closed, reproducible font environment whose source text, selected face, shaped glyphs, positioned geometry, coverage mask, final pixels, and causal evidence remain separately inspectable by a text-only Agent?

The accepted [`svgdiff-font-bundle/1`](../font-resource-bundle.md) contract already fixes the input boundary. This decision cannot replace raw resource identity with a filename, family name, installed-font lookup, or library-specific object. It also cannot silently admit a system fallback, network lookup, or first face in a collection. A runtime must consume verified bytes plus the exact `(resource_id, face_index)` and must identify every execution choice separately from the bundle fingerprint.

## Recommendation

Create a separate native workspace module, provisionally `Milky2018/svgdiff-font-runtime`, that owns statically vendored **HarfBuzz 14.2.1** and **FreeType 2.14.3** behind a small project C ABI.

- HarfBuzz owns only single-run OpenType shaping.
- FreeType independently opens the same verified bytes and owns outline extraction plus optional grayscale coverage rasterization.
- A project-owned MoonBit facade owns admission, work limits, lifecycle, error translation, fixed output records, and the future Font Execution Profile.
- Neither upstream handle type, borrowed buffer, filesystem API, font matching rule, fallback rule, nor platform backend crosses the module boundary.
- The root comparison engine consumes only project records such as `GlyphRun`, `GlyphOutline`, and `GlyphMask`; it does not import HarfBuzz or FreeType APIs.

Do **not** consume a current Mooncakes font package as the canonical product runtime yet. There are useful pure-MoonBit implementations, and they should remain conformance candidates and possible future replacements, but the published versions inspected below do not jointly close current-toolchain strictness, upstream parity, self-contained fixtures, provenance, security limits, and terminal-script coverage. Do not import `moon_cosmic`: it also owns matching, fallback, BiDi, layout, and editor policy that svgdiff must specify independently.

This is a source-and-profile pin, not a promise that the same library names produce identical pixels. Exact source commits, build inputs, target, runtime options, and conformance result must be part of the Font Execution Profile. A dependency update creates a new profile and must not mutate the meaning of an old report.

## Selected upstream sources

| Component | Selected source identity | License disposition | Why selected |
| --- | --- | --- | --- |
| HarfBuzz | Tag `14.2.1`; annotated tag object `77a832110d40b0179636f5be8f8781f8299d7e50`; peeled commit `56feae4035bdd48f62ba2b8d8c16232d4d89b3a4`; official release source archive SHA-256 `a54a5d8e9380a41fbb762ce367bcbf7704792dfca0d93f1bbca86c5a57902e0e`; released 2026-06-02 | Old MIT; retain upstream copyright and license text | Mature OpenType shaping, explicit in-memory C API, stable C API/ABI policy, built-in Unicode data and `hb-ot-font`, exact shaper selection, broad script/table support, and existing fuzz/hardening work. See the [release](https://github.com/harfbuzz/harfbuzz/releases/tag/14.2.1), [API stability statement](https://github.com/harfbuzz/harfbuzz/blob/14.2.1/README.md#api-stability), and [license](https://github.com/harfbuzz/harfbuzz/blob/14.2.1/COPYING). |
| FreeType | Tag `VER-2-14-3`; annotated tag object `c740f0fda4274d6ffd2e5b64a25b06ef69803a07`; peeled commit `0a0221a1347e2f1e07c395263540026e9a0aa7c7`; official release source archive SHA-256 `36bc4f1cc413335368ee656c42afca65c5a3987e8768cc28cf11ba775e785a5f`; released 2026-03-22 | Select the FreeType License, not GPL, for svgdiff distribution; retain its required notices and license text; legal review remains external | Mature in-memory font loading, collection-face selection, glyf/CFF outline extraction, variations, and explicit grayscale rendering through an ANSI C API. See the [release source](https://gitlab.freedesktop.org/freetype/freetype/-/tree/VER-2-14-3), [API reference](https://freetype.org/freetype2/docs/reference/index.html), and [dual-license entrypoint](https://gitlab.freedesktop.org/freetype/freetype/-/blob/VER-2-14-3/LICENSE.TXT). |

The commit IDs and verified release-archive hashes are defensible acquisition identities. When the sources are actually vendored, also record SHA-256 for the normalized vendored trees, every local patch, generated configuration header, static archive, and final linked binary. Do not rely on a moving release URL or an unpeeled annotated-tag ID alone.

HarfBuzz is implemented in C++ but exposes a C API; its selected Meson project uses C++11 and disables exceptions by default. FreeType is C. The project shim must be compiled as C or `extern "C"`, and no C++ exception or upstream-owned allocation may cross it.

## Local feasibility probe

On 2026-07-17, a throwaway macOS native probe built the SHA-verified official HarfBuzz 14.2.1 and FreeType 2.14.3 release sources as static libraries and linked them through MoonBit's native C ABI without resolving system HarfBuzz or FreeType dynamic libraries. The probe passed caller-owned in-memory bytes independently to both engines, selected the face explicitly, shaped an explicit Latin run with HarfBuzz's OpenType font functions and `ot` shaper, loaded a FreeType outline, and produced a normal grayscale glyph bitmap. It did not use a path-based font API or `hb-ft` coupling.

This result establishes source-build, static-link, lifetime, and narrow-FFI feasibility for the recommended seam. It does **not** establish script coverage, malformed-font safety, byte-for-byte determinism, cross-target agreement, conformance, or acceptance of the product runtime. Those remain subject to the verification gates below.

## Responsibility boundary

HarfBuzz explicitly does not perform BiDi, line breaking, font discovery, fallback, or multi-style text layout. FreeType loads and rasterizes glyphs; it does not shape or lay out text. Those omissions are a good module boundary, not defects to hide. See HarfBuzz's [scope](https://harfbuzz.github.io/what-does-harfbuzz-do.html) and [non-scope](https://harfbuzz.github.io/what-harfbuzz-doesnt-do.html), and FreeType's [face creation](https://freetype.org/freetype2/docs/reference/ft2-face_creation.html), [glyph loading/rendering](https://freetype.org/freetype2/docs/reference/ft2-glyph_retrieval.html), and [outline decomposition](https://freetype.org/freetype2/docs/reference/ft2-outline_processing.html) APIs.

The narrow seam should expose concepts similar to these, without committing the public svgdiff API to these provisional names:

```text
create_runtime(ExecutionBuildProfile) -> Runtime
open_face(Runtime, verified_bytes, face_index) -> Face
shape(Face, ExplicitRunSpec) -> owned GlyphRun
outline(Face, glyph_id, explicit_variation_coordinates) -> owned GlyphOutline
raster_gray(Face, glyph_id, explicit_variation_coordinates,
            fixed_scale, fixed_origin) -> owned GlyphMask
destroy/free every returned handle or buffer
```

`ExplicitRunSpec` must contain UTF-8 bytes, direction, script, language, cluster-level policy, ordered OpenType features, and variation coordinates. The result must copy HarfBuzz's borrowed arrays immediately into project-owned records containing at least glyph ID, source cluster, x/y advance, and x/y offset. Cluster offsets remain offsets into the run's UTF-8 input; mapping them to SVG Source Spans is a higher layer.

The outline result must use a project enum of move, line, quadratic, cubic, and close verbs with a versioned fixed-coordinate representation. The mask result must contain width, height, signed origin, stride, grayscale coverage bytes, and the exact raster profile ID. Shaped positions, unscaled outline geometry, raster coverage, and composited pixels are distinct evidence layers and must never be collapsed into one opaque bitmap.

Each face implementation may hold both an `hb_face_t`/`hb_font_t` and an `FT_Face`, but both must refer to the same caller-owned verified bytes and exact collection index. The face retains or copies those bytes until both upstream objects are destroyed. The shim checks every MoonBit-to-C length/index conversion, returns a closed project error enum, and retains upstream domain/code only as private diagnostics.

## Deterministic initial execution slice

The first profile should be deliberately narrower than the final Phase 8 feature set:

- raw `opentype_sfnt` and `opentype_collection` inputs only;
- a caller-segmented, single-direction Unicode run;
- explicit script, language, direction, cluster policy, feature list, and no implicit fallback;
- HarfBuzz's built-in UCD and `hb-ot-font`, with `hb_shape_full` restricted to the `ot` shaper;
- font scale set to units-per-em so shaped positions remain font-relative integers;
- ordinary static glyf and CFF1 outlines only, subject to focused conformance gates;
- unhinted outline extraction;
- unhinted, non-LCD `FT_RENDER_MODE_NORMAL` grayscale coverage at an exact fixed-point scale and phase;
- project-owned alpha compositing after the mask is returned.

Do not call `hb_buffer_guess_segment_properties`; defaults and guessed language are not profile evidence. Do not create the shaping font with `hb_ft_font_create_referenced`: FreeType scale, load flags, or hinting must not leak into shaping advances. Use `hb_face_create`/`hb_font_create` plus `hb_ot_font_set_funcs` for the admitted raw SFNT slice, then use FreeType independently for outlines and coverage.

For outline extraction, use the equivalent of `FT_LOAD_NO_SCALE | FT_LOAD_NO_HINTING | FT_LOAD_NO_AUTOHINT | FT_LOAD_NO_BITMAP | FT_LOAD_NO_SVG`, require `FT_GLYPH_FORMAT_OUTLINE`, and reject `FT_FACE_FLAG_TRICKY` in the unscaled profile. FreeType warns that unscaled outlines for tricky fonts can be meaningless. For grayscale masks, set an exact size, use `NO_HINTING | NO_AUTOHINT | NO_BITMAP | NO_SVG`, require an outline, and explicitly render with `FT_RENDER_MODE_NORMAL`. Bitmap-only fonts can ignore `FT_LOAD_NO_BITMAP`, so checking the returned glyph format is mandatory. Never use LCD or host subpixel geometry in the canonical profile.

The accepted Font Bundle can describe WOFF1 and WOFF2, but admission of a container does not imply that this first execution profile supports it. HarfBuzz's ordinary OpenType loader does not decode WOFF; its own face documentation says a FreeType loader may do so when FreeType was built with those features. Initially reject WOFF with a capability diagnostic. A later profile may add a separately pinned zlib/Brotli decoder, hash the decoded SFNT as execution evidence while retaining raw bundle identity, and pass decoded tables to both engines. It must not silently change the first profile.

Likewise gate these until their dedicated roadmap decisions and conformance suites exist:

- family matching, ordered fallback, generic families, synthetic bold/oblique, and missing-glyph policy;
- BiDi, script-run segmentation, line breaking, and SVG text layout;
- vertical shaping/layout and vertical metrics synthesis;
- user-space variable coordinates, named instances, optical sizing, and `avar` behavior;
- AAT, Graphite, legacy encodings, and fallback shapers;
- TrueType bytecode hinting, auto-hinting, stem darkening, LCD/subpixel output, and platform filters;
- embedded bitmap strikes, COLR/CPAL, CBDT/CBLC, `sbix`, and SVG-in-OpenType;
- WOFF1/WOFF2 and any external compression library;
- platform-native CoreText, DirectWrite, GDI, browser, or system-font behavior.

## Pinned static build profile

The workspace module must build from vendored sources. It must not use Homebrew, `pkg-config`, a system dynamic library, a runtime loader, or an automatically detected optional dependency.

### HarfBuzz

Use the upstream Meson build as the normative production build; the official `harfbuzz.cc`/`harfbuzz-world.cc` amalgamations are useful for throwaway probes but make feature and patch auditing less clear for the maintained module. HarfBuzz documents both the build system and amalgamations in its [build guide](https://harfbuzz.github.io/building.html) and [configuration guide](https://github.com/harfbuzz/harfbuzz/blob/14.2.1/CONFIG.md).

Pin a static build and disable every optional integration and non-product library: GLib, GObject, Cairo, Chafa, PNG, zlib, ICU, Graphite2, FreeType integration, Fontations, GDI, DirectWrite, CoreText, HarfRust, `kb_text_shape`, WASM shaper, raster, vector, GPU, subset library, tests, utilities, docs, introspection, and experimental API. The exact option names are listed in the selected [`meson_options.txt`](https://github.com/harfbuzz/harfbuzz/blob/14.2.1/meson_options.txt).

Provide and hash a project `HB_CONFIG_OVERRIDE_H` that disables environment/file ambient behavior and unused shapers, for example `HB_NO_GETENV`, `HB_NO_OPEN`, `HB_NO_MMAP`, `HB_NO_SETLOCALE`, `HB_NO_AAT`, and `HB_NO_FALLBACK_SHAPE`. Keep built-in UCD, the OpenType shaper, vertical data, variation data, metrics, multithread safety, and buffer verification compiled in. Do **not** use `HB_TINY`, `HB_LEAN`, or `HB_MINI`: their selected-version definitions remove combinations of thread safety, verification, vertical metrics, variations, font metrics, AAT/legacy behavior, and beyond-64K support that are too broad for svgdiff's terminal goal.

### FreeType

Use the upstream CMake static build. Its selected [`CMakeLists.txt`](https://gitlab.freedesktop.org/freetype/freetype/-/blob/VER-2-14-3/CMakeLists.txt) documents a static default and explicit dependency-disable switches. For the first profile set `BUILD_SHARED_LIBS=OFF` and disable zlib, bzip2, PNG, HarfBuzz, and Brotli. In particular, disable FreeType's optional HarfBuzz-assisted auto-hinter so there is no hidden or circular runtime dependency.

Vendor and hash project copies of `ftoption.h` and `ftmodule.h`. Disable `FREETYPE_PROPERTIES`, incremental loading, SVG support, color layers, the TrueType bytecode interpreter, subpixel hinting, auto-hinter modules, bitmap drivers, and unused renderers. Retain only the modules required for SFNT/collection loading, TrueType and CFF1 outlines, required PostScript helpers, and the grayscale smooth renderer. The selected upstream [`ftoption.h`](https://gitlab.freedesktop.org/freetype/freetype/-/blob/VER-2-14-3/include/freetype/config/ftoption.h) shows that environment properties, SVG, color layers, bytecode interpretation, and subpixel hinting are compile-time choices.

### Build identity

The execution profile must record:

- both peeled source commits and vendored-tree hashes;
- all local patch hashes;
- Meson/CMake versions and complete configure arguments;
- every generated/override configuration-header hash;
- C and C++ compiler identity, version, target triple, standard library, and exact flags;
- linker and static-archiver identity and flags;
- absence or exact identity of every compression/image dependency;
- target OS/architecture and MoonBit C-ABI/toolchain identity;
- static archive hashes, shim source/header hash, and final linked binary hash;
- runtime `hb_version_string()` and `FT_Library_Version()` agreement with the build manifest.

Use no `-march=native`, fast-math, or implicit host feature detection. A cross-platform profile is accepted only after byte-for-byte output evidence; otherwise the target triple remains part of profile identity.

## Mooncakes registry survey

The registry was queried through its primary `/api/v0/modules` and `/api/v0/manifest/...` endpoints on 2026-07-17. Published source archives were downloaded and their SHA-256 matched the registry checksum. Verification used:

```text
moon 0.1.20260714 (4620153 2026-07-14)
moonc v0.10.4+4f2e8f7dc-nightly (2026-07-13)
moonrun 0.1.20260714 (4620153 2026-07-14)
```

| Package | Exact published identity | Evidence and disposition |
| --- | --- | --- |
| `moonbit-community/harfbuzz@0.1.0` | ZIP SHA-256 `5913988c8efc7b26e173145d694e0d39da15d623240707d9d511f6d04d10807f`; registry build `success` | This is a substantial pure-MoonBit port, but the published manifest has no repository URL, its `PORTING_PLAN.md` marks the generic shaping plan, OT shaping fallback/variation-selector path, and feature-map parity partial, and it excludes Graphite and platform integrations. Current ordinary tests ran 374 cases with 365 passing; nine failures were current debug/snapshot spelling drift rather than observed shaping mismatches. Strict check stopped on 102 current-toolchain warnings/errors. It is not currently a clean, source-traceable product pin. [Registry manifest](https://mooncakes.io/api/v0/manifest/moonbit-community/harfbuzz), [published source](https://download.mooncakes.io/user/moonbit-community/harfbuzz/0.1.0.zip). |
| `Milky2018/moon_swash@0.1.10` | ZIP SHA-256 `5309260ffa4ce54745edcd3fa14514188fcd8d838377e362392362f1d09cc481`; registry build `success` | Provides pure-MoonBit parsing, shaping, scaling, and raster APIs and passed 72/72 ordinary native tests. The published source still labels language/script tables and shaper pieces as minimal, and strict check fails on current-toolchain diagnostics. Keep as a conformance candidate, especially for a future memory-safe runtime, but do not infer full Swash or HarfBuzz parity from its API surface. [Registry manifest](https://mooncakes.io/api/v0/manifest/Milky2018/moon_swash), [published source](https://download.mooncakes.io/user/Milky2018/moon_swash/0.1.10.zip). |
| `Milky2018/moon_skrifa@0.1.8` | ZIP SHA-256 `a96e42abed5bf6f17ba99ecc878d119049d7125f8daeb952b9878263d6a7cb71`; registry build `success` | Provides pure-MoonBit metadata, glyf/CFF/CFF2 outlines, variations, hinting, bitmap helpers, and COLR traversal. It passed 256/256 ordinary native tests; strict check fails on ten newly reserved-identifier diagnostics. It does not replace shaping and lacks a checked terminal conformance matrix. [Registry manifest](https://mooncakes.io/api/v0/manifest/Milky2018/moon_skrifa), [published source](https://download.mooncakes.io/user/Milky2018/moon_skrifa/0.1.8.zip). |
| `Milky2018/moon_zeno@0.1.3` | ZIP SHA-256 `ecdcbb6d618e7a6a7ef0a7b54b56aace408b008ba03d43ed4b2afb264816f6d2`; registry build `success` | Low-level path rasterizer; strict native check/tests passed 13/13. It is promising as a future project-owned outline raster backend but does not load fonts or shape text. Its equivalence to the selected grayscale semantics still needs glyph-corpus and cross-target evidence. [Registry manifest](https://mooncakes.io/api/v0/manifest/Milky2018/moon_zeno), [published source](https://download.mooncakes.io/user/Milky2018/moon_zeno/0.1.3.zip). |
| `Milky2018/moon_cosmic@0.3.3` | ZIP SHA-256 `31a58ed6416690135917d48e3a8a9e0de8286997d92df8ada4e77b2c0b9cdee4`; registry build `success` | Its 294 ordinary native tests passed and it demonstrates that the MoonBit HarfBuzz/Swash/Skrifa/Zeno pieces can interoperate. It is intentionally the wrong seam: it also owns family matching, platform fallback profiles, BiDi, wrapping, text layout, synthetic style, caching, and editor policy. Importing it would pre-decide later svgdiff roadmap items and admits a native macOS fallback profile. [Registry manifest](https://mooncakes.io/api/v0/manifest/Milky2018/moon_cosmic), [published source](https://download.mooncakes.io/user/Milky2018/moon_cosmic/0.3.3.zip). |
| `bikallem/freetype@0.5.3` | ZIP SHA-256 `fdd84ba633d9b8f82c60f2401c6a9d7d7f22c8cd7144b7b83dad65cc95cd84e2`; registry build `success`; preferred target `native` | Claims a broad pure-MoonBit FreeType-compatible parser, hinter, rasterizer, WOFF decoder, and C-FreeType parity corpus. The published archive is not a self-contained verification artifact: whole-module native tests require an ambient `ft2build.h`, while package-only tests abort because referenced font fixtures are absent. Strict current-toolchain warnings are numerous. Its Apache-only port provenance and exact relationship to dual-licensed FreeType also require legal review before redistribution. [Registry manifest](https://mooncakes.io/api/v0/manifest/bikallem/freetype), [published source](https://download.mooncakes.io/user/bikallem/freetype/0.5.3.zip). |
| `mizchi/font@0.7.3` | ZIP SHA-256 `76fdca50dda42fbef34d52e632614901c29151921daf33eb1108cb974717bef0`; registry build `success` | Useful TTF/OTF/TTC/WOFF parsing and outlines, but its own support matrix excludes GSUB, GPOS, GDEF, complex shaping, color tables, hinting, BiDi, and cmap format 14. Glyph rasterization delegates outlines to `mizchi/svg`. The published archive ran 144/195 tests; 51 fixture-dependent tests failed because external font files were absent. It cannot supply the selected runtime. [Registry manifest](https://mooncakes.io/api/v0/manifest/mizchi/font), [published source](https://download.mooncakes.io/user/mizchi/font/0.7.3.zip). |
| `Ronlands/ttf_parser_moonbit@0.1.1` | ZIP SHA-256 `43c045a2234815bca0e3d50bbb58a9b8b9e2998f30d035e0da7b88747fbe18fc`; registry build `legacy` | Basic table/metadata inspection only; its roadmap still lists glyph outlines and WOFF/WOFF2 as future work and the published archive contains no tests. Not a shaping or raster dependency. [Registry manifest](https://mooncakes.io/api/v0/manifest/Ronlands/ttf_parser_moonbit), [published source](https://download.mooncakes.io/user/Ronlands/ttf_parser_moonbit/0.1.1.zip). |

No usable published MoonBit C binding for upstream HarfBuzz plus upstream FreeType was found. The existing `bikallem/freetype` package is a MoonBit reimplementation, not a narrow binding. Therefore the recommended workspace module must own the bindings and static sources itself.

Registry `build_status=success` proves that Mooncakes accepted one package build. It is not evidence of strict current-toolchain cleanliness, complete test fixtures, semantic parity, malformed-font safety, or cross-platform pixel determinism.

## Alternatives

| Alternative | Decision for canonical profile | Reason |
| --- | --- | --- |
| HarfBuzz experimental `libharfbuzz-raster` | Reject for the first profile | The selected HarfBuzz README still labels it experimental and explicitly says font hinting/autohinting is absent. Its consolidation is attractive later, but FreeType has a much older and more explicit glyph-loading/raster contract. |
| `stb_truetype.h` v1.26 at current master `31c1ad37456438565541f4919958214b6e762fb4` | Permanent rejection for untrusted product input | Its own header states that there is no security guarantee and malformed offsets can cause arbitrary reads. It also is not a complex-script shaping engine and does not cover the required format/table surface. It remains acceptable only for trusted throwaway previews. [Exact source](https://github.com/nothings/stb/blob/31c1ad37456438565541f4919958214b6e762fb4/stb_truetype.h). |
| HarfRust `0.12.0`, commit `60b28ea22b5261710018d69c168a762bcb28794c` | Best future shaping replacement; not selected now | Memory-safe Rust and close HarfBuzz alignment are valuable, but the official project records remaining conformance gaps, no stable C ABI, no external integration, and a Rust 1.85 build input. Reconsider after an accepted MoonBit/Rust ABI and representative parity gate. [Project](https://github.com/harfbuzz/harfrust), [release](https://github.com/harfbuzz/harfrust/releases/tag/0.12.0). |
| RustyBuzz `0.20.1`, peeled commit `8c52723ff75e91a33ae36e527baed871097e64bf` | Reject in favor of upstream HarfBuzz/HarfRust | Its documented parity baseline lags current HarfBuzz and its own test count still has known mismatches. It also introduces Rust without providing rasterization or a stable project ABI. [Project](https://github.com/harfbuzz/rustybuzz). |
| `ttf-parser` `0.25.1`, peeled commit `56c33b910b03ca152f78363ec471c5dfd97c3069` | Useful parser oracle only | The project explicitly parses and exposes outlines but does not render or shape. It cannot replace the selected pair. [Project](https://github.com/harfbuzz/ttf-parser). |
| Swash `0.2.9`, crate SHA-256 `0811b01ca2c4e8718760713911feaf4675c24f94e50530a015ec646cfb622f7c` | Future all-Rust experiment, not product dependency | It combines shaping and scaling in Rust but intentionally does not own complete text layout/composition and has no stable C ABI. A conformance corpus and an accepted Rust toolchain/ABI would be prerequisites. [API](https://docs.rs/swash/0.2.9/swash/), [source](https://github.com/dfrg/swash). |
| CoreText, DirectWrite, GDI, browser text, or other platform APIs | Permanent non-goal for the canonical profile; possible separately named observational profiles | Installed fonts, fallback, substitutions, raster modes, and behavior vary by platform and version. CSS Fonts itself permits UA/platform-dependent matching and fallback. A captured browser build remains useful as an oracle, not as canonical font semantics. [CSS Fonts 4 matching](https://www.w3.org/TR/css-fonts-4/#font-matching-algorithm). |
| From-scratch shaping and rasterization inside the root svgdiff module | Reject | The shaping and font-parser state space is too large and security-sensitive, and it would make the comparison engine own unrelated complexity. If a community MoonBit implementation eventually passes the gates, adapt it behind the same seam; if a project-owned implementation becomes necessary, keep it in the separate workspace module and preserve the seam. |

## Licensing and security consequences

Static vendoring makes dependencies auditable and eliminates ambient dynamic-library drift, but it also transfers update and redistribution duties to svgdiff.

- Include HarfBuzz's complete Old MIT text and FreeType's selected FTL text plus required notices in source and binary distributions. Preserve upstream copyright notices and document every local patch. This is implementation guidance, not a legal conclusion.
- The bundle's per-font license evidence is separate from runtime-library licensing. A runtime license does not authorize distributing any Font Resource, and font metadata does not prove redistribution permission.
- HarfBuzz and FreeType parse attacker-controlled, highly structured binary data in C++/C. Input hashes and size caps establish identity and budget, not memory safety. Keep the pre-parser limits from the font-bundle contract, add decoded-table/glyph/axis/recursion/output/work caps, and fail closed.
- Disabling file APIs, environment properties, system backends, compression, color/SVG glyphs, bitmap drivers, hinting bytecode, and unused modules reduces both nondeterminism and attack surface; it does not make the remaining parser safe by assertion.
- Run AddressSanitizer and UndefinedBehaviorSanitizer against the C shim and both libraries, fuzz every admitted entry point with malformed fonts, and run the upstream test suites under the exact build configuration. A hard time/memory limit may require an isolated helper process because an in-process C call cannot be preempted safely.
- Track upstream security releases. A security upgrade creates a new execution profile and conformance result; old report identities remain interpretable, but vulnerable binaries need not remain executable.
- Never include a C pointer, address, allocator behavior, hash-map iteration order, locale, environment value, system path, or wall-clock value in report evidence.

## Verification prerequisites before implementation is accepted

The dependency decision authorizes a bounded implementation experiment, not complete text evidence. The runtime remains unaccepted until all of these gates exist and pass:

1. **Supply-chain lock:** verified tag signatures where available, peeled commits, archive/tree/patch/build hashes, licenses/notices, SBOM, and no undeclared network or system dependency.
2. **Build closure:** clean static builds from a fresh offline checkout on every supported target; runtime versions and artifact hashes match the Font Execution Profile; no dynamic HarfBuzz/FreeType resolution.
3. **ABI safety:** ASan/UBSan, checked lengths and face indices, owned-output/lifetime tests, repeated create/destroy tests, allocator-failure tests, and no borrowed pointer escape.
4. **Admission safety:** malformed/truncated SFNT and collection corpus, table overlap/overflow, excessive glyph/table/axis counts, compound-glyph recursion, CFF subroutine recursion, huge outlines/masks, cancellation, and work-limit tests.
5. **Shaping conformance:** upstream HarfBuzz shaping tests plus a pinned corpus covering Latin, Arabic, Hebrew, Indic families, Southeast Asian scripts, combining marks, emoji sequences, ligatures, kerning, direction, language, features, variation selectors, default ignorables, clusters, and missing glyphs. Compare exact glyph IDs, clusters, advances, and offsets to the selected upstream CLI/library.
6. **Outline conformance:** glyf simple/compound, CFF1/CFF2, collections, malformed outlines, and exact fixed-coordinate comparison against the selected FreeType build.
7. **Raster conformance:** exact grayscale mask bytes across repeated runs, optimization levels, clean processes, and supported target triples for a pinned font/glyph/size/phase corpus. Any target divergence either blocks the profile or creates target-specific profile identities.
8. **Layer separation:** tests prove that source text, selected face, feature/variation inputs, shaped run, positioned glyph, outline, mask, final pixels, Difference Regions, magnitudes, and Cause Envelopes remain individually recoverable.
9. **No ambient fallback:** missing bytes, unsupported containers/tables, absent glyphs, invalid coordinates, and runtime mismatch produce stable errors/Diagnostics and never consult a path, OS font, generic family, browser, or network.
10. **Differential evidence:** compare the selected C stack with at least one independent implementation or browser oracle for the admitted slice. Agreement is evidence; disagreement must be classified, not averaged away.

Only after those gates pass may the Font Execution Profile lift `font_analysis_deferred` for the exact admitted layers. Shaping success alone does not make SVG text layout or final pixels complete, and a grayscale mask alone does not make matching, fallback, color glyphs, or platform rendering complete.

## Explicit non-goals of this dependency decision

- No font loader, matcher, fallback policy, shaper, text layout, or renderer is added to the product by this document.
- No current report schema, renderer identity, equality rule, magnitude, Impact Assessment, or causal-completeness claim changes.
- No system font, CSS `local()`, generic family, filesystem path, network resource, or platform fallback is admitted.
- No claim is made that two library versions, build configurations, target triples, hinting modes, or differently encoded font resources are visually equivalent.
- No WOFF, variable-font, AAT, Graphite, color-font, bitmap-strike, SVG-glyph, hinting, LCD, synthetic-style, vertical-layout, BiDi, or complex SVG text-layout support is implied.
- No automatic legal conclusion is drawn from an SPDX expression, font metadata, registry license label, or upstream dual license.
- No community package is forked or modified by this decision. If later conformance work selects a MoonBit implementation, it must enter through the same project-owned seam and receive a new Font Execution Profile identity.

## Decision consequence

The project has a concrete dependency direction: a native, statically pinned HarfBuzz/FreeType runtime isolated in its own workspace module, with an initially small OpenType/unhinted-grayscale profile and a seam that can later host a conformant MoonBit or Rust replacement. This closes dependency selection without prematurely claiming that font loading, matching, shaping, SVG layout, or glyph evidence is implemented.
