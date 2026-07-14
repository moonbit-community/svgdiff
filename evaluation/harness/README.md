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

## Verify

```sh
sh scripts/test-agent-harness.sh
```

The integration test generates reports from the curated corpus as setup, prepares task JSONL, checks that task top-level fields contain no source or annotation path, runs a report-only test adapter, and validates one answer per case.
