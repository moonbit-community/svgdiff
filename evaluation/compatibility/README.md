# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-14

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is consumer-classified and validated against the [released Schema registry](../../schema/registry.v1.json) twice, and the versioned results must be byte-identical.

The current policy accepts schema `1.0` with `v1_domain_lexicographic`, accepts older `1.0` reports that omit the later optional coverage matrix, renderer-conformance-profile, and renderer-capability fields, and safely ignores an unknown additive top-level field in a report that still declares `1.0`. New producers must nevertheless allocate a schema minor identity for additions after the [versioning contract](../../docs/versioning.md) was accepted. The case proves tolerant parsing; it does not authorize silent producer-version reuse. The policy rejects unknown schema versions before interpreting report fields and rejects unknown ordering policies before using their component vectors.

Schema `1.0` is currently the only released entry. Its registry record names the checked-in Schema, accepted ordering policy, canonical-example manifest, and every in-version compatibility case. The shared project validator audits the complete assertion vocabulary used by that Schema and rejects unknown future keywords. It is not advertised as a general-purpose JSON Schema implementation.

No schema `2.0` or ordering policy v2 migration is implemented; those values are deliberately unknown test inputs. An unknown declared Schema must fail every released Schema, and an unknown ordering policy under `1.0` must fail the `1.0` policy constraint before ranking.

## Cases

| Case | Consumer decision | Schema validation |
| --- | --- | --- |
| Current schema and policy | Accept as current. | Valid `1.0`. |
| Legacy optional fields absent | Accept with explicit legacy handling. | Valid `1.0`. |
| Unknown additive top-level field under declared `1.0` | Accept while ignoring the unknown field. | Valid `1.0`. |
| Unknown schema version | Reject before interpretation. | Invalid under every released Schema. |
| Unknown ordering policy | Reject before ranking. | Invalid `1.0`. |
