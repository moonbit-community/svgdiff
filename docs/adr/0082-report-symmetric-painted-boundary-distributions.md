# Report symmetric painted-boundary distributions

## Context

One maximum boundary displacement cannot distinguish a broad movement from a mostly stable contour with one outlier. The engine already computes an exact Euclidean distance transform for guarded path boundaries, but retaining only the symmetric maximum discards the distribution and its sampling support. Reusing exact parameter displacement, changed coverage, or color error would collapse different evidence layers.

## Decision

Add nullable `painted_boundary_displacement` evidence to Difference Magnitude. A measured object uses method ID `symmetric_nearest_boundary_pixels/v1`, records before and after sample counts, and reports arithmetic mean, nearest-rank p95, and maximum distances in CSS pixels.

The method samples centers of pinned-renderer pixels whose alpha is greater than zero and that touch the viewport edge or a four-connected zero-alpha neighbor. It computes every before sample's Euclidean distance to the nearest after boundary and every after sample's distance to the nearest before boundary, concatenates both directions, sorts the combined samples, and divides device-pixel statistics by Comparison DPR. Nearest-rank p95 uses index `ceil(0.95 * sample_count) - 1`. Concatenation makes the result invariant under swapping before and after.

Both-empty isolated boundaries produce zero statistics with zero sample counts. Exactly one empty boundary, different image dimensions, unsupported isolation, or budget exhaustion produces null. Cache one observation per entity Subject Alignment and attach it to each related geometry Atomic Difference. Path observations continue to expose their distribution maximum through the existing `geometry_displacement_css_px`; independently computed analytic geometry outcomes remain unchanged.

Do not attach the object to paint-only, resource-role, presence, or unaligned differences. Resource-backed paint and active marker, clip, mask, or filter isolation remain unavailable until the project can reproduce those resources honestly in the isolated surface. The distribution is pinned-raster support evidence, not continuous vector Hausdorff distance, semantic point correspondence, signed displacement, soft coverage, color, visibility, or importance.

## Consequences

Agents can distinguish typical boundary motion from tail and worst-case motion and can see how many samples support the statistics. Mean and p95 are independent summaries: a sparse outlier set can make the arithmetic mean positive while nearest-rank p95 remains zero, so consumers must not assume `mean <= p95`. Quantization and nearest-boundary ambiguity remain explicit: a nonzero exact geometry change may have a zero distribution, and repeated contours may match the nearest wrong contour. The following roadmap item separately owns symmetric soft coverage difference.

The required nullable object advances Structured Report schema to `1.37` and module version to `0.5.17`. Renderer identity, conformance profile `/25`, ordering policy, Diagnostics, and v2 ordering tuples remain unchanged.
