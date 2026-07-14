# Renderer Upstream and Ownership Gate

Status: current renderer escalation policy

Last verified: 2026-07-14

This policy decides whether a measured renderer gap should remain guarded, receive a focused upstream patch, or cause SVG Diff to own a MoonBit rendering layer. It refines [ADR 0011](adr/0011-prefer-moonbit-rendering-dependencies-before-owning-a-renderer.md) and [ADR 0012](adr/0012-own-only-the-smallest-failing-renderer-layer.md) without changing the current support contract.

## Correctness floor

Ownership and report correctness are separate decisions. Every complete-eligible conformance case must have zero unexplained divergence. Each measured divergence must be eliminated by an adapter fix, accepted by an explicit versioned tolerance, or covered by a stable Diagnostic that prevents an unsupported Rendered Evidence claim.

A global pass percentage cannot satisfy this floor. One severe semantic failure can invalidate complete analysis even when thousands of unrelated fixtures pass. Pixel magnitude also cannot choose an ownership route: a one-level alpha error may reveal a systematic arithmetic defect, while a large error in a deferred feature may not block the active milestone.

## Evidence units

An escalation record counts only minimized, deterministic conformance cases with an accepted oracle and a named smallest failing layer. Cases are independent when they exercise different SVG mechanisms, code paths, or boundary conditions rather than merely changing constants in one reproducer.

A capability family is a report-relevant semantic group such as geometry sampling, paint-server evaluation, leaf alpha, isolated group compositing, CSS cascade, clipping, or provenance instrumentation.

## Route 1: guarded dependency gap

Keep a gap guarded when it does not block an active milestone, its failing layer is not yet isolated, or either upstream or ownership evidence is incomplete. The Diagnostic must name the limited evidence layers. A guard preserves soundness but does not close the missing capability or the external blocker.

## Route 2: focused upstream patch

One minimized failing conformance case is sufficient to open an upstream issue or patch. Upstream remains the required route while all of the following hold:

1. the failure is localized to one dependency-owned layer;
2. the correction expresses general SVG or raster semantics rather than SVG Diff report policy;
3. the correction can be tested in the dependency without importing SVG Diff types or identities;
4. the dependency can expose any required narrow hook without a maintained project fork; and
5. the affected SVG Diff cases can remain guarded until a release is available.

A focused patch is not rejected merely because its pixel impact is large or because the affected case is important. Those facts change priority, not ownership.

## Route 3: project-owned smallest layer

A workspace-owned module is eligible only when every mandatory condition and one evidence trigger are satisfied.

Mandatory conditions:

1. the missing capability blocks an accepted active-milestone item;
2. the smallest failing layer and its input/output seam are named;
3. no released dependency currently satisfies the acceptance cases;
4. upstream is demonstrably non-viable because the change was rejected as out of scope, requires project-specific semantics that do not belong upstream, or a ready fix remains unreleased after either two subsequent upstream releases or 90 days;
5. the proposal retains every passing parser, scene, image, and comparison layer; and
6. the proposal names module ownership, conformance fixtures, migration steps, license obligations, and long-term maintenance responsibility.

One of these evidence triggers is also required:

- **Breadth trigger:** at least three independent failing cases across at least two required capability families resolve to the same smallest failing layer.
- **Control trigger:** at least three independent cases require the same SVG Diff-specific instrumentation or semantic control, and the requirement cannot be expressed through an acceptable upstream public hook.

The numbers are an admission threshold, not an automatic implementation order. Passing the gate permits an ownership ADR and bounded module issue; it does not authorize rewriting the entire renderer.

## Decision scorecard

Record one row per candidate before proposing ownership:

| Field | Required evidence |
| --- | --- |
| Active milestone blocker | Roadmap item and acceptance case IDs |
| Smallest failing layer | Parser, scene resolution, raster primitive, paint server, compositor, or instrumentation seam |
| Independent cases | IDs plus mechanism or boundary that makes each independent |
| Capability families | Named groups represented by those cases |
| Current disposition | Adapter, tolerance, stable Diagnostic, or unexplained |
| Upstream attempt | Issue or PR and maintainer/release outcome |
| Upstream viability | Viable, rejected/out of scope, project-specific, or expired release window |
| Proposed owned seam | Inputs, outputs, retained dependencies, and excluded responsibilities |
| Maintenance owner | Module owner, test command, license, and update duty |
| Decision | Guard, focused upstream patch, or ownership ADR |

## Current application

| Gap | Evidence | Decision under this gate |
| --- | --- | --- |
| Inline-style precedence | One localized XML-value adapter, focused upstream PR open, positive production regressions, conservative fallback Diagnostic | Own only the private renderer-input adapter while keeping the upstream path open; do not fork the renderer. |
| Fractional geometry quantization | Measured browser divergence with a rendered-only guard; broader geometry work is not yet complete | Keep guarded while identifying the smallest sampling layer; ownership evidence is incomplete. |
| Referenced-gradient sampling | Two raster observations in one paint-server family with a guard | Keep guarded; it does not meet breadth or control trigger. |
| Fractional leaf opacity | One arithmetic boundary case with a guard | Keep guarded and prefer a focused upstream correction if promoted to active scope. |
| Group opacity | One isolated-compositing mechanism, already outside complete coverage | Keep guarded until compositing becomes active milestone work; one case cannot admit ownership. |
| `mizchi/canvas` test compatibility | One transitive test-only `Debug` defect with a focused upstream PR | Continue focused upstream path; this is far below ownership threshold. |

Re-evaluate a row when its roadmap priority changes, a new independent case is added, upstream publishes a relevant release, or the renderer conformance profile changes.
