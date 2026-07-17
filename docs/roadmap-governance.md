# Roadmap Review and Rejection Ledger

Status: current maintenance policy

Last reviewed: 2026-07-16

This document prevents roadmap cleanup from erasing product intent. It defines when [`roadmap.md`](../roadmap.md) must be reviewed and records product shapes that the project has intentionally rejected.

## State distinctions

An unchecked roadmap item remains part of the backlog unless a review explicitly changes its state.

| State | Meaning | Required record |
| --- | --- | --- |
| Planned | Accepted direction, not necessarily scheduled | Keep the checklist item and its priority. |
| Deferred | Valuable only after named prerequisites or a later milestone | Keep the checklist item with `Deferred` and the prerequisite. |
| Decision | Product or architecture choice is still open | Keep the checklist item with `Decision`; resolve it through an ADR before implementation. |
| Rejected | The project intentionally will not provide the capability or product shape in the named scope | Remove it from active milestone gates only in the same commit that adds or updates a rejection-ledger entry. |
| Superseded | A different accepted capability satisfies the original outcome | Link the replacement and its decision; do not silently delete the original intent. |

Unsupported current behavior is not automatically rejected. For example, deterministic fonts, animation comparison, `foreignObject`, and cross-browser profiles remain explicitly recorded future decisions or deferred work.

## Milestone review procedure

Review the roadmap when a milestone begins, when its acceptance gate is claimed complete, and whenever the terminal product goal or milestone scope changes materially.

For each review:

1. Re-read the terminal goal, non-negotiable correctness rules, phase checklist, and milestone gate.
2. Confirm that completed items have verification evidence in their issue or commit and mark them complete.
3. Keep unscheduled work visible as planned, deferred, or decision work; update prerequisites when they change.
4. For every removed or narrowed capability, add a rejection or supersession entry below with its exact scope, evidence, and reconsideration trigger.
5. Update `roadmap.md`'s `Last reviewed` date and append one row to its review log in the same commit.

A roadmap review may conclude that no capability should move or be removed. That result still belongs in the review log.

## Rejection ledger

These entries describe exact rejected forms. They do not reject adjacent capabilities that remain in the roadmap.

| Rejected form | Scope | Reason and accepted replacement | Decision evidence | Reconsideration trigger |
| --- | --- | --- | --- | --- |
| Pure XML formatting variation as a Visual Difference, or raw XML text diff as the primary model | All report versions | Attribute order, quote style, tag closing, entity spelling, and declaration whitespace are not visual-semantic outcomes. Compare normalized Declared Visual Facts while retaining reportable authored values and Source Spans as provenance. | [ADR 0027](adr/0027-represent-authored-visual-declarations-as-facts.md) | A future independent source-audit projection may expose textual edits, but it cannot enter Visual Events or replace the visual-semantic model. |
| A visibility boolean or universal scalar as the source of truth | All report versions | Incommensurate exact, geometric, raster, coverage, color, and perceptual measurements must remain available. Optional labels or rankings require a versioned policy. | [ADR 0007](adr/0007-separate-magnitude-evidence-from-impact-policy.md) | None for the canonical evidence model; new derived policies may be added without deleting measurements. |
| Pixel-only comparison as proof of equality or the sole magnitude oracle | All complete analyses | A raster cannot explain authored equivalence or subpixel computed changes, and it cannot establish causal attribution by itself. Preserve Source Semantics, Computed Appearance, and Rendered Evidence separately. | [ADR 0004](adr/0004-record-differences-at-three-evidence-layers.md), [ADR 0006](adr/0006-use-render-observations-as-visible-change-evidence.md) | None for complete analysis; additional renderers may add evidence under explicit profiles. |
| Implicit scripts, network resources, animation state, or platform state inside the deterministic static profile | Deterministic static profile only | Undeclared state makes comparison irreproducible. Encountering it reduces coverage; separately pinned dynamic or resource profiles remain open roadmap decisions. | [ADR 0009](adr/0009-scope-initial-correctness-to-deterministic-static-svg.md) | An accepted ADR defines a separate deterministic profile with all state and resources declared. |
| Alternate-scale diagnostic rerenders in canonical Difference Magnitude | Canonical Structured Report | Magnified samples can exaggerate tiny changes and duplicate continuous computed geometry evidence. They remain renderer-conformance QA. | [ADR 0013](adr/0013-keep-diagnostic-rerendering-outside-the-report.md) | A separately versioned diagnostic artifact is justified without changing canonical magnitude semantics. |
| Production Impact tiers or a total event order calibrated from the single-pass v1 corpus | Schema `1.43` reports and the current thirteen-case evaluation corpus | The corpus has no recorded independent reviewer agreement, only one `low` event, one `high` target without policy inputs, and no ranked multi-event pair. Retain the traceable uncalibrated `event_rendered_pareto/v1` frontier and its raw inputs. | [ADR 0089](adr/0089-reject-impact-calibration-from-the-v1-corpus.md), [calibration results](../evaluation/impact-calibration/results.v1.json) | Independent blinded agreement, ranked multi-event cases, broader tier and boundary coverage, complete policy inputs, and profile sensitivity evidence are versioned and pass the declared release gates. |
| SSIM or MS-SSIM as canonical report evidence, equality, severity, localization, or Impact semantics | Current deterministic static profile and Schema `1.43` | Whole-canvas values are scale-sensitive, coverage-dependent, non-localizing, and misordered against current human tiers. Retain them only as versioned QA observations beside authoritative raw, region, cause, DeltaEOK, and FLIP evidence. | [ADR 0090](adr/0090-keep-ssim-out-of-canonical-report-semantics.md), [diagnostic results](../evaluation/ssim-diagnostics/results.v1.json) | A new Agent task cannot be answered by existing evidence and an accepted proposal demonstrates canonical-scale meaning, complete renderer coverage, localization links, and independent human validation. |
| LPIPS as canonical report evidence, equality, severity, localization, Impact semantics, a default dependency, or a release gate | Current deterministic static profile and Schema `1.44` | The learned scalar requires alternate-scale RGB input, an explicit background, a Python neural runtime, calibration and backbone weights, and a fixed platform. The experiment is scale/background sensitive, inherits renderer false identity, and misorders current tiers. Retain only the pinned optional offline artifact beside authoritative exact, raw, DeltaEOK, FLIP, region, and cause evidence. | [ADR 0096](adr/0096-keep-lpips-outside-product-semantics.md), [experiment results](../evaluation/lpips-experiment/results.v1.json) | A new Agent task cannot be answered by existing evidence and an accepted proposal demonstrates canonical-scale meaning, complete renderer coverage, event links, independent human validation, portable deterministic execution, and cleared model distribution obligations. |
| Semantic priority inferred from SVG source wording, authored IDs, visual magnitude, or frontier membership | Context-free Impact and Schema `1.43` | Business meaning is caller context, not an intrinsic visual measurement. Preserve every event and apply caller concerns as external queries over report evidence; unresolved concern identity remains unknown. | [ADR 0091](adr/0091-separate-query-concern-from-context-free-impact.md), [semantic-concern results](../evaluation/semantic-concern/results.v1.json) | A versioned deterministic Concern Profile is independently evaluated and proves reliable semantic matching without suppressing the complete inventory. |

## Baseline review

The 2026-07-14 pre-M1 review retained every unchecked roadmap capability. No planned, deferred, or decision item was removed. The 2026-07-16 Impact review completed the current-corpus study while preserving recalibration as explicit deferred work and leaving the M3 calibrated-Impact gate open.
