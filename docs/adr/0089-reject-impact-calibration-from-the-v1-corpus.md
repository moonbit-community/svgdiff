# Reject Impact calibration from the v1 corpus

## Context

`event_rendered_pareto/v1` deliberately identifies a non-dominated main-event frontier without thresholds, labels, or a total order. The next roadmap question was whether the versioned human labels could support a calibrated production policy.

The current corpus has thirteen cases. Twelve are scorable for a top-event target, but every scorable case has exactly one Visual Event. The annotations are an initial single-pass review with no recorded independent agreement. Their target-event tiers contain four `none`, one `low`, four `medium`, and three `high` events. One `high` embedded-raster target has no rendered or perceptual policy inputs under the current profile.

A deterministic study evaluated monotonic ordinal cutpoints over changed-pixel fraction, linear premultiplied-RGBA RMSE, and FLIP canvas mean, plus a changed-area-then-RMSE lexicographic total order. It used fresh Schema `1.43` reports under a recorded white background, 20 FLIP pixels per degree, renderer identity, and conformance profile.

## Decision

Reject every evaluated production calibration candidate and retain `event_rendered_pareto/v1` with `calibration_status: "not_calibrated"`.

Changed-pixel fraction fits all eleven measured target events in-sample, but leave-one-case-out evaluation has `10/12` coverage, `9/10` conditional accuracy, and `9/12` overall accuracy. Holding out the only `low` case makes the four-tier model untrainable, while holding out the unsupported-path case predicts `low` instead of `medium`. RMSE and FLIP canvas mean have overlapping or inverted tier ranges and cannot fit monotonic four-tier cutpoints. The total-order candidate has zero evaluable multi-event cases and zero human-ranked event pairs.

Do not emit corpus tiers, synonyms such as `subtle` or `major`, learned thresholds, weights, or a total cross-domain order from this evidence. The full-fit changed-area cutpoints are an overfit evaluation observation, not product parameters.

Repeat calibration only after all of these are versioned:

- an independent blinded review with recorded agreement;
- ranked multi-event cases containing cross-domain tradeoffs;
- more low-tier and boundary cases;
- policy inputs for every labeled target, including embedded rasters;
- sensitivity results across relevant viewports, backgrounds, and viewing conditions.

Any accepted retry requires a new Impact policy identity and its own schema, compatibility, Agent, benchmark, and release review where applicable.

## Consequences

The calibration roadmap study is complete and reproducible, but the M3 calibrated-Impact gate remains open. The roadmap retains a prerequisite-bound recalibration item instead of treating this negative study as delivery of a calibrated policy.

The current uncalibrated frontier still contains an accepted top target in all twelve scorable cases. That is a recall result only: it does not justify selecting one winner, ranking incomparable events, or assigning importance labels.

The versioned dataset, candidate outcomes, release gates, and failure examples live in the [Impact calibration evaluation](../../evaluation/impact-calibration/README.md). Raw measurements, event inventory, equality, Diagnostics, coverage, and same-domain ordering remain unchanged.
