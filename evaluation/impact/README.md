# Impact Assessment Frontier Evaluation

Status: active schema `1.44` regression suite

Last verified: 2026-07-16

This gate checks whether the production `event_rendered_pareto/v1` frontier remains useful for the text-only Agent task without leaking the hidden human labels used by later calibration work.

`validate.py` generates all thirteen curated corpus reports through the release CLI, verifies the policy identity and `not_calibrated` status, rejects severity or corpus-tier labels anywhere in the assessment, and checks that every scorable case retains at least one accepted human main-change target in the reported frontier. It also verifies that `candidate_event_count` equals the complete Visual Event inventory size and that every frontier event and Atomic Difference link resolves into the retained full inventories. The one no-difference case must have an empty frontier.

The accepted targets are evaluation-only oracles. They do not choose production events, weights, thresholds, or labels. This gate therefore measures frontier recall, not calibrated ranking quality: extra incomparable frontier groups are allowed, while omission of every accepted main change fails.

Run:

```sh
sh scripts/test-impact-assessment.sh
```

The result must be deterministic and currently reports twelve scorable targets covered and one not-applicable case. The separate roadmap calibration item owns threshold, tier, and ordering experiments.
