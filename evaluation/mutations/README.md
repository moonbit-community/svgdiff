# Deterministic Mutation Suite

Status: active generated evaluation input

Specification version: `svgdiff-mutations/1`

Last verified: 2026-07-14

This suite generates SVG pairs from one-value templates. Each mutation spec declares the expected authored Changed Fact and affected visual subjects before `svgdiff` analyzes the pair, so the report cannot define its own ground truth.

## Model

Each template contains exactly one `{{VALUE}}` placeholder. A case supplies the before and after replacement values plus:

- the mutated source property and its expected report property;
- the supported visual subject kind expected in Subject Alignment;
- the expected normalized before and after values;
- the visual subject IDs expected in `ChangedFact.affected_subject_ids`;
- the comparison viewport and expected analysis status.

The coverage contract names all six current basic subject kinds and all twenty-six current authored properties across twenty-eight cases. Seven cases remain complete and produce fourteen complete directional comparisons; active stroke, curved/point geometry, fractional opacity, and inherited-value cases are intentionally partial under their documented guards. Stroke cases cover width, cap, join, miter limit, dash array, dash offset, and vector effect while proving that every authored fact remains reportable. The viewport case verifies that one changed root declaration reaches its affected leaf and every complete region's Cause Envelope.

## Generate

```sh
python3 evaluation/mutations/generate.py --output /tmp/svgdiff-mutations
```

The output contains `cases/<id>/before.svg`, `cases/<id>/after.svg`, and `generated-manifest.json`. The generator sorts JSON keys and uses fixed formatting so identical inputs produce byte-identical outputs.

## Verify

```sh
sh scripts/test-mutations.sh
```

The check generates into a temporary directory, reruns generation to compare hashes, proves that cases cover the exact declared subject-kind and source-property sets, executes every pair through the production CLI, and verifies Subject Alignment plus the independently declared report property, declared values, and affected subjects. For each controlled single-change pair, that independently declared fact is also the actual-cause oracle. The causal property runs both before-to-after and after-to-before, swapping the declared values for reverse matching. Every complete Difference Region in both directions must contain the fact in a `sound_overapproximation` Cause Envelope, while partial cases may not claim that guarantee. A missing-cause negative control proves the property is active. Active stroke cases expect `partial` because Chromium conformance guards limit Rendered Evidence without removing source or computed stroke semantics.

Mutation-generated pairs complement the hand-authored [curated corpus](../corpus/README.md). They provide mechanical single-change actual-cause oracles, but not human importance labels, human-reviewed region bounds, complex multi-change causal annotations, or Agent answers.
