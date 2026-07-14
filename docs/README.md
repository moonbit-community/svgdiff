# Documentation Guide

Status: current documentation map

Last verified: 2026-07-14

This directory separates the current product contract from future plans and historical evidence. When two documents appear to disagree, use the authority order below instead of inferring which file is newer.

## Authority order

| Question | Authoritative source |
| --- | --- |
| What does the command do? | [`README.mbt.md`](../README.mbt.md) and the executable in `cmd/svgdiff` |
| How do stdin, stdout, stderr, and `-` behave? | [`cli-io.md`](cli-io.md) |
| How are Bash, Zsh, and Fish completions installed? | [`completions/README.md`](../completions/README.md) |
| What integrity and attribution files belong in a native release bundle? | [`release/README.md`](../release/README.md) |
| What do CLI exit statuses mean? | [`cli-exit-codes.md`](cli-exit-codes.md) |
| How does compact agent JSON differ from default JSON? | [`agent-json.md`](agent-json.md) |
| What JSON is emitted? | [`schema/svgdiff-report.schema.json`](../schema/svgdiff-report.schema.json) and the public MoonBit report types |
| What can v1 analyze completely today? | [`v1-scope.md`](v1-scope.md) |
| Which tests and Diagnostics enforce that boundary? | [`feature-coverage.md`](feature-coverage.md) |
| What must an analyzer prove before returning complete? | [`coverage-proof-obligations.md`](coverage-proof-obligations.md) |
| How is false equality over unsupported inputs tested? | [`unsupported-input-properties.md`](unsupported-input-properties.md) |
| What do `complete`, `partial`, and `failed` guarantee? | [`analysis-status.md`](analysis-status.md) |
| Which fixed budgets bound one comparison? | [`resource-limits.md`](resource-limits.md) |
| How are local reference cycles and explosive `<use>` DAGs rejected? | [`reference-safety.md`](reference-safety.md) |
| How should a text-only agent interpret the report? | [`agent-report-guide.md`](agent-report-guide.md) |
| How is a text-only agent evaluated? | [`agent-acceptance-spec.md`](agent-acceptance-spec.md) |
| Which counterexamples guard adversarial engine failure modes? | [`adversarial/README.md`](../evaluation/adversarial/README.md) |
| How are parser, renderer, serialization, and HTML boundaries fuzzed reproducibly? | [`fuzz/README.md`](../evaluation/fuzz/README.md) |
| How are pipeline stages timed and representative CLI time and memory budgets enforced? | [`performance/README.md`](../evaluation/performance/README.md) |
| How is hostile SVG source isolated in the generated HTML report? | [`html-security/README.md`](../evaluation/html-security/README.md) |
| Which reports test schema and ordering-policy compatibility? | [`compatibility/README.md`](../evaluation/compatibility/README.md) |
| Which Structured Report Schema versions are released? | [`schema/registry.v1.json`](../schema/registry.v1.json) |
| Which canonical reports demonstrate core agent interpretation cases? | [`schema/examples/README.md`](../schema/examples/README.md) |
| What ordering and report-local ID repeatability is guaranteed? | [`report-determinism.md`](report-determinism.md) |
| How are equally plausible Subject Alignments selected? | [`alignment-tie-breaking.md`](alignment-tie-breaking.md) |
| How do source changes, Atomic Differences, and Visual Events group? | [`core-model.md`](core-model.md#visual-event) and [ADR 0040](adr/0040-give-each-atomic-difference-one-event-owner.md) |
| How are same-domain differences ordered? | [`domain-ordering.md`](domain-ordering.md) |
| Which measurements remain authoritative without an Impact Assessment? | [`impact-assessment.md`](impact-assessment.md) |
| How is the MoonBit library used and documented? | [`library-api.md`](library-api.md) |
| How do embedding agents cooperatively cancel or budget comparison time? | [`library-api.md`](library-api.md) and [ADR 0043](adr/0043-treat-comparison-interruption-as-control-flow.md) |
| Which compatibility change increments which version? | [`versioning.md`](versioning.md) |
| How are dependencies and report contracts upgraded? | [`upgrade-procedures.md`](upgrade-procedures.md) |
| What licenses, security gaps, and upstream blockers are current? | [`dependency-security.md`](dependency-security.md) |
| How are deterministic browser reference rasters captured? | [`browser-oracle/README.md`](../evaluation/browser-oracle/README.md) |
| How is the pinned renderer compared with those rasters? | [`renderer-conformance/README.md`](../evaluation/renderer-conformance/README.md) |
| How are alternate output scales used for renderer QA? | [`alternate-scale/README.md`](../evaluation/alternate-scale/README.md) |
| When should a renderer gap go upstream or become an owned module? | [`renderer-ownership-gate.md`](renderer-ownership-gate.md) |
| When does roadmap work become an `ISS-###` issue? | [`work-planning.md`](work-planning.md) |
| How are milestone reviews and rejected capabilities recorded? | [`roadmap-governance.md`](roadmap-governance.md) |
| What do the report concepts and invariants mean? | [`core-model.md`](core-model.md) |
| How is causal completeness defined? | [`influence-provenance.md`](influence-provenance.md) |
| What remains to be built? | [`roadmap.md`](../roadmap.md) |
| Why was an architectural choice made? | [`adr/README.md`](adr/README.md) and the linked ADR |
| What evidence supported an earlier decision? | [`research/README.md`](research/README.md) and the linked research note |
| What work was executed? | [`issues/README.md`](../issues/README.md) and individual issue files |

The public MoonBit types and checked-in JSON Schema take precedence over prose for serialized field names. A mismatch is a documentation bug and should be corrected in the prose rather than rationalized as an alternate report format.

## Current product snapshot

- The stable report schema is `1.6`.
- The production comparison implementation lives in `engine`; the root package is the public seam.
- The CLI lives in `cmd/svgdiff` and can emit JSON plus an optional self-contained HTML presentation.
- The implemented analyzer covers a deliberately narrow deterministic static-SVG subset.
- Unsupported semantics produce Diagnostics and prevent a false `complete` claim.
- Fixed resource budgets fail safely instead of returning a truncated difference inventory.
- Cyclic or explosively expanding accepted local-reference graphs fail before renderer parsing.
- Representative native release CLI workloads have measured wall-time and peak-RSS regression ceilings.
- Embedding callers can cooperatively cancel or set an elapsed-time budget without creating a truncated report.
- Font-dependent analysis and the broader SVG feature set are future work recorded in the roadmap.

## Document classes

### Current contract

These files must be updated whenever behavior changes:

- [`README.mbt.md`](../README.mbt.md): user-facing usage and support summary;
- [`v1-scope.md`](v1-scope.md): implemented support and coverage boundary;
- [`feature-coverage.md`](feature-coverage.md): feature-to-Diagnostic-to-test traceability;
- [`analysis-status.md`](analysis-status.md): exact caller guarantees for every analysis status;
- [`resource-limits.md`](resource-limits.md): fixed input, structure, raster, region, and report budgets and their failure semantics;
- [`reference-safety.md`](reference-safety.md): conservative local-reference graph, cycle detection, and transitive expansion budget;
- [`agent-report-guide.md`](agent-report-guide.md): reading order and worked report interpretations for text-only agents;
- [`agent-acceptance-spec.md`](agent-acceptance-spec.md): text-only evaluation boundary, answer contract, scoring dimensions, and safety gates;
- [`report-determinism.md`](report-determinism.md): repeatability, report-local ID uniqueness, reference closure, and source-subject identity boundary;
- [`alignment-tie-breaking.md`](alignment-tie-breaking.md): exact-signature and equal-cost deterministic alignment selection;
- [`impact-assessment.md`](impact-assessment.md): raw magnitude authority and constraints on any future policy-derived Impact Assessment;
- [`library-api.md`](library-api.md): public MoonBit seam, exported types, and executable examples;
- [`versioning.md`](versioning.md): module, Schema, Diagnostic, ordering-policy, and renderer-conformance compatibility rules;
- [`core-model.md`](core-model.md): current report model and invariants;
- [`influence-provenance.md`](influence-provenance.md): current causal-completeness contract;
- [`renderer-evaluation.md`](renderer-evaluation.md): current renderer decision and known blockers.
- [`renderer-ownership-gate.md`](renderer-ownership-gate.md): evidence thresholds for guards, focused upstream patches, and project-owned layers.
- [`upgrade-procedures.md`](upgrade-procedures.md): renderer, parser, metric, schema, and policy upgrade gates.
- [`dependency-security.md`](dependency-security.md): resolved licenses, input/output security boundary, and live blockers.

### Planning

[`roadmap.md`](../roadmap.md) is the complete post-v1 capability backlog. Unchecked items are not current capabilities.

[`work-planning.md`](work-planning.md) defines the admission and one-item-per-commit workflow for the Markdown issue tracker.

[`roadmap-governance.md`](roadmap-governance.md) defines milestone review triggers and the rejection ledger. Unchecked capabilities must not disappear from the roadmap without an explicit rejection or supersession record.

### Historical evidence

- ADRs preserve decisions and their rationale. Superseded ADRs remain in place.
- Research notes preserve dated observations. They are not current product promises.
- Issues preserve execution history, including old paths and intermediate schema versions. `issues/README.md` is generated by the tracker and must not be edited by hand.
- Archived prototype findings live in research notes; executable prototypes are removed after their validated behavior is absorbed into production tests.

## Maintenance rules

1. Update the Schema, public types, current scope, and README together when the report contract changes.
2. Put aspirational capabilities in the roadmap, not in the current scope or current model.
3. Add a new ADR when a decision changes; mark the old ADR superseded instead of rewriting its history.
4. Date research snapshots and link them from a short current decision document.
5. Do not edit closed issues to make their historical terminology look current.
6. Keep `CONTEXT.md` as a short project orientation page; do not recreate a second glossary there.
