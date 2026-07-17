# Platform-Native Font Rendering Boundary

Status: accepted profile boundary; no platform font backend is implemented

Observation identity format: `svgdiff-platform-font-observation/1`

Last verified: 2026-07-17

Platform-native font rendering is a permanent non-goal for svgdiff's canonical deterministic Font Execution Profiles and complete-analysis claims. CoreText, DirectWrite/ClearType, GDI, browser text, and comparable system stacks may be captured only as separately versioned external observations. They cannot replace the selected project-owned Font Runtime Module or enter canonical equality, Difference Magnitude, coverage, Impact, or causal evidence.

The governing decision is [ADR 0099](adr/0099-keep-platform-font-rendering-observational.md). Primary-source evidence is recorded in the [research note](research/platform-native-font-rendering.md), and the machine-checkable classification lives under [`evaluation/platform-font-modes`](../evaluation/platform-font-modes/).

## Classification

| Mode | Status | Maximum claim |
| --- | --- | --- |
| Pinned project Font Runtime Module plus closed Font Bundle | Future canonical candidate after its own safety and conformance gates | Complete evidence only for the exact admitted Font Execution Profile |
| Platform-native rendering from an exact closed Font Bundle | Conditionally permitted future external observation | Named-target raster/shaping observation and conformance input; never canonical report evidence |
| Browser rendering from an exact closed Font Bundle | Conditionally permitted under the existing external browser-oracle boundary | Browser-build observation and conformance input; never canonical report evidence |
| Platform or browser rendering with system discovery, generic family, `local()`, automatic fallback, or downloadable fonts | Exploratory ambient observation only | Description of what one captured environment produced; never a reproducible or conformance disposition |
| Platform-native rendering as the canonical Font Execution Profile | Permanent non-goal | None |

The first row is not implemented. The remaining rows do not create current product support, CLI modes, report fields, or fixtures.

## Ambient font boundary

System-font discovery, family-name matching, generic families, `local()`, automatic substitution/cascading, platform fallback, user-installed fonts, downloadable fonts, and network font services are permanently forbidden inputs to a canonical deterministic comparison. Recording an OS name, installed-family list, or resolved PostScript name does not close that environment.

An external experiment may capture ambient output to answer “what did this machine display?” It must label the result `ambient_unreproducible`, retain the exact output artifact and capture metadata, and make no equality, completeness, renderer-conformance, or product-disposition claim. Hashing resolved font files after capture improves provenance but cannot retroactively prove that matching, fallback, timing, or hidden platform state was reproducible.

## Closed-bundle native observations

A future platform observation may use only exact caller-supplied Font Resources when the platform API supports application-owned font data or collections. It must prohibit system collection merging, fallback, name-based substitution, remote/downloadable fonts, and asynchronous replacement. Every selected face and glyph must trace to one Font Face Locator and raw hash from the closed bundle.

This closes font acquisition but not the rendering implementation. CoreText and DirectWrite remain OS/framework code with target-specific shaping, raster, antialiasing, measuring, color-glyph, fallback, and policy behavior. Their results are observations of a named environment, not another implementation of `svgdiff-font-execution-slice/1`.

## Observation identity

Every permitted capture uses `svgdiff-platform-font-observation/1` and records, or explicitly marks unavailable, all of these inputs:

- observation role (`closed_bundle_oracle` or `ambient_unreproducible`), platform API, API generation, OS product/build, target architecture, process/runtime identity, and capture-tool source/binary hash;
- exact SVG/text input hash, Font Bundle Fingerprint and manifest digest when closed, every resolved Font Face Locator/raw hash, variation coordinates, features, language, script, direction, and fallback result;
- viewport, DPR/output scale, text transform, baseline/origin/phase, target dimensions, pixel format, alpha mode, color space, background, and compositor;
- shaping/layout API and options plus rendering, measuring, grid-fit, antialiasing, grayscale/LCD, pixel geometry, gamma, contrast, font smoothing, synthetic-style, hinting, color/bitmap/SVG-glyph, and cache settings;
- locale, language preferences, user font/smoothing preferences, display or virtual-device identity, CPU/GPU/software path, driver identity when observable, sandbox state, and network-disabled state; and
- warm/cold process state, repeated-capture count, byte-identity result, output dimensions/format/hash, logs, unresolved hidden state, and tool errors.

An unavailable field is evidence of a limit, not permission to omit the input from reasoning. Even a fully populated record does not promise reproduction on a nominally identical OS: undocumented implementation state may remain. The exact captured bytes and their hash are authoritative for the observation.

## Claim boundary

Platform Font Observations remain outside the comparison engine and Structured Report. They may:

- expose a disagreement between the canonical runtime and one named platform;
- supply independent target-specific conformance evidence;
- motivate a canonical adapter, narrower support declaration, or stable Diagnostic through a separately reviewed conformance decision; and
- help an Agent explain why a user screenshot differs from canonical output, while clearly labeling the external environment.

They may not:

- establish visual equality, complete text analysis, or a zero Difference Magnitude;
- replace exact Source Semantics, Shaped Runs, outlines, masks, regions, or causal evidence;
- pool several platform outputs into one canonical result or majority vote;
- make an ambient-font capture a conformance baseline; or
- silently change renderer, font, execution, schema, ordering, or Impact identities.

The accepted [multi-renderer boundary](multi-renderer-profiles.md) permits both same-target profile sensitivity and same-profile target observations through separate typed edges. It preserves this decision's non-canonical role: a platform font cell cannot become complete canonical evidence merely by joining a matrix.

## Reconsideration

The permanent canonical exclusion may be reconsidered only if a concrete Agent or user task cannot be served by the project runtime plus external observations, and one native stack exposes a closed byte-based font set, all shaping/raster inputs, stable implementation identity, offline execution, hard resource limits, exact repeated and cross-host conformance, and evidence-layer outputs rather than only pixels. Any accepted target would receive a new explicitly platform-specific product profile; it would not redefine the portable canonical profile.

Until then, the existing browser oracle remains font-free and the current engine continues to report font-dependent text as partial. Run the decision gate with:

```sh
sh scripts/test-platform-font-modes.sh
```
