---
name: svgdiff
description: "Compare two deterministic static SVG files by visual semantics with the native/WASIp1 svgdiff CLI, producing compact Structured Report JSON for agents that cannot inspect images. Use when an agent must enumerate visual-semantic differences, magnitudes, conservative locations, possible causes, and coverage limitations."
---

# svgdiff

## Run

From this repository, use the checked-in fixtures for a self-contained smoke
test:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff testdata/before.svg testdata/after.svg --agent-json
```

After module version `0.7.0` is published, run the pinned package directly:

```sh
moon runwasm Milky2018/svgdiff/cmd/svgdiff@0.7.0 before.svg after.svg --agent-json
```

The command writes canonical Structured Report schema `2.0` JSON by default;
pass `--agent-json` for the same report without formatting whitespace. It
accepts exactly two guest-visible SVG paths. Use `-` for at most one input to
read it from stdin.

To inspect the skill's own help through `moon runwasm`, separate the forwarded
flag from the runner's flags:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff -- --help
```

Inspect the exact engine, schema, renderer, conformance, and policy identities
before interpreting or retaining a report:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff -- --version
```

Record this output alongside reports that will be persisted, compared, or
handed off. The report schema version alone does not identify every
rendering-related implementation input.

Useful explicit comparison inputs:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff before.svg after.svg \
  --width 256 \
  --height 256 \
  --max-checkpoints 1000000 \
  --agent-json
```

Optional displayed-color evidence requires an opaque background. LDR-FLIP
additionally requires pixels per degree:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff before.svg after.svg \
  --perceptual-background '#ffffff' \
  --flip-pixels-per-degree 67 \
  --agent-json
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

## Filesystem and resources

All input and resource paths are guest-visible. `moon runwasm` exposes the
project directory when running the local package. The comparison runtime
performs no network access or implicit SVG-authored path resolution; the
`moon runwasm` launcher may still download the module or dependencies before
execution.

External raster resources may be supplied explicitly with the same repeatable
`--before-resource` and `--after-resource` JSON options as the native CLI.
Their paths must also be guest-visible. Argument and file errors exit with
status `2`; comparison interruption or a failed analysis exits with status `1`.
