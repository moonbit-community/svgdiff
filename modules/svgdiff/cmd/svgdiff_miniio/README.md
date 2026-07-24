# svgdiff_miniio

Portable WASIp1 CLI for the `Milky2018/svgdiff` visual-semantic comparison
engine.

After module version `0.7.0` is published:

```sh
moon runwasm Milky2018/svgdiff/cmd/svgdiff_miniio@0.7.0 before.svg after.svg --agent-json
```

From the repository root:

```sh
moon runwasm modules/svgdiff/cmd/svgdiff_miniio testdata/before.svg testdata/after.svg --agent-json
moon runwasm modules/svgdiff/cmd/svgdiff_miniio -- --help
```

The package reads guest-visible files and exposes the same CLI contract as the
native executable, including canonical or Agent JSON, projection JSONL,
resource bundles, HTML, Markdown summary, output files, and an optional
deterministic checkpoint budget. See the module-level
[`SKILL.md`](../../SKILL.md) for the agent-facing interpretation contract and
guest-visible filesystem and resource rules.

Build the WASIp1 artifact with:

```sh
moon build --target wasm modules/svgdiff/cmd/svgdiff_miniio
```
