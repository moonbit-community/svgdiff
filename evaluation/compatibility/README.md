# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-14

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema, renderer, renderer-conformance, and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is consumer-classified and validated against the [released Schema registry](../../schema/registry.v1.json) twice, and the versioned results must be byte-identical.

The current policy accepts schemas `1.0` through `1.6`, legacy ordering policy `v1_domain_lexicographic`, current policy `v2_domain_lexicographic`, the raw historical `mizchi/svg@0.2.1` renderer identity, the current style-precedence-normalized renderer identity, and conformance profiles `/1` through `/3`. Current producers emit `1.6` with optional typed transform effects and v2 transform-specific tuples. Explicit legacy migration cases restore the ordering and renderer-conformance identities emitted with each old schema and remove fields introduced after each identity, proving that the archived Schemas remain readable. The policy also accepts previous renderer identities under the current shape, optional-field omissions with explicit legacy handling, and an unknown additive top-level field under a recognized identity. It rejects unknown schema, renderer, and renderer-conformance identities before interpreting their evidence and rejects unknown ordering policies before using their component vectors. The current Schema treats renderer identities as non-empty opaque strings; acceptance belongs to this policy rather than the report-shape contract.

The registry retains Schemas `1.0` through `1.5` as legacy and names Schema `1.6` as current. Each entry names its checked-in Schema, accepted ordering policy, canonical-example manifest, and migration cases. The shared project validator audits the complete assertion vocabulary used by every Schema and rejects unknown future keywords. It is not advertised as a general-purpose JSON Schema implementation.

No schema `2.0` or ordering policy v3 migration is implemented; those values are deliberately unknown test inputs. An unknown declared Schema must fail every released Schema, and an unknown ordering policy under `1.6` must fail the current policy constraint before ranking.

## Cases

| Case | Consumer decision | Schema validation |
| --- | --- | --- |
| Current schema and policy | Accept as current. | Valid `1.6`. |
| Legacy `1.0` without alignment or Diagnostic-location evidence | Accept through the registered legacy migration. | Valid `1.0`. |
| Legacy `1.1` without Diagnostic-location evidence | Accept through the registered legacy migration. | Valid `1.1`. |
| Legacy `1.2` without resource-limit failure semantics | Accept through the registered legacy migration. | Valid `1.2`. |
| Legacy `1.3` without reference-safety failure semantics | Accept through the registered legacy migration. | Valid `1.3`. |
| Legacy `1.4` with conformance profile `/2` | Accept through the registered legacy migration. | Valid `1.4`. |
| Legacy `1.5` with v1 ordering | Accept through the registered legacy migration. | Valid `1.5`. |
| Optional alignment evidence absent | Accept with uncertainty evidence unreported. | Valid `1.6`. |
| Optional Diagnostic source locations absent | Accept with locations unreported. | Valid `1.6`. |
| Legacy optional fields absent | Accept with explicit legacy handling. | Valid `1.6`. |
| Unknown additive top-level field under declared `1.6` | Accept while ignoring the unknown field. | Valid `1.6`. |
| Previous renderer and conformance identities | Accept as a known current-shape report. | Valid `1.6`. |
| Unknown schema version | Reject before interpretation. | Invalid under every released Schema. |
| Unknown renderer identity | Reject before rendered interpretation. | Structurally valid `1.6`. |
| Unknown renderer conformance profile | Reject before rendered interpretation. | Structurally valid `1.6`. |
| Unknown ordering policy | Reject before ranking. | Invalid `1.6`. |
