# Agent Report Guide

Status: current schema `2.0` interpretation guide

Last verified: 2026-07-22

The report is designed for a text-only Agent. Read it in this order:

1. Verify `schema_version`.
2. Read `analysis_status`. Only a complete report with no differences supports
   profile-scoped equality.
3. Read `comparison` to establish viewport and requested perceptual inputs.
4. Read `canvas` for whole-image measurements.
5. Enumerate every item in every `difference_groups` group, including items
   whose rendered magnitude is zero.
6. Follow each difference into `events` for rendered outcome, localization,
   and possible causes.
7. Read every linked and top-level `limitations` entry before describing
   unavailable evidence.

## Difference interpretation

`source.before` and `source.after` preserve exact authored values. They may be
spelled differently while `effective.relation` is `equivalent`; for example,
`red` and `#ff0000`. A `different` relation says supported computed semantics
differ. `indeterminate` means a limitation prevents that conclusion.

`magnitude` is sparse. Present numeric zero is measured zero. An omitted metric
is not applicable, unrequested, or unavailable; use limitation links and event
outcome reasons to distinguish those cases. Do not manufacture null-valued
fields or turn absence into zero.

The category groups are navigation, not a global ranking. Compare magnitudes
only when their units and meanings match. Changed fraction, linear RGBA RMSE,
perceptual response, geometric displacement, and coverage are independent
measurements; the report contains no universal severity score.

## Events and localization

An event groups related Atomic Difference IDs for one visual subject. Its
outcome can be computed or unavailable. A computed zero event remains useful:
it proves that the reported semantic difference produced no pixels under the
recorded profile and rasterization.

Each region contains one CSS-space bounding box. All current Event regions are
`conservative`. Some are tightened by a supported isolated entity rendering;
others only intersect final changed pixels with Event bounds, or retain
computed bounds when rendered pixels are unavailable. Several Events may
therefore share the same region. Their numeric outcome is a bounded canvas
response, not an exact contribution. `observed` is reserved for future
scene-level contribution evidence. No duplicate device/CSS rectangle or
per-side footprint is emitted.

## Possible causes

`possible_causes.candidate_difference_ids` points directly to Atomic
Differences. `sound_overapproximation` means the set may contain false
positives but includes every actual changed cause within complete supported
coverage. It does not mean every candidate is causal. `not_established` makes
no completeness claim; report its limitation IDs.

## Safe summary template

State the analysis status and comparison profile first. Report the three
whole-canvas measurements independently when present. Then list all grouped
differences with source values, effective relation, sparse magnitudes, event
regions, and candidate causes. End with limitations. Never claim visibility,
importance, or cross-domain severity unless the caller supplies that policy.

See [Concise Agent JSON](agent-json.md), [Analysis Status](analysis-status.md),
and the checked-in [JSON Schema](../schema/svgdiff-report.schema.json).
