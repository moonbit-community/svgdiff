# Measure event-local DeltaEOK after explicit background compositing

## Context

Raw linear-premultiplied RGBA error preserves transparent-canvas renderer evidence but is not a displayed-color distance. Schema `1.39` records an explicit opaque sRGB Perceptual Background, so a display-dependent color measurement can now avoid guessing white, black, or an SVG-derived paint.

## Decision

Measure DeltaEOK for the exact raw-different pixels attributed to each Visual Event. Convert foreground and background sRGB8 channels to linear sRGB, composite both sides independently over the same declared background, convert the two resulting opaque colors to OKLab, and retain their Euclidean distance. Record the arithmetic mean and sample count under a versioned method ID.

Expose an explicit computed or not-computed state. An absent background and unavailable raw rendered evidence use different reason codes. Zero changed samples and composited equality are numeric zero, not absence.

This channel does not change raw transparent-canvas pixels, Difference Regions, event membership, equality, Diagnostics, Cause Envelopes, or ordering. It is not a visibility boolean, just-noticeable threshold, severity label, FLIP result, or Impact Assessment.

## Consequences

Agents gain one background-aware displayed-color magnitude without losing the independent raw evidence surface. Later work may add p95, maximum, threshold-area, canvas-wide, event-region-area, and FLIP statistics without redefining this method.

The required evidence state advances Structured Report schema to `1.40` and module version to `0.5.20`; renderer and conformance identities remain unchanged.
