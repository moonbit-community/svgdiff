# svgdiff_miniio

Portable WASIp1 CLI for the `Milky2018/svgdiff` visual-semantic comparison
engine.

```sh
moon runwasm cmd/svgdiff_miniio before.svg after.svg
moon runwasm cmd/svgdiff_miniio -- --help
```

The package reads two guest-visible SVG files and writes concise Structured
Report schema `2.0` JSON to stdout. See [`SKILL.md`](SKILL.md) for the
agent-facing interpretation contract and WASI preopen requirements.

Build the WASIp1 artifact with:

```sh
moon build --target wasm cmd/svgdiff_miniio
```
