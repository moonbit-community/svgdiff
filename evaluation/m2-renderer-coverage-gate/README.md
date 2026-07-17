# M2 Renderer and Coverage Safety Gate

`gate.v1.json` ties the six required safety links together:

1. reproducible browser-versus-pinned-renderer observations;
2. one reviewed disposition for every divergence;
3. encountered renderer capability projection;
4. centralized coverage proof;
5. status composition from coverage cells; and
6. unsupported self-comparison false-equality properties.

Run the focused product gate with:

```sh
sh scripts/test-m2-renderer-coverage-gate.sh
```

Reproduce the Chromium baseline separately with:

```sh
sh scripts/test-renderer-conformance.sh
```

The baseline is an observation. This gate succeeds only because every divergence is dispositioned and every unproven evidence layer prevents an invalid complete claim.
