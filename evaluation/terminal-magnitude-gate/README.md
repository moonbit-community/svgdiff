# Terminal Multidimensional Magnitude Gate

Status: accepted terminal evidence

Gate identity: `svgdiff-terminal-magnitude-gate/1`

Last verified: 2026-07-17

This gate validates the second terminal acceptance item: applicable exact, geometric, raster, coverage, color, and perceptual magnitude evidence remains present in its named units and availability state.

## Exact claim

- Exact local, CSS-pixel, viewport-relative, entity-relative, and tagged transform-effect evidence remains independent from renderer quantization.
- Symmetric painted-boundary distributions, alpha-only coverage, one-sided presence footprints, scene raster response, and intrinsic decoded-raster response retain separate denominators.
- Event-local DeltaEOK requires one explicit opaque sRGB8 background. LDR-FLIP additionally requires explicit Viewing Conditions and preserves its map plus canvas, region, tail, maximum, and optional threshold-area populations.
- Missing or inapplicable evidence remains null or `not_computed`, never measured zero.
- Domain Ordering and Impact Assessment remain derived views and cannot erase or replace the raw fields.

This gate does not create a visibility boolean, severity class, universal scalar, calibrated Impact order, or equality threshold.

## Reproduce

```sh
sh scripts/test-terminal-magnitude-gate.sh
```

The script validates manifest negative controls, focused MoonBit magnitude tests, canonical examples, mutations, Impact, evaluation metrics, and the retained report-only language-model observation. Production probes cover the `1.0` to `0.99999` geometry change, salient paint with DeltaEOK and FLIP, and unsupported text with unavailable magnitude.

The accepted result is:

```text
Terminal multidimensional magnitude gate: passed
```
