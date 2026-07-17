# ADR 0100: Stage color management beyond sRGB

- Status: accepted, not implemented
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

The current profile deliberately interprets supported SVG/CSS and admitted raster samples as sRGB, uses linear-sRGB premultiplied float raster math, and emits precise partial-coverage Diagnostics for wide-gamut, ICC, HDR, or high-bit-depth input. “Support color management” is not one switch: source decoding, interpolation, compositing, gamut mapping, perceptual measurement, and physical output can use different spaces and policies.

CSS Color 4 defines stable mathematical SDR spaces and conversions. ICC profiles add caller-controlled transform programs, intent and interoperability choices. HDR adds absolute luminance, reference white, headroom, mastering and viewing state, and tone mapping; current web HDR work is still evolving. Platform and browser color systems additionally import host and display state.

## Decision

Reserve `svgdiff-color-execution-profile/1` as a future executable color contract separate from Schema, renderer, and renderer-conformance identities. It must close source admission, exact transform resources and algorithms, interpolation, float working/compositing representation, reference output, gamut/tone policy, perceptual measurement, limits, and build identity. Before and after always use the same concrete profile; direct equality across profiles is forbidden.

Keep the current sRGB profile unchanged. Make static CSS Color 4 predefined SDR mathematics the first future canonical candidate, but require a later decision to select and conformance-test a complete output instance. Defer bounded ICC v4 RGB matrix/TRC conversion behind a separately evaluated deterministic transform seam. Keep arbitrary ICC/custom-profile and HDR reference-space work experimental. Keep actual display, browser, OS, and adaptive HDR results external observations under `svgdiff-color-observation/1`.

Ambient display selection, implicit platform color management, silent retagging, unsupported-space clipping to sRGB, ignored ICC data, implicit gamut mapping, and implicit HDR tone mapping are permanent non-goals for canonical comparison.

## Consequences

Current product behavior, Schema `1.44`, Diagnostics, public APIs, dependencies, and renderer identities do not change. Future profiles can add color coverage without claiming one universal display result, but each implementation must carry substantial conversion, precision, security, conformance, and metric evidence. Platform observations may challenge a canonical implementation but cannot establish its equality or completeness directly.

## Rejected alternatives

- Add one `wide_gamut` or `hdr` flag: it omits the spaces, transfer functions, working representation, output, mapping, and viewing policy that determine pixels.
- Treat every color as sRGB numbers: this silently retags data and can erase the main visual difference.
- Convert everything immediately to bounded sRGB8: early clipping loses wide-gamut and HDR evidence before interpolation, compositing, or measurement.
- Use the host ICC/CMS and active display automatically: the result imports undeclared platform and device state.
- Make arbitrary ICC the first implementation: untrusted transform programs, multiple intents/classes, broad numeric behavior, and resource costs are a much larger seam than predefined CSS mathematics.
- Make Display-P3 or Rec.2020 a physical-display promise: a mathematical RGB space does not identify a display, luminance, profile, pipeline, or tone mapper.
- Compare reports from different profiles directly: their rendered values and perceptual measurements do not share one declared observation domain.
