---
name: svgdiff
description: "Compare two deterministic static SVG files by visual semantics with the native/WASIp1 svgdiff CLI, producing compact Structured Report JSON for agents that cannot inspect images. Use when an agent must enumerate visual-semantic differences, magnitudes, conservative locations, possible causes, and coverage limitations."
---

# svgdiff

## Run

From this repository, use the checked-in fixtures for a self-contained smoke
test:

```sh
moon run --target wasm modules/svgdiff/cmd/svgdiff -- testdata/before.svg testdata/after.svg --agent-json
```

Run the published module version `0.10.9` directly:

```sh
moonx Milky2018/svgdiff/cmd/svgdiff@0.10.9 before.svg after.svg --agent-json
```

The command writes canonical Structured Report schema `5.0` JSON by default;
pass `--agent-json` for the same report without formatting whitespace. It
accepts exactly two guest-visible SVG paths. Use `-` for at most one input to
read it from stdin.

To inspect the skill's own help through `moon run --target wasm`, separate the forwarded
flag from the runner's flags:

```sh
moon run --target wasm modules/svgdiff/cmd/svgdiff -- --help
```

Inspect the command and report schema versions before retaining a report:

```sh
moon run --target wasm modules/svgdiff/cmd/svgdiff -- --version
```

Record this output alongside reports that will be persisted or handed off.

Useful explicit comparison inputs:

```sh
moon run --target wasm modules/svgdiff/cmd/svgdiff -- before.svg after.svg \
  --width 256 \
  --height 256 \
  --max-checkpoints 1000000 \
  --agent-json
```

Optional displayed-color evidence requires an opaque background. LDR-FLIP
additionally requires pixels per degree:

```sh
moon run --target wasm modules/svgdiff/cmd/svgdiff -- before.svg after.svg \
  --perceptual-background '#ffffff' \
  --flip-pixels-per-degree 67 \
  --agent-json
```

## Interpret the report

1. Read `analysis_status` and `scene.summary` first. Treat `content`,
   `object_set`, `relation_graph`, `layout`, `style`, and `representation` as
   independent conclusions; do not collapse them into one severity score.
2. Read `changed_facts` as the canonical cause inventory. Then read
   `scene.object_changes` and `scene.events`: Scene Changes reference Object
   Changes only. Keep cause, effect, subject, and object counts distinct.
3. Check both `scene.evidence_coverage` transitions; unresolved Atomic
   Differences and residual Object Changes remain evidence, not equality.
4. Enumerate every item in every `difference_groups` group, including
   effective-equivalent changes and changes whose owning event measures zero.
5. Treat each item's sparse `magnitude` as direct evidence for that Atomic
   Difference. Omitted fields are not zero.
6. Follow `events[].difference_ids` for the owning rendered outcome, optional
   shared `isolated_subject` measurements, conservative regions, and possible
   causes.
7. A `sound_overapproximation` cause set may contain false positives but
   includes every actual cause within complete supported coverage. It does not
   prove that every candidate contributed.
8. Report every entry in `limitations` before making equality or magnitude
   claims.
9. Keep changed fraction, linear RGBA RMSE, perceptual response, geometry,
   coverage, and other domain magnitudes independent. Do not invent a universal
   severity score or suppress small differences.

## Filesystem and resources

Run from the project directory and use input and resource paths visible to
the Wasm guest. The comparison runtime performs no network access or implicit
SVG-authored path resolution. `moonx` may download the command before execution.

External raster resources may be supplied explicitly with the same repeatable
`--before-resource` and `--after-resource` JSON options as the native CLI.
Their paths must also be guest-visible. Argument and file errors exit with
status `2`; comparison interruption or a failed analysis exits with status `1`.
