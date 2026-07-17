# ADR 0098: Own a pinned font runtime module

- Status: accepted
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

The accepted Font Bundle fixes raw font inputs but does not select the code that turns them into glyph IDs, outlines, or coverage. Library names alone are insufficient: source versions, build features, target ABI, shaping inputs, hinting, raster mode, and ambient platform integrations can change output. Importing a text-layout package would also pre-decide family matching, fallback, BiDi, wrapping, and layout that belong to separate roadmap items.

Current Mooncakes packages provide valuable pure-MoonBit parsing, shaping, and raster components, but no inspected published combination currently closes strict-toolchain cleanliness, exact upstream parity, self-contained fixtures, hostile-input limits, and representative script/raster conformance. Direct system HarfBuzz/FreeType use would instead make results depend on undeclared machine packages.

## Decision

Select exact-source HarfBuzz `14.2.1` and FreeType `2.14.3` behind a separately versioned project workspace module, provisionally `Milky2018/svgdiff-font-runtime`. The module will statically vendor the selected source archives, own a narrow C ABI and MoonBit facade, and expose only project-owned faces, shaping requests/results, outlines, grayscale masks, and errors.

HarfBuzz independently consumes verified bytes and uses built-in Unicode data, OpenType font functions, units-per-em scale, and an explicitly selected `ot` shaper. FreeType independently consumes the same bytes and exact face index for unhinted outlines and normal grayscale coverage. Do not use `hb-ft` in the canonical shaping path and do not expose upstream handles.

Adopt `svgdiff-font-runtime-build/1` as the required build-identity format and `svgdiff-font-execution-slice/1` as the initial bounded capability set. The initial slice covers only raw SFNT/collections, explicit single-direction OpenType runs, static glyf/CFF1 outlines, and unhinted grayscale masks. All matching, fallback, BiDi, SVG layout, variables/CFF2, WOFF, AAT/Graphite, hinting, subpixel, bitmap, color/SVG glyph, synthetic-style, and platform behavior remains gated.

Keep current MoonBit font implementations as differential oracles and possible future replacements behind the same facade. A replacement or dependency upgrade creates a new runtime build and Font Execution Profile identity.

## Consequences

The future comparison engine can inspect shaping, geometry, and coverage separately without owning upstream APIs or a broad editor/layout stack. Exact static sources and disabled integrations reduce ambient drift and attack surface, but C/C++ font parsing still requires hard resource limits, sanitizers, fuzzing, conformance, security updates, license notices, and target-specific evidence.

This decision adds no dependency or font behavior now. Current Structured Reports, public interfaces, schema, renderer identity, release assets, and `font_analysis_deferred` behavior remain unchanged.

## Rejected alternatives

- Import `Milky2018/moon_cosmic`: it owns matching, fallback, BiDi, wrapping, layout, caching, and platform policy outside this decision.
- Select current MoonBit font components as canonical immediately: their current releases are promising conformance candidates but do not yet satisfy the complete acceptance gates.
- Link system HarfBuzz/FreeType: package versions, build features, dynamic resolution, and platform behavior would be undeclared inputs.
- Use `hb-ft` for shaping: mutable FreeType scale and loading state would couple outline/raster choices into shaping.
- Use `stb_truetype`: it neither supplies complex shaping nor promises safety for malformed untrusted fonts.
- Implement shaping and rasterization in the root module: the state space and security burden would make the comparison engine own unrelated complexity.
