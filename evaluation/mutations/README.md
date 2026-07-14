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

The coverage contract names all six current basic subject kinds and all eighteen current authored properties. Eighteen complete cases cover the minimum applicable property/subject combinations. The fractional-opacity case verifies retained source/computed evidence behind a renderer-conformance guard, and the inherited-fill case verifies retained source evidence where computed color and rendered reconstruction remain deferred.

## Generate

```sh
python3 evaluation/mutations/generate.py --output /tmp/svgdiff-mutations
```

The output contains `cases/<id>/before.svg`, `cases/<id>/after.svg`, and `generated-manifest.json`. The generator sorts JSON keys and uses fixed formatting so identical inputs produce byte-identical outputs.

## Verify

```sh
sh scripts/test-mutations.sh
```

The check generates into a temporary directory, reruns generation to compare hashes, proves that cases cover the exact declared subject-kind and source-property sets, executes every pair through the production CLI, and verifies Subject Alignment plus the independently declared report property, declared values, and affected subjects. For each controlled single-change pair, that independently declared fact is also the actual-cause oracle. The causal property runs both before-to-after and after-to-before, swapping the declared values for reverse matching. Every complete Difference Region in both directions must contain the fact in a `sound_overapproximation` Cause Envelope, while partial cases may not claim that guarantee. A missing-cause negative control proves the property is active. Fractional opacity and inherited fill expect `partial` for their documented, distinct coverage guards.

Mutation-generated pairs complement the hand-authored [curated corpus](../corpus/README.md). They provide mechanical single-change actual-cause oracles, but not human importance labels, human-reviewed region bounds, complex multi-change causal annotations, or Agent answers.
