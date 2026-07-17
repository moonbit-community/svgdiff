# Text-Only Agent Evaluation Harness

Status: active evaluation transport

Acceptance contract: `agent-acceptance/1`

Last verified: 2026-07-17

The harness transports canonical Structured Report JSON to an evaluated agent without including SVG sources, rendered images, corpus metadata, or hidden annotations. It records normalized answer records for later metric computation.

## Boundary

Report generation is an explicit setup step outside this directory. `harness.py prepare` accepts only a directory whose `*.json` files are complete Structured Reports. It derives the case ID from each filename and combines the report with `prompt.txt`. It never opens the curated corpus manifest or annotation files.

The harness controls the input protocol, not the operating-system sandbox of an arbitrary agent command. A production benchmark runner must execute untrusted adapters in an environment that cannot access hidden files or multimodal tools.

## Prepare tasks

```sh
python3 evaluation/harness/harness.py prepare \
  --reports /tmp/svgdiff-reports \
  --output /tmp/svgdiff-tasks.jsonl
```

Each JSONL row contains exactly `case_id`, `acceptance_version`, `prompt`, and `report`.

## Run an adapter

```sh
python3 evaluation/harness/harness.py run \
  --tasks /tmp/svgdiff-tasks.jsonl \
  --output /tmp/svgdiff-answers.jsonl \
  --agent "my-agent-adapter --model example"
```

For each case the adapter receives one task JSON object on stdin and must write one answer JSON object on stdout. The answer must follow `agent-answer.schema.json`, repeat the task's `case_id`, and use acceptance version `agent-acceptance/1`. Nonzero exit, timeout, invalid JSON, schema-shape failure, or case mismatch stops the run.

The schema is a transport and scoring contract. A structurally valid but semantically wrong answer remains possible and will be scored by later benchmark items.

## Score answers

```sh
python3 evaluation/harness/score.py \
  --tasks /tmp/svgdiff-tasks.jsonl \
  --answers /tmp/svgdiff-answers.jsonl \
  --output /tmp/svgdiff-metrics.json
```

Metrics version `svgdiff-evaluation-metrics/1` keeps report and agent layers separate. The report-only answerability dimensions are independently machine-scored: Atomic Difference recall and main-change reciprocal rank cover what changed, exact magnitude-claim recall covers how much, region overlap covers where, and Cause Envelope or possible-cause recall covers why. A magnitude claim matches only when its field, availability status, JSON value, and unit equal canonical evidence for an Atomic Difference ID cited by the same answer item; missing claims reduce recall and altered or fabricated tuples increase `invalid_magnitude_claim_count`.

The same metrics artifact records report Cause Envelope candidate volume and false-positive counts plus invalid report-local evidence references. Candidate volume includes unique candidates, candidate occurrences across regions, region count, and candidates per region for every case. False-positive count and fraction are computed only where hidden actual-cause labels make precision scorable. Exact reference bounds use bounding-box IoU; conservative reference bounds score how much of the predicted union is contained by the reference. Results include per-case values and macro or total aggregates, never a universal combined score.

`evidence_test_agent.py` is a deterministic protocol and scoring fixture that copies report evidence without reading hidden labels, including every named scalar magnitude with its explicit availability and unit. It is not an intelligent benchmark baseline.

## Reproducible benchmark gate

Run the checked repository baseline with:

```sh
sh scripts/run-agent-benchmark.sh --output /tmp/svgdiff-benchmark
```

Pass a real adapter with `--agent "command --arguments"`. The output directory must be empty and receives `reports/`, `tasks.jsonl`, `answers.jsonl`, `metrics.json`, `gate.json`, and `failures.json`. The default `evaluation/benchmark-thresholds.v1.json` uses independent minimum and maximum checks; it does not compute a combined score. Use `--thresholds FILE` only for an explicitly versioned alternate policy.

The current strict thresholds are calibrated to the thirteen-case corpus. They require complete Atomic Difference and magnitude-claim recall, accepted main-change ranking, complete region and possible-cause recall, zero hard safety failures, zero altered or fabricated magnitude claims, and zero invalid evidence references. The default deterministic adapter remains a reproducible regression gate proving that the report-only protocol and scorer expose the required evidence. Any corpus or metric version change requires an explicit threshold review.

The separate [report-only language-model benchmark](../language-model-benchmark/README.md) applies the same corpus, hidden annotations, metrics, and thresholds to an independently executed model. It pins and isolates the execution environment, rejects tool events, records full answers and implementation identities, and remains opt-in rather than part of default CI. Its retained `observation.v1` passes all accepted thresholds; that dated observation does not replace the deterministic default or guarantee future nondeterministic runs.

The 2026-07-16 review additionally made exact multidimensional magnitude claims a thresholded dimension. The evidence adapter retains parameter, presence, typed transform, intrinsic-raster, boundary, coverage, and canonical raster scalar states with explicit units. A valid answer with one altered magnitude value now fails both recall and invalid-claim gates while report-layer metrics remain unchanged. Report candidate volume remains 10 unique candidates, 18 candidate occurrences, and 13 regions; those raw values are regression evidence rather than relaxed acceptance thresholds.

[`failure-attribution.md`](../failure-attribution.md) defines how `failures.json` separates renderer conformance, planned feature coverage, input failure, report-model regression, and agent-interpretation regression. The artifact is written even when the threshold gate fails.

## Verify

```sh
sh scripts/test-agent-harness.sh
python3 -m unittest evaluation/harness/test_codex_report_only_agent.py
sh scripts/test-language-model-observation.sh
```

The integration test generates reports from the curated corpus as setup, prepares task JSONL, checks that task top-level fields contain no source or annotation path, runs a report-only test adapter, and validates one answer per case.

Run `sh scripts/test-evaluation-metrics.sh` to compare the evidence-copying fixture with an intentionally empty semantic answer, reject a schema-valid answer containing an altered magnitude value, and verify that report-level metrics remain unchanged while Agent-level metrics fall.
