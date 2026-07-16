# Define an uncalibrated event Impact Assessment frontier

## Context

Visual Events are the report's primary reading unit, but Schema `1.42` offers no machine-readable cross-domain main-difference result. Atomic Difference domain tuples cannot be compared across domains, while a universal weighted scalar would conceal units and policy judgment. Human tiers exist only as hidden single-pass evaluation labels and have not been calibrated for production use.

## Decision

Add `event_rendered_pareto/v1` as an additive top-level Impact Assessment over Visual Events. Compare only the two common whole-canvas fields `RenderedMagnitude.changed_pixel_fraction` and `RenderedMagnitude.linear_premultiplied_rgba_rmse`.

Event A dominates event B only when both measurements are available for both events, A is no smaller on either field, and A is strictly greater on at least one. The main result is the non-dominated frontier. Events with exactly equal measured vectors share a tie group. Distinct non-dominated vectors and unavailable rendered magnitudes remain separate incomparable groups. Missing values never become zero.

Record the exact input field IDs, candidate count, assessment completeness, calibration status, frontier relation, grouped event and Atomic Difference references, nullable measured vectors, and one MoonBit `String::compare` shortlex-ID-selected domination witness for every dominated event. Frontier event groups use the same shortlex ordering while their Atomic Difference links preserve the report's existing deterministic difference order. Both are representation-only. Do not add weights, thresholds, a scalar, a total order, equality meaning, visibility meaning, or severity labels.

## Consequences

A text-only Agent can identify every currently defensible main event, explain why dominated events were excluded, and preserve ties or ambiguity without comparing domain-specific units. Source-only, guarded, or otherwise unrendered events cannot be silently demoted because unavailable evidence remains on the frontier.

The policy is deliberately marked `not_calibrated`. A later policy identity may add reviewed thresholds, ordering rules, or human-facing tiers only after the separate corpus-calibration item records its labels, profile, metrics, agreement, and failure analysis. Raw events, Atomic Differences, magnitudes, Diagnostics, coverage, equality, and same-domain ordering remain authoritative and unchanged.
