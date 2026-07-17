# Report-Only Language-Model Benchmark

Status: accepted M3 observation

Profile: `svgdiff-language-model-benchmark-profile/1`

Last verified: 2026-07-17

This opt-in benchmark evaluates an actual language model as a text-only consumer of the accepted thirteen-case Structured Report corpus. It is distinct from the deterministic `evidence_test_agent.py` protocol fixture used by default CI.

## Isolation and authority

Each case runs as a new ephemeral Codex session in a fresh empty working directory and a fresh `CODEX_HOME` containing only a copied authentication file. User configuration and project rules are ignored, while strict profile-pinned feature overrides disable shell, unified execution, browser, apps, MCP, memory, image generation, multi-agent, and related tool surfaces before the request. The adapter gives the model only the canonical prompt, acceptance version, opaque case ID, Structured Report, and normalized answer-format rules. A recorded command, file-change, web, computer-use, or MCP event still rejects the case as a defense-in-depth check.

`profile.v1.json` pins the corpus, metrics, thresholds, adapter, model, reasoning effort, Codex CLI, schemas, sandbox, timeout, and retained artifacts. `codex-agent-answer.schema.json` is only the stricter Structured Outputs transport form; the canonical answer contract remains `agent-answer.schema.json`, and every returned answer is validated by the harness before scoring.

The benchmark is not part of default CI. It needs authenticated network access, consumes model capacity, takes several minutes, and is not byte-deterministic. One passing observation establishes only the recorded model/profile/implementation combination; it is not a promise about every future model run.

## Run

```sh
python3 scripts/run-language-model-benchmark.py \
  --output /tmp/svgdiff-language-model-observation
```

The output directory must be absent or empty. The runner rejects an unpinned Codex CLI version, executes the ordinary report generator and scorer without alternate thresholds, then retains:

- the exact profile and runtime identity;
- all thirteen normalized answers;
- per-case and aggregate metrics;
- threshold decisions and failure classification;
- SHA-256 hashes for every retained artifact;
- SHA-256 identities for the adapter, schemas, prompt, harness, scorer, thresholds, failure classifier, and corpus manifest.

Validate an observation independently with:

```sh
python3 evaluation/language-model-benchmark/validate_observation.py \
  evaluation/language-model-benchmark/observation.v1
sh scripts/test-language-model-observation.sh
```

## Accepted observation v1

The retained `observation.v1` used `gpt-5.6-sol`, low reasoning effort, and `codex-cli 0.144.4`. All thirteen answers were Schema-valid and tool-free under the adapter policy. The threshold gate passed with:

- `1.0` macro accuracy or recall for coverage status, equality conclusion, required Diagnostics, Atomic Differences, exact magnitude claims, localization, possible causes, report regions, and report Cause Envelopes;
- `1.0` main-difference MRR;
- all `354` expected exact magnitude claims matched;
- zero hard safety failures, invalid magnitude claims, invalid evidence references, report cause false positives, agent cause false positives, and unclassified failures.

Report-region overlap and report Cause Envelope recall remain engine/report metrics. The model receives no credit for producing them; they stay visible beside the Agent metrics so input-report failure cannot be disguised as Agent success.

The retained observation also satisfies the [terminal text-only Agent reliability gate](../terminal-agent-reliability-gate/README.md). That gate requires perfect Atomic Difference recall, accepted-main-event reciprocal rank, eligible localization and possible-cause recall, zero observed cause-label false positives, exact coverage/equality/Diagnostic handling, valid report references, and zero hard safety failures. It independently requires perfect eligible report-region and actual-cause recall with zero observed report cause-label false positives. These are claims about this pinned observation only, not every model or future run.
