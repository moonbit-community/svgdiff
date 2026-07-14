# Deterministic Mutation Suite

Status: active generated evaluation input

Specification version: `svgdiff-mutations/1`

Last verified: 2026-07-14

This suite generates SVG pairs from one-value templates. Each mutation spec declares the expected authored Changed Fact and affected visual subjects before `svgdiff` analyzes the pair, so the report cannot define its own ground truth.

## Model

Each template contains exactly one `{{VALUE}}` placeholder. A case supplies the before and after replacement values plus:

- the mutated source property and its expected report property;
- the expected normalized before and after values;
- the visual subject IDs expected in `ChangedFact.affected_subject_ids`;
- the comparison viewport and expected analysis status.

The initial cases cover a direct rectangle fill, a circle position parameter, and an inherited group fill that affects a child circle.

## Generate

```sh
python3 evaluation/mutations/generate.py --output /tmp/svgdiff-mutations
```

The output contains `cases/<id>/before.svg`, `cases/<id>/after.svg`, and `generated-manifest.json`. The generator sorts JSON keys and uses fixed formatting so identical inputs produce byte-identical outputs.

## Verify

```sh
sh scripts/test-mutations.sh
```

The check generates into a temporary directory, reruns generation to compare hashes, executes every pair through the production CLI, and verifies that the independently declared report property, declared values, and affected subjects occur in the report's Changed Facts. The inherited case expects `partial` because its source fact is retained while computed color and rendered evidence remain explicitly deferred.

Mutation-generated pairs complement the hand-authored [curated corpus](../corpus/README.md). They do not provide human importance labels, region bounds, actual-cause annotations, or agent answers.
