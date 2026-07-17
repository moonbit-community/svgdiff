# M5 Explicit Non-goal Coverage Gate

Status: accepted milestone evidence

Gate identity: `svgdiff-m5-nongoal-coverage-gate/1`

Last verified: 2026-07-17

This gate composes the accepted advanced-capability decisions with current product coverage guards. It establishes only that every currently unadopted capability has an explicit disposition and cannot silently establish complete equality.

## Exact claim

- Deterministic font execution, platform-native fonts, beyond-sRGB color, multi-renderer comparison, script execution, interaction state, animation timelines, `foreignObject` layout, and generalized external-resource snapshots are not current product capabilities.
- Each capability has a governing document, a machine decision artifact, a reproducible decision validator, a future identity boundary, and either an encountered-input coverage guard or an explicit reason why it cannot occur in one current SVG comparison.
- Unsupported authored semantics produce `partial` coverage or failed admission. Empty Atomic Difference arrays and matching raw pixels never override that status.
- Platform, browser, display, and cross-renderer results remain separately identified observations. They cannot become canonical equality, magnitude, Impact, localization, or causal evidence by voting or implicit fallback.
- Comparison performs no implicit network or filesystem acquisition. Generalized resources require a future closed offline snapshot bundle and resolution policy.

The manifest records accepted future contract identities, not implementations. Passing this gate does not adopt an advanced profile, resolve a dependency, widen the Structured Report Schema, or satisfy the separate M5 adopted-capability gate.

## Reproduce

```sh
sh scripts/test-m5-nongoal-coverage-gate.sh
```

The script validates the manifest and negative controls, runs all nine decision validators, probes the production CLI with unsupported self-comparisons, and runs the existing renderer/coverage and focused font, raster-color, and resource tests.

The accepted result is:

```text
M5 explicit non-goal coverage gate: passed
```
