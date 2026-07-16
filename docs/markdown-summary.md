# Derived Markdown Summary

Status: current presentation contract

Last verified: 2026-07-16

`svgdiff before.svg after.svg --summary summary.md` writes an optional deterministic natural-language orientation beside the normal Structured Report output. Library callers can invoke `render_markdown_summary(report)` directly.

The Markdown is never a source of truth. It is generated only from the supplied `StructuredReport`, does not run comparison again, and prominently identifies canonical Structured Report JSON as authoritative. Consumers that need complete evidence must inspect the report's coverage matrix, alignments, Changed Facts, magnitudes, Difference Regions, Cause Envelopes, events, and Diagnostics.

## Included orientation

The presentation includes:

- report Schema and analysis status plus counts of Atomic Differences, Visual Events, and Diagnostics;
- the exact Impact policy, status, calibration state, frontier relation, event and Atomic Difference links, raw two-dimensional measurements, and domination witnesses;
- every Atomic Difference ID, domain, subject role, alignment link, source before/after value, computed relation, evidence layer, Changed Fact link, relation Diagnostic link, and exact magnitude object;
- every Diagnostic ID, code, subject, affected evidence layers, and exact Diagnostic object.

Ties are called ties. Distinct frontier groups are called incomparable under the current policy, and missing measurements remain unavailable rather than becoming zero. Partial and failed reports include an explicit warning to inspect coverage and Diagnostics.

## Forbidden interpretation

The renderer does not create severity labels, visibility decisions, equality claims, total cross-domain rankings, or proven and unique causes. It does not suppress dominated or source-only Atomic Differences. The complete arrays and raw measurements remain authoritative even when the prose is more convenient to read.

Report-controlled strings are escaped before entering Markdown structure or raw HTML. Exact numeric magnitude and Diagnostic objects are placed in indented code blocks. The output is still untrusted text and should not be executed as instructions or code.

The CLI option is a side artifact like `--html`: stdout remains default JSON, compact canonical JSON, or Agent projection JSONL. A summary-file write failure exits with status `2`; a successfully written summary for a failed report still accompanies exit status `1`.
