# ADR 0049: Separate Authored and Used Basic-Shape Geometry

Status: accepted and implemented

## Decision

Keep authored geometry declarations, origins, and Source Spans unchanged in Source Semantics, while resolving a separate canonical used-geometry record for `rect`, `circle`, `ellipse`, `line`, `polyline`, and `polygon`. Alignment, computed relations, parameter magnitudes, conservative bounds, and private renderer-input normalization use the canonical record. Changed Facts continue to describe authored changes.

The resolver implements the current unitless SVG-number slice, omitted defaults, rectangle `auto` dimensions as zero, rectangle radius propagation and clamping, ellipse radius propagation, zero-size non-rendering geometry, line no-interior semantics, open polyline topology with implicit closure for fill, polygon closure, and point-list odd-coordinate recovery. Invalid syntax, negative dimensions or radii, and unsupported units retain source evidence but emit `basic_shape_geometry_unsupported`; they cannot support complete equality.

The private renderer copy may materialize canonical values or a missing paired radius, but the original source is never rewritten. Browser conformance remains a separate claim: measured curved-shape and filled point-shape raster divergences emit renderer-specific Diagnostics even when used geometry is fully resolved.

## Consequences

Equivalent authored forms such as `rx="8"` on a `10 x 6` rectangle and explicit `rx="5" ry="3"` remain source-visible but compare as computed-equivalent. Numeric geometry is not collapsed into a visible/invisible boolean; valid zero-size subjects remain available for source comparison with zero rendered contribution. Percentages, physical units, complete stroke outlines, markers, stylesheet cascade, and precise transformed localization remain later work.
