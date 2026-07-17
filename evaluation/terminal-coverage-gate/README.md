# Terminal Evidence-or-Diagnostic Coverage Gate

Status: accepted terminal evidence

Gate identity: `svgdiff-terminal-coverage-gate/1`

Last verified: 2026-07-17

This gate composes the current coverage-safety chain for the first terminal acceptance item. It validates that every encountered visual semantic under the declared profile either follows an admitted evidence path or constrains completeness through an explicit Diagnostic or failed admission.

## Exact claim

- `complete` remains scoped to schema `1.44`, one recorded Comparison Profile, and the implemented support contract.
- The named static feature inventory, renderer dispositions, centralized coverage proof, unsupported-input properties, and status composition prevent missing or inconsistent evidence from becoming complete.
- Malformed, over-limit, cyclic, or explosively expanding inputs fail instead of returning a truncated inventory.
- Unadopted advanced semantics remain partial or external; the advanced adopted set is empty.
- Supported differences retain the evidence and reference closure established by the M2 soundness gate.

This is not a claim of full SVG support, browser equivalence, equality under another profile, or causal completeness for partial reports. Finite suites exercise the production enforcement; they do not define or widen the support contract.

## Reproduce

```sh
sh scripts/test-terminal-coverage-gate.sh
```

The script validates manifest negative controls; runs the M2 core, renderer/coverage, and soundness gates; runs both M5 gates; exercises CLI failed admission, deterministic hostile/generated inputs, and focused coverage/resource safety tests; and validates one complete, partial, and failed production report.

The accepted result is:

```text
Terminal evidence-or-Diagnostic coverage gate: passed
```
