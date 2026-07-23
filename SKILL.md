---
name: svgdiff
description: "Compare two SVG files by visual semantics and emit compact Structured Report JSON for an agent that cannot inspect images."
---

# svgdiff

Use this skill when an agent needs to determine what visually changed between
two deterministic static SVG files without relying on multimodal inspection.
It reports authored distinctions, computed relations, independent numeric
magnitudes, rendered outcomes, conservative locations, possible causes, and
analysis limitations.

## Run

After module version `0.7.0` is published:

```sh
moon runwasm Milky2018/svgdiff/cmd/svgdiff_miniio@0.7.0 before.svg after.svg
```

From this repository, use the checked-in fixtures for a self-contained smoke
test:

```sh
moon runwasm cmd/svgdiff_miniio testdata/before.svg testdata/after.svg
```

The command writes concise Structured Report schema `2.0` JSON to stdout. It
accepts exactly two guest-visible SVG paths. Use `-` for at most one input to
read it from stdin.

To inspect the skill's own help through `moon runwasm`, separate the forwarded
flag from the runner's flags:

```sh
moon runwasm cmd/svgdiff_miniio -- --help
```

Useful explicit comparison inputs:

```sh
moon runwasm cmd/svgdiff_miniio before.svg after.svg \
  --width 256 \
  --height 256 \
  --max-checkpoints 1000000
```

Optional displayed-color evidence requires an opaque background. LDR-FLIP
additionally requires pixels per degree:

```sh
moon runwasm cmd/svgdiff_miniio before.svg after.svg \
  --perceptual-background '#ffffff' \
  --flip-pixels-per-degree 67
```

## Interpret the report

1. Read `analysis_status` first. Only `complete` with no Atomic Differences
   establishes profile-scoped equality.
2. Enumerate every item in every `difference_groups` group, including
   effective-equivalent changes and changes whose owning event measures zero.
3. Treat each item's sparse `magnitude` as direct evidence for that Atomic
   Difference. Omitted fields are not zero.
4. Follow `events[].difference_ids` for the owning rendered outcome, optional
   shared `isolated_subject` measurements, conservative regions, and possible
   causes.
5. A `sound_overapproximation` cause set may contain false positives but
   includes every actual cause within complete supported coverage. It does not
   prove that every candidate contributed.
6. Report every entry in `limitations` before making equality or magnitude
   claims.
7. Keep changed fraction, linear RGBA RMSE, perceptual response, geometry,
   coverage, and other domain magnitudes independent. Do not invent a universal
   severity score or suppress small differences.

## WASI filesystem

All paths are guest-visible. `moon runwasm` exposes the project directory when
running the local package. With a standalone WASI host, preopen the directory
that contains the input SVGs:

```sh
wasmtime run --dir ./examples::examples \
  svgdiff_miniio.wasm examples/before.svg examples/after.svg
```

The skill performs no network access and resolves no ambient host paths.
External raster resources must currently be embedded as supported `data:` URLs.
Argument and file errors exit with status `2`; comparison interruption or a
failed analysis exits with status `1`.
