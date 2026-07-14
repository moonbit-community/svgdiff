# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-14

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is consumer-classified and validated against the [released Schema registry](../../schema/registry.v1.json) twice, and the versioned results must be byte-identical.

The current policy accepts schemas `1.0`, `1.1`, `1.2`, `1.3`, and `1.4` with `v1_domain_lexicographic`. Current producers emit `1.4` with local-reference cycle and expansion admission failures in addition to fixed resource-limit failure semantics, alignment evidence, and Diagnostic source locations. Explicit legacy migration cases remove fields introduced after each identity and prove that the archived Schemas remain readable; Schema `1.2` differs semantically through the absence of `resource_limit_exceeded`, while Schema `1.3` lacks the two new reference-safety Diagnostics but retains the same report shape. The policy also accepts a current `1.4` report that omits optional Diagnostic locations with the explicit meaning “not reported,” reports that omit historical optional coverage, renderer-conformance-profile, and renderer-capability fields, and an unknown additive top-level field under a recognized identity. It rejects unknown schema versions before interpreting report fields and rejects unknown ordering policies before using their component vectors.

The registry retains Schemas `1.0`, `1.1`, `1.2`, and `1.3` as legacy and names Schema `1.4` as current. Each entry names its checked-in Schema, accepted ordering policy, canonical-example manifest, and migration cases. The shared project validator audits the complete assertion vocabulary used by every Schema and rejects unknown future keywords. It is not advertised as a general-purpose JSON Schema implementation.

No schema `2.0` or ordering policy v2 migration is implemented; those values are deliberately unknown test inputs. An unknown declared Schema must fail every released Schema, and an unknown ordering policy under `1.4` must fail the current policy constraint before ranking.

## Cases

| Case | Consumer decision | Schema validation |
| --- | --- | --- |
| Current schema and policy | Accept as current. | Valid `1.4`. |
| Legacy `1.0` without alignment or Diagnostic-location evidence | Accept through the registered legacy migration. | Valid `1.0`. |
| Legacy `1.1` without Diagnostic-location evidence | Accept through the registered legacy migration. | Valid `1.1`. |
| Legacy `1.2` without resource-limit failure semantics | Accept through the registered legacy migration. | Valid `1.2`. |
| Legacy `1.3` without reference-safety failure semantics | Accept through the registered legacy migration. | Valid `1.3`. |
| Optional alignment evidence absent | Accept with uncertainty evidence unreported. | Valid `1.4`. |
| Optional Diagnostic source locations absent | Accept with locations unreported. | Valid `1.4`. |
| Legacy optional fields absent | Accept with explicit legacy handling. | Valid `1.4`. |
| Unknown additive top-level field under declared `1.4` | Accept while ignoring the unknown field. | Valid `1.4`. |
| Unknown schema version | Reject before interpretation. | Invalid under every released Schema. |
| Unknown ordering policy | Reject before ranking. | Invalid `1.4`. |
