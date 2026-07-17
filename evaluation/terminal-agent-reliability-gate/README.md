# Terminal Text-Only Agent Reliability Gate

Status: accepted terminal evidence

Gate identity: `svgdiff-terminal-agent-reliability-gate/1`

Last verified: 2026-07-17

This gate validates the third terminal acceptance item against the retained thirteen-case report-only model observation. It maps each part of the claim to independent metrics instead of treating Agent quality as one score.

## Exact claim

- “Changes” means every expected Atomic Difference is retained.
- “Important changes” means an annotation-accepted main event is ranked first; it is not a severity class or universal event order.
- “Locations” means the Agent's referenced Difference Regions meet every eligible hidden localization label.
- “Possible reasons” means every eligible actual changed cause is retained, no label-false candidate is added in this observation, and Cause Envelope language remains possible-cause rather than proven unique-cause language.
- Coverage, equality, required Diagnostics, hard safety, and report-reference validity remain exact.
- Report-region and report Cause Envelope metrics are checked independently so unsound input evidence cannot be mistaken for successful Agent interpretation.

The result is limited to the retained model, reasoning effort, Codex CLI, adapter, implementation identities, corpus, prompt contract, and metric versions. It does not promise that another model or nondeterministic future run passes, and it does not widen SVG or profile coverage.

## Reproduce

```sh
sh scripts/test-terminal-agent-reliability-gate.sh
```

The script validates manifest negative controls and retained-observation integrity, then runs the deterministic report-only harness, metric mutation suite, retained observation validator, and M2 alignment/region/cause soundness gate. It makes no remote model call.

The accepted result is:

```text
Terminal text-only Agent reliability gate: passed
```
