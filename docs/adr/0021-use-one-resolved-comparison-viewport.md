# Use one resolved Comparison Viewport

Both SVG inputs will be evaluated and rendered under one Comparison Viewport. The viewport may be derived when both inputs declare the same valid intrinsic viewport; otherwise the caller must provide it explicitly, because independently inferred canvases would make pixel, coverage, and perceptual measurements incomparable. Differences between the inputs' own viewport declarations remain reportable as `document.viewport` Atomic Differences even when an explicit common viewport is used.
