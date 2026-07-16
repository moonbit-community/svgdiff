# Use device-space feature distance for rendered-subject alignment

## Context

Rendered subjects previously matched exactly by local normalized visual properties and otherwise minimized raw property distance. Cumulative transforms were absent from both stages. Two locally identical subjects at different final placements could therefore align by source order, while a local geometry change compensated by a transform could be treated as farther apart even though the final geometry coincided.

The correspondence score is selection evidence, not a visual Difference Magnitude. It must remain deterministic and bounded, use the caller's Comparison Viewport, and avoid counting the same placement change once through local geometry and again through transforms.

## Decision

Exact direct-subject signatures include the complete cumulative affine transform and conservative painted bounds in device space. Rendered `use` leaves retain exact instance-path precedence; split and merge rules retain their existing precedence.

For remaining compatible-kind candidates, minimize `rendered_geometry_feature_distance_v1` with the existing deterministic Hungarian assignment. The score is the arithmetic mean of available features, each in `[0, 1]`: painted-bounds center and size displacement normalized by the Comparison Viewport diagonal, non-geometry appearance-property difference, hierarchy agreement, and device-space normalized path-segment difference for paths. Raw basic-shape geometry properties are excluded from appearance distance.

When both sides lack painted bounds, four cumulative-transform probes at the Comparison Viewport corners substitute for the bounds feature. Probes are omitted when bounds exist because those bounds already encode final placement. One-sided bounds or transform availability contributes `1`; features unavailable on both sides are omitted. Numeric feature deltas use `d / (1 + d)` after their stated normalization, so the aggregate remains bounded. Exact score ties retain stable signature and source-index ordering.

Complete normalized paths without arcs receive conservative bounds from the control hull of every endpoint and Bezier control point, transformed to device space and expanded by admitted stroke, marker, clip, and mask effects. An arc keeps these bounds unavailable because endpoint and control-hull data do not establish its extrema; arc parameters may still participate in the path correspondence feature.

## Consequences

Transform-swapped shapes and local-geometry/transform compensation pairs can correspond by final placement without candidate rasterization. The caller's viewport affects the dimensionless normalization but not the report's visual Difference Magnitudes.

The score is a versioned heuristic over one compatible-kind candidate set. It is not rendered equality, perceptual distance, calibrated confidence, contribution attribution, group aggregation, or Visual Resource alignment. Structural subjects keep their separate authored-ID/path/order policy. Robust repeated-subject matching, broader split/merge validation, precise continuous path bounds, and raster correspondence remain separate work.

This changed interpretation of Subject Alignment evidence advances Structured Report schema to `1.33` and module version to `0.5.13`. Renderer identity and conformance profile `/25` do not change because the pixel pipeline is unchanged.
