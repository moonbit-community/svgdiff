# SVG Diff Engine

This package contains the formal comparison engine behind the root `Milky2018/svgdiff` interface. It implements the supported deterministic static-SVG subset and conservatively reduces analysis coverage whenever required semantics are unavailable.

Run the engine test suite with:

```sh
moon test engine --target native
```

## Package seam

The engine exposes the comparison seam consumed by the root package:

```text
compare(before_svg, after_svg, comparison_profile) -> structured_report
```

Callers should normally import `Milky2018/svgdiff`; the root package pins v1 comparison conditions and exposes the stable report interface. The engine package owns source, computed, and rendered analysis, subject alignment, magnitudes, regions, cause envelopes, and conservative diagnostics.
