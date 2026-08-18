# Impact Assessment Frontier Evaluation

Status: active schema `3.0` regression suite

Last verified: 2026-07-16

This gate checks whether the production `event_rendered_pareto/v1` frontier remains useful for the text-only Agent task without leaking the hidden human labels used by later calibration work.

`validate.py` generates all thirteen curated corpus reports and their derived Markdown summaries through the release CLI. It checks the summary's policy identity and `not_calibrated` status, then resolves its frontier event and Atomic Difference links against the canonical Schema `3.0` JSON inventories. It also verifies that the derived `candidate_event_count` equals the complete Visual Event inventory size. The one no-difference case must have an empty frontier.

The accepted targets are evaluation-only oracles. They do not choose production events, weights, thresholds, or labels. This gate therefore measures frontier recall, not calibrated ranking quality: extra incomparable frontier groups are allowed, while omission of every accepted main change fails.

Run:

```sh
sh scripts/test-impact-assessment.sh
```

The result must be deterministic and currently reports twelve scorable targets covered and one not-applicable case. The separate roadmap calibration item owns threshold, tier, and ordering experiments.
