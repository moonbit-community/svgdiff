# Expose optional event-local LDR-FLIP maps

## Context

Changed-pixel mean DeltaEOK measures displayed color distance but has no spatial-frequency model. FLIP is designed as a spatial error map for alternating rendered images, but its result depends on pixels per degree and its filtering can mix unrelated changes if a whole comparison canvas is treated as one event.

## Decision

Make LDR-FLIP opt-in through explicit finite pixels-per-degree Viewing Conditions in the supported `[1, 4096]` range. This prevents degenerate or unbounded kernels without inventing a default display. Do not assume the reference implementation's default display geometry. Continue to require the same explicit Perceptual Background and composite both inputs over it in linear sRGB.

Compute one event-local FLIP map with the before rendering as the reference and context image, changing only the raw-different pixels selected by that event's Difference Regions to their after values. Serialize only the complete response bounds, not the extra convolution context, using deterministic uint16 big-endian base64 with the quantization step recorded. The underlying FLIP metric is symmetric for a fixed image pair, but event isolation is intentionally directional when other events alter the surrounding context; reversing the comparison creates a new before-context map. Apply fixed aggregate output and work budgets and report exhaustion as unavailable map evidence rather than weakening other evidence layers.

This channel does not define equality, visibility, a just-noticeable threshold, a pooled score, severity, or Impact Assessment. Pooled canvas/event statistics remain a separate decision and must use the unquantized internal map.

## Consequences

Agents and later presentation code can locate spatially distributed perceptual response without conflating it with exact geometry, raw RGBA error, DeltaEOK, or importance. Reports remain compact enough for explicit opt-in use, and comparisons that do not request FLIP pay no FLIP computation or map-size cost.

The required profile and evidence fields advance Structured Report schema to `1.41` and module version to `0.5.21`; renderer identity, conformance profile, Diagnostics, coverage, equality, and ordering remain unchanged.
