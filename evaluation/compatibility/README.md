# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-14

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is consumer-classified and validated against the [released Schema registry](../../schema/registry.v1.json) twice, and the versioned results must be byte-identical.

The current policy accepts schemas `1.0` and `1.1` with `v1_domain_lexicographic`. Current producers emit `1.1` with alignment evidence. The explicit legacy migration case changes a real current report to `1.0` and removes that additive evidence, proving that the archived Schema remains readable. The policy also accepts reports that omit historical optional coverage, renderer-conformance-profile, and renderer-capability fields, and safely ignores an unknown additive top-level field under a recognized identity. It rejects unknown schema versions before interpreting report fields and rejects unknown ordering policies before using their component vectors.

The registry retains Schema `1.0` as legacy and names Schema `1.1` as current. Each entry names its checked-in Schema, accepted ordering policy, canonical-example manifest, and migration cases. The shared project validator audits the complete assertion vocabulary used by both Schemas and rejects unknown future keywords. It is not advertised as a general-purpose JSON Schema implementation.

No schema `2.0` or ordering policy v2 migration is implemented; those values are deliberately unknown test inputs. An unknown declared Schema must fail every released Schema, and an unknown ordering policy under `1.1` must fail the current policy constraint before ranking.

## Cases

| Case | Consumer decision | Schema validation |
| --- | --- | --- |
| Current schema and policy | Accept as current. | Valid `1.1`. |
| Legacy schema without alignment evidence | Accept through the registered legacy migration. | Valid `1.0`. |
| Optional alignment evidence absent | Accept with uncertainty evidence unreported. | Valid `1.1`. |
| Legacy optional fields absent | Accept with explicit legacy handling. | Valid `1.1`. |
| Unknown additive top-level field under declared `1.1` | Accept while ignoring the unknown field. | Valid `1.1`. |
| Unknown schema version | Reject before interpretation. | Invalid under every released Schema. |
| Unknown ordering policy | Reject before ranking. | Invalid `1.1`. |
