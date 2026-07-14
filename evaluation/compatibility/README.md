# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-15

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema, renderer, renderer-conformance, and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is consumer-classified and validated against the [released Schema registry](../../schema/registry.v1.json) twice, and the versioned results must be byte-identical.

The current policy accepts schemas `1.0` through `1.14`, legacy ordering policy `v1_domain_lexicographic`, current policy `v2_domain_lexicographic`, the raw historical `mizchi/svg@0.2.1` renderer identity, all seven production renderer identities, and conformance profiles `/1` through `/11`. Current producers emit `1.14` with bounded static selector matching, the author cascade seam, ordinary inheritance, authored-unit used values, marker placement and viewport semantics, canonical stroke and basic-shape geometry, optional typed transform effects, and v2 transform-specific tuples. Explicit legacy migration cases restore the renderer and conformance identities emitted with each old schema and remove fields introduced after each identity, proving that the archived Schemas remain readable. The policy also accepts previous renderer identities under the current shape, optional-field omissions with explicit legacy handling, and an unknown additive top-level field under a recognized identity. It rejects unknown schema, renderer, and renderer-conformance identities before interpreting their evidence and rejects unknown ordering policies before using their component vectors. The current Schema treats renderer identities as non-empty opaque strings; acceptance belongs to this policy rather than the report-shape contract.

The registry retains Schemas `1.0` through `1.13` as legacy and names Schema `1.14` as current. Each entry names its checked-in Schema, accepted ordering policy, canonical-example manifest, and migration cases. The shared project validator audits the complete assertion vocabulary used by every Schema and rejects unknown future keywords. It is not advertised as a general-purpose JSON Schema implementation.

No schema `2.0` or ordering policy v3 migration is implemented; those values are deliberately unknown test inputs. An unknown declared Schema must fail every released Schema, and an unknown ordering policy under `1.14` must fail the current policy constraint before ranking.

## Cases

| Case | Consumer decision | Schema validation |
| --- | --- | --- |
| Current schema and policy | Accept as current. | Valid `1.14`. |
| Legacy `1.13` with the static-selector renderer and conformance profile `/10` | Accept through the registered legacy migration. | Valid `1.13`. |
| Legacy `1.12` with the inline-cascade renderer and conformance profile `/9` | Accept through the registered legacy migration. | Valid `1.12`. |
| Legacy `1.11` with the length normalizer and conformance profile `/8` | Accept through the registered legacy migration. | Valid `1.11`. |
| Legacy `1.10` with the marker-era renderer and conformance profile `/7` | Accept through the registered legacy migration. | Valid `1.10`. |
| Legacy `1.9` with conformance profile `/6` | Accept through the registered legacy migration. | Valid `1.9`. |
| Legacy `1.8` with the basic-shape normalizer and conformance profile `/5` | Accept through the registered legacy migration. | Valid `1.8`. |
| Legacy `1.0` without alignment or Diagnostic-location evidence | Accept through the registered legacy migration. | Valid `1.0`. |
| Legacy `1.1` without Diagnostic-location evidence | Accept through the registered legacy migration. | Valid `1.1`. |
| Legacy `1.2` without resource-limit failure semantics | Accept through the registered legacy migration. | Valid `1.2`. |
| Legacy `1.3` without reference-safety failure semantics | Accept through the registered legacy migration. | Valid `1.3`. |
| Legacy `1.4` with conformance profile `/2` | Accept through the registered legacy migration. | Valid `1.4`. |
| Legacy `1.5` with v1 ordering | Accept through the registered legacy migration. | Valid `1.5`. |
| Legacy `1.6` with conformance profile `/3` | Accept through the registered legacy migration. | Valid `1.6`. |
| Legacy `1.7` with the style-precedence renderer and conformance profile `/4` | Accept through the registered legacy migration. | Valid `1.7`. |
| Optional alignment evidence absent | Accept with uncertainty evidence unreported. | Valid `1.14`. |
| Optional Diagnostic source locations absent | Accept with locations unreported. | Valid `1.14`. |
| Legacy optional fields absent | Accept with explicit legacy handling. | Valid `1.14`. |
| Unknown additive top-level field under declared `1.14` | Accept while ignoring the unknown field. | Valid `1.14`. |
| Previous renderer and conformance identities | Accept as a known current-shape report. | Valid `1.14`. |
| Unknown schema version | Reject before interpretation. | Invalid under every released Schema. |
| Unknown renderer identity | Reject before rendered interpretation. | Structurally valid `1.14`. |
| Unknown renderer conformance profile | Reject before rendered interpretation. | Structurally valid `1.14`. |
| Unknown ordering policy | Reject before ranking. | Invalid `1.14`. |
