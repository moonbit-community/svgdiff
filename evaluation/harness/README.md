# Text-Only Agent Evaluation Harness

Status: active evaluation transport

Acceptance contract: `agent-acceptance/1`

Last verified: 2026-07-14

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

Metrics version `svgdiff-evaluation-metrics/1` keeps report and agent layers separate. It records agent Atomic Difference recall and main-change reciprocal rank, report and agent region overlap, report Cause Envelope and agent possible-cause recall, conservative candidate volume and false-positive counts, and invalid evidence references. Candidate volume includes unique candidates, candidate occurrences across regions, region count, and candidates per region for every case. False-positive count and fraction are computed only where hidden actual-cause labels make precision scorable. Exact reference bounds use bounding-box IoU; conservative reference bounds score how much of the predicted union is contained by the reference. Results include per-case values and macro or total aggregates, never a universal combined score.

`evidence_test_agent.py` is a deterministic protocol and scoring fixture that copies report evidence without reading hidden labels. It is not an intelligent benchmark baseline.

## Reproducible benchmark gate

Run the checked repository baseline with:

```sh
sh scripts/run-agent-benchmark.sh --output /tmp/svgdiff-benchmark
```

Pass a real adapter with `--agent "command --arguments"`. The output directory must be empty and receives `reports/`, `tasks.jsonl`, `answers.jsonl`, `metrics.json`, `gate.json`, and `failures.json`. The default `evaluation/benchmark-thresholds.v1.json` uses independent minimum and maximum checks; it does not compute a combined score. Use `--thresholds FILE` only for an explicitly versioned alternate policy.

The current strict thresholds are calibrated to the seven-case corpus and deterministic evidence adapter. They are regression gates, not evidence that an external language model has been evaluated. Any corpus or metric version change requires an explicit threshold review.

[`failure-attribution.md`](../failure-attribution.md) defines how `failures.json` separates renderer conformance, planned feature coverage, input failure, report-model regression, and agent-interpretation regression. The artifact is written even when the threshold gate fails.

## Verify

```sh
sh scripts/test-agent-harness.sh
```

The integration test generates reports from the curated corpus as setup, prepares task JSONL, checks that task top-level fields contain no source or annotation path, runs a report-only test adapter, and validates one answer per case.

Run `sh scripts/test-evaluation-metrics.sh` to compare the evidence-copying fixture with an intentionally empty semantic answer and verify that report-level metrics remain unchanged while agent-level metrics fall.
