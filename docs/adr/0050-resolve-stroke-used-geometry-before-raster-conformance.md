# ADR 0050: Resolve Stroke Used Geometry Before Raster Conformance

Status: accepted and implemented for the unitless static slice

## Context

Authored stroke declarations do not directly describe the geometry that reaches a renderer. Defaults, inactive paint or topology, odd dash-list duplication, all-zero dash collapse, offset normalization, joins, miter limits, transforms, and `non-scaling-stroke` can make distinct source values computed-equivalent or make a small scalar change produce a transform-dependent boundary movement. Treating these values as unrelated text facts loses the semantic relation; trusting the pinned renderer alone also confuses dependency-specific raster differences with SVG semantics.

## Decision

Preserve every authored stroke fact, declaration origin, inheritance owner, and Source Span, then resolve a separate canonical used-geometry record for unitless `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`, `stroke-dasharray`, `stroke-dashoffset`, and `vector-effect`.

Canonicalization follows the admitted SVG 2 slice: defaults are materialized, negative widths/miter limits/dash entries and unsupported syntax are diagnosed, odd dash lists duplicate, all-zero lists become solid, and effective offsets normalize by the even pattern sum. Source differences remain reportable when stroke paint, zero width, or shape topology makes their computed contribution inactive.

Stroke width is a geometry domain. Its parameter magnitude is the full width delta, while its boundary displacement is half that delta multiplied by the maximum linear transform scale for ordinary strokes. `non-scaling-stroke` uses host-space CSS pixels instead. Miter limits and dash offsets retain numeric parameter magnitudes without claiming that the scalar itself is Cartesian displacement.

Conservative bounds may overapproximate caps and joins but must contain every admitted contribution. Ordinary stroke expansion happens in local user space before the cumulative transform; non-scaling stroke expands the transformed path in host space.

The private renderer-input copy receives canonical stroke values, but Source Semantics continues to use the original SVG. Renderer conformance remains a separate layer: zero-width stroke is admitted by an exact Chromium fixture, while active outline, join, dash, and non-scaling-stroke rasterization receive distinct stable guards under conformance profile `/6`.

## Consequences

Agents can distinguish source-only stroke rewrites, small numerical geometry changes, inactive properties, and visually meaningful used-geometry changes without relying on raw XML or pixels alone. Alignment, Atomic Differences, ordering, Difference Regions, and Cause Envelopes share the same canonical values and conservative bounds.

The implementation does not claim exact continuous outline construction, marker geometry, `pathLength` calibration, percentage or physical stroke lengths, full stylesheet cascade, or deterministic font-dependent stroke behavior. Those remain explicit roadmap items rather than implicit renderer behavior.
