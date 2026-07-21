# SVG Diff Engine

This directory contains the formal comparison engine behind the root `Milky2018/svgdiff` interface. It implements the supported deterministic static-SVG subset and conservatively reduces analysis coverage whenever required semantics are unavailable.

Run the engine test suite with:

```sh
moon test engine --target native
```

## Package seam

The `Milky2018/svgdiff/engine` facade exposes the comparison seam consumed by the root package:

```text
compare(before_svg, after_svg, comparison_profile) -> structured_report
```

Callers should normally import `Milky2018/svgdiff`; the root package pins v1 comparison conditions and exposes the stable report interface. The facade owns no comparison algorithms. Public report types live in `model`, the optional metadata audit lives in `source`, and implementation packages are arranged in one dependency direction below `engine/internal`.

```text
engine
├── model                         public comparison profile and report model
├── source                        independent nonvisual source audit
├── internal/source               XML, CSS, authored values, and structural IR
│   ├── css_color                 supported source color syntax
│   ├── number_parser             finite SVG-style numeric scanning
│   ├── path_data                 path parsing with source offsets
│   └── embedded_data_url         embedded raster URL parsing
├── internal/computed             viewport, length, transform, and bounds values
│   ├── geometry                  shape, path-bound, and stroke computation
│   ├── style                     inherited and effective visual properties
│   ├── structure                 use/definition and viewport semantics
│   ├── resources                 gradients, patterns, markers, clip, mask, images
│   ├── effects                   filter and blend semantic models
│   ├── affine_transform          affine math and transform-list parsing
│   └── arc_geometry              elliptical-arc geometry and bounds
├── internal/ir                   shared resolved visual subjects
├── internal/rendered             raster evidence and group compositing
│   ├── normalization             renderer-input normalization
│   ├── effects                   filter and blend raster evaluation
│   └── ldr_flip                  pure LDR-FLIP computation
├── internal/alignment            structural and visual subject alignment
├── internal/measurement          magnitude and difference-region measurement
├── internal/attribution          cause envelopes and resource dependency graph
├── internal/resource_diff        resource/effect-specific atomic differences
├── internal/diff                 remaining entity diffs and report orchestration
├── internal/resource_model       resource bundles and deterministic limits
├── internal/report_support       report constructors and shared report queries
└── internal/control              deterministic cancellation checkpoints
```

No implementation package imports the `engine` facade. Dependencies flow from source and computed semantics through shared IR, rendered evidence, alignment/measurement/attribution, and finally report orchestration. `internal/diff` and `internal/resource_diff` consume the lower layers; no lower layer imports either diff package. The facade only adapts cancellation and resource inputs, preserving the existing `Milky2018/svgdiff/engine` API.

The [current support contract](../docs/v1-scope.md) defines when this engine may return complete analysis. The [core comparison model](../docs/core-model.md) defines the report concepts, and the checked-in [JSON Schema](../schema/svgdiff-report.schema.json) defines the serialized contract.
