# Impact Calibration Evaluation

Status: versioned negative calibration result

Last verified: 2026-07-16

This evaluation asks whether the current human-labeled corpus can justify a calibrated production Impact Assessment. It does not tune or change the production `event_rendered_pareto/v1` policy.

`dataset.v1.json` joins the versioned corpus, main-change labels, ranking targets, and fresh Schema `1.43` production reports generated with a white Perceptual Background and 20 FLIP pixels per degree. The artifact records renderer and conformance identities, profile inputs, every event measurement, target membership, and the uncalibrated frontier.

`results.v1.json` evaluates three single-metric ordinal cutpoint families and one deterministic total-order family. Every candidate records its inputs, fitted or untrainable result, leave-one-case-out outcomes where applicable, release-gate results, and decision reasons.

## Result

The v1 study rejects every calibrated production candidate:

- annotations have no recorded independent reviewer agreement;
- only one event has a `low` label;
- one `high` target has no rendered or perceptual measurements;
- all twelve scorable cases contain only one event, so their frontiers are all `unique` and there are no ties, incomparable multi-event frontiers, or human-ranked within-case event pairs;
- changed-pixel fraction fits the measured data in-sample but reaches only `10/12` held-out coverage and `9/12` overall accuracy;
- linear RGBA RMSE and FLIP canvas mean have overlapping or inverted tier ranges and cannot fit monotonic four-tier cutpoints.

The current Pareto frontier contains an accepted top target in all twelve scorable cases. This is only frontier recall: it does not establish a total ordering or calibrated tier labels.

Production therefore retains `event_rendered_pareto/v1` with `calibration_status: "not_calibrated"`. The study must be repeated after independent blinded review, ranked multi-event cases, more low and boundary cases, complete policy inputs, and profile sensitivity evidence are available.

## Reproduce

```sh
sh scripts/test-impact-calibration.sh
```

To intentionally regenerate the checked-in artifacts after an accepted corpus, annotation, renderer, metric, or profile change:

```sh
moon build --target native --release modules/svgdiff/cmd/svgdiff
python3 evaluation/impact-calibration/validate.py \
  --cli _build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe \
  --update
sh scripts/test-impact-calibration.sh
```

Regeneration is an evaluation update, not permission to publish labels. Any accepted calibrated production policy requires a new policy identity and the compatibility work defined in the Impact Assessment upgrade procedure.
