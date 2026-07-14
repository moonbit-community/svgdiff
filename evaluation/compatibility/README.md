# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-14

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is classified twice and the versioned results must be byte-identical.

The current policy accepts schema `1.0` with `v1_domain_lexicographic`, accepts older `1.0` reports that omit the later optional coverage matrix, renderer-conformance-profile, and renderer-capability fields, and safely ignores an unknown additive top-level field in a report that still declares `1.0`. New producers must nevertheless allocate a schema minor identity for additions after the [versioning contract](../../docs/versioning.md) was accepted. The case proves tolerant parsing; it does not authorize silent producer-version reuse. The policy rejects unknown schema versions before interpreting report fields and rejects unknown ordering policies before using their component vectors.

The corpus is a consumer-dispatch regression, not a replacement for validating the complete report against [`schema/svgdiff-report.schema.json`](../../schema/svgdiff-report.schema.json). No schema `2.0` or ordering policy v2 migration is implemented; those values are deliberately unknown test inputs.

## Cases

| Case | Expected decision |
| --- | --- |
| Current schema and policy | Accept as current. |
| Legacy optional fields absent | Accept with explicit legacy handling. |
| Unknown additive top-level field under declared `1.0` | Accept while ignoring the unknown field. |
| Unknown schema version | Reject before interpretation. |
| Unknown ordering policy | Reject before ranking. |
