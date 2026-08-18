# Color-Management Profile Boundary

Status: accepted profile architecture; no beyond-sRGB profile is implemented

Profile identity format reserved for future work: `svgdiff-color-execution-profile/1`

External observation identity format: `svgdiff-color-observation/1`

Last verified: 2026-07-17

The current product remains fixed to sRGB source interpretation and `linear_srgb_premultiplied_rgba_f64` raster evidence. Out-of-profile CSS colors, embedded ICC data, non-v1 PNG color metadata, HDR metadata, and high-bit-depth samples retain precise partial coverage Diagnostics. This decision neither converts them nor changes Schema `5.0`.

A future color profile must be an executable contract, not a gamut label. It must close source decoding, color conversion, interpolation, compositing, reference output, perceptual measurement, numeric behavior, resources, and implementation identity. The governing decision is [ADR 0100](adr/0100-stage-color-management-beyond-srgb.md); evidence is recorded in the [research note](research/color-management-profiles.md) and under [`evaluation/color-profile-decision`](../evaluation/color-profile-decision/).

## Required layers

One `svgdiff-color-execution-profile/1` instance must identify all of these independently:

1. **Source admission**: admitted CSS color syntaxes/spaces; embedded raster formats, bit depths, metadata precedence, ICC classes/versions/tags, and exact resource hashes.
2. **Conversion**: transfer functions, matrices or transform pipeline, white points, chromatic adaptation, ICC rendering intent, black-point compensation, extended-range behavior, numeric precision, rounding, and implementation/build identity.
3. **Interpolation**: the property-specific interpolation space, missing-component and hue rules, premultiplication and unpremultiplication order, and gradient/filter behavior.
4. **Working and compositing representation**: linear or encoded components, RGB basis, range, alpha representation, blend-space rules, clipping points, and intermediate precision. Blending and source-over compositing are different operations and cannot share an unspecified shortcut.
5. **Reference output**: one mathematical output color space and dynamic range, plus explicit gamut mapping, clipping, quantization, and tone-mapping policy. A monitor, OS setting, or the word `Display-P3` is not enough.
6. **Measurement**: exact transforms and method identities used by raw raster error, DeltaEOK, FLIP, and any future HDR metric. Perceptual Background values must carry a declared color space before they can be used outside the current sRGB profile.
7. **Execution and limits**: parser and transform limits, deterministic failure outcomes, dependency source/build identity, target identity until cross-target agreement is proved, and renderer-conformance profile compatibility.

The Comparison Profile will eventually reference this identity separately from `schema_version`, `renderer_id`, and `renderer_conformance_profile_id`. A schema version cannot imply color execution, and a color profile cannot imply renderer conformance.

## Staged classification

| Family | Status | Maximum future role |
| --- | --- | --- |
| Current fixed sRGB static profile | Implemented canonical baseline; unchanged | Current complete evidence within the existing support contract |
| CSS Color 4 predefined SDR spaces and PNG `cICP` values that exactly name the same SDR mathematics | First future canonical candidate after a concrete profile, float pipeline, conformance, and schema gates | Canonical evidence only for one exact profile instance and renderer-conformance identity |
| Bounded ICC v4 RGB matrix/TRC input under an exact pinned transform implementation | Deferred canonical candidate | Exact-profile source conversion after hostile-profile, numeric, licensing, and cross-target gates |
| Arbitrary ICC LUT/device-link profiles, ICC v2 behavior, CMYK or N-channel input, custom CSS `@color-profile`, and arbitrary PNG `gAMA`/`cHRM` | Deferred experimental family | Source-preserving offline experiment until a narrow admitted subset and deterministic transform contract are accepted |
| Rec.2100 PQ/HLG, HDR PNG metadata, high-bit-depth HDR samples, and HDR reference-space metrics | Deferred experimental family | Reference-space research under an explicit evolving HDR specification; no current completeness claim |
| Actual HDR/SDR display output, browser color management, OS color systems, display profiles, EDID, adaptive headroom, and device tone mapping | External observation only | One named environment captured under `svgdiff-color-observation/1` |
| Ambient display selection or implicit platform color management inside canonical comparison | Permanent non-goal | None |
| Equality inferred directly between reports with different color execution profiles | Permanent non-goal | None; compare them only through a separately declared cross-profile experiment |

“First future candidate” is not current support and does not schedule the implementation. A concrete candidate must choose every field above; `wide_gamut`, `icc`, `hdr`, or `display_p3` alone is invalid identity.

## Predefined SDR boundary

CSS Color 4 supplies deterministic equations for predefined RGB, XYZ, Lab/LCH, and Oklab/Oklch spaces, chromatic adaptation, interpolation, missing components, hue paths, and alpha premultiplication. This makes its static predefined SDR family the narrowest credible next canonical step.

Admission still requires more than parsing `color(display-p3 ...)`. A future implementation must retain out-of-range components until the declared clipping or mapping stage, implement property-specific interpolation, use a non-lossy float pipeline through compositing and measurement, and define one reference output space. Embedded PNG `cICP` may join a concrete profile only for admitted full-range RGB code points with exact precedence and bit-depth rules. CSS system colors, device-dependent colors, custom profiles, and HDR functions remain outside that slice.

No preferred output target is selected here. Before implementation, a follow-up must choose and conformance-test at least one complete instance, such as a fixed SDR reference output, rather than silently using the host display.

## ICC boundary

ICC bytes are caller-controlled color resources. A profile name, header profile ID, or registry entry does not replace the exact byte hash. A future admitted transform must validate the complete header and tag table, bound decompression and CLUT work, reject overlapping or out-of-range structures, identify source and destination profiles, and pin the transform implementation and its interpolation behavior.

The first credible ICC slice is v4 RGB matrix/TRC input with media-relative colorimetric intent and black-point compensation disabled, converted by an exact project-owned or pinned separately versioned transform seam. This is a candidate, not an accepted production choice. Perceptual and saturation transforms, v2 profiles, LUT pipelines, device links, output profiles, CMYK, N-channel data, named colors, and custom CSS profiles remain experimental because their behavior, profile content, resource cost, or interoperability surface is materially broader.

If a later dependency is needed, it must be evaluated independently for exact-source builds, licenses, hostile-profile safety, numeric reproducibility, bounded in-memory APIs, and type isolation. Platform ColorSync, Windows Color System, browser color management, or another ambient CMS cannot become that canonical seam.

## HDR boundary

HDR is not “wide-gamut with larger numbers.” A complete profile must distinguish scene- and display-referred data, primaries, transfer function, signal range, reference white, absolute luminance, mastering metadata, content-light metadata, surround, headroom, compositing of SDR with HDR, output capability, and tone- or gamut-mapping policy.

Current CSS HDR work remains a Working Draft and explicitly permits output adaptation to device capability and viewing conditions. Svgdiff may later evaluate fixed Rec.2100 PQ, HLG, or linear reference-space mathematics under a named experimental profile. Canonical HDR display equality remains unavailable until the specification, output reference, tone mapper, metric, fixtures, precision, and cross-target behavior are closed. Actual display pixels remain external observations even then.

## Evidence and claim boundary

Before and after inputs always execute under the same color profile. Within one admitted profile, Source Semantics may preserve different authored spaces while Computed Appearance records normalized values and Rendered Evidence records the profile-specific result. Two colors can therefore be source-different, computed-equivalent, or rendered-equivalent after the declared mapping without collapsing those layers.

Reports from different profiles cannot be pooled, compared for equality, or ranked as if their raster values shared a domain. Difference Magnitude methods, Impact inputs, Perceptual Background, FLIP viewing conditions, and renderer conformance must name compatible color semantics. Transparent-canvas raw evidence remains separate from background-composited perceptual evidence.

Unsupported input continues to preserve exact source and resource evidence, emit the current precise Diagnostic, and make only the affected evidence layers partial. No profile may silently retag untagged input, guess a monitor, clip an unsupported space to sRGB, ignore an ICC profile, choose a platform default, or tone-map HDR.

## External observations

`svgdiff-color-observation/1` has either `closed_reference_observation` or `ambient_unreproducible` role. It records, or explicitly marks unavailable:

- exact source and resource hashes; browser/renderer/capture-tool source or binary identity; OS/build, architecture, graphics backend, color-management framework, and process flags;
- every embedded/source profile hash, selected transform and rendering intent, reference/destination profile bytes, display or virtual-target identity, EDID/profile identity when applicable, bit depth, pixel format, alpha, transfer function, color space, and dynamic range;
- reference white, peak and black luminance, SDR/HDR headroom, mastering/content-light metadata, adaptation, gamut/tone mapping, user display settings, ambient/viewing state, background, viewport, DPR, and compositing path; and
- screenshot/capture API and any post-capture conversion or tagging, repeated-capture agreement, output dimensions/format/profile/hash, logs, errors, and unresolved hidden state.

An exact mathematical virtual target may support a closed observation. A physical display, active host profile, unavailable transform state, adaptive headroom, or unknown screenshot conversion forces `ambient_unreproducible`. In either case the exact captured artifact, not the environment description, is the observation's output authority.

Observations remain outside canonical Structured Report evidence. The accepted [multi-renderer boundary](multi-renderer-profiles.md) associates them only through typed profile-sensitivity, conformance, target-observation, or confounded edges; it cannot promote host color behavior implicitly.

## Reconsideration

The staging may change only through a new decision backed by an Agent acceptance case, stable primary specification, exact executable profile, bounded implementation, negative controls, independent conformance fixtures, cross-target determinism evidence, and compatible magnitude semantics. Until then, run the decision gate with:

```sh
sh scripts/test-color-profile-decision.sh
```
