# Schema and Policy Compatibility Corpus

Status: active compatibility regression suite

Corpus version: `svgdiff-compatibility-corpus/1`

Consumer policy: `svgdiff-consumer-compatibility/1`

Last verified: 2026-07-20

This corpus generates one real current report through the production CLI and applies versioned, reviewable mutations to its schema, renderer, renderer-conformance, and ordering identities. Run `sh scripts/test-compatibility.sh`; every case is consumer-classified and validated against the [released Schema registry](../../schema/registry.v1.json) twice, and the versioned results must be byte-identical.

The current policy accepts schemas `1.0` through `1.45`, legacy ordering policy `v1_domain_lexicographic`, current ordering policy `v2_domain_lexicographic`, Impact Assessment policy `event_rendered_pareto/v1`, the raw historical `mizchi/svg@0.2.1` renderer identity, all sixteen production renderer identities, and conformance profiles `/1` through `/26`. Current producers emit `1.45` with a required uncalibrated main-event Pareto frontier over common rendered magnitude fields, plus the existing event-local perceptual-color availability, changed-pixel mean DeltaEOK when an opaque sRGB Perceptual Background is declared, and opt-in event-local LDR-FLIP maps with separate unquantized canvas, selected-event, response-tail, maximum, and nullable explicit-threshold area statistics when bounded pixels-per-degree Viewing Conditions are also present. The optional threshold is recorded independently and has no implicit default or visibility meaning. Current reports retain the existing bounded static selector matching, author cascade, inheritance, computed CSS, paint, geometry, effects, resource, alignment, magnitude, region, causal, and v2 ordering evidence. Explicit legacy migration cases restore the identities emitted with each old schema and remove fields introduced after each identity, including the complete Impact Assessment for `1.42` and earlier, proving that the archived Schemas remain readable. The policy also accepts previous renderer identities under the current shape, optional-field omissions with explicit legacy handling, and an unknown additive top-level field under a recognized identity. It rejects unknown schema, renderer, and renderer-conformance identities before interpreting their evidence, unknown ordering policies before using their component vectors, and unknown Impact Assessment policies before selecting main events. The current Schema treats renderer identities as non-empty opaque strings; acceptance belongs to this policy rather than the report-shape contract.

The registry retains Schemas `1.0` through `1.44` as legacy and names Schema `1.45` as current. Each entry names its checked-in Schema, accepted ordering policy, accepted Impact policy where applicable, canonical-example manifest, and migration cases. The shared project validator audits the complete assertion vocabulary used by every Schema and rejects unknown future keywords. It is not advertised as a general-purpose JSON Schema implementation.

No schema `2.0`, ordering policy v3, or Impact Assessment policy v2 migration is implemented; those values are deliberately unknown test inputs. An unknown declared Schema must fail every released Schema, and unknown ordering or Impact Assessment policy IDs under `1.45` must fail the current policy constraints before interpretation.

## Cases

| Case | Consumer decision | Schema validation |
| --- | --- | --- |
| Current schema and policies | Accept as current. | Valid `1.45`. |
| Legacy `1.44` before comparison-wide Canvas Outcome | Accept through the registered legacy migration. | Valid `1.44`. |
| Legacy `1.43` before embedded raster color-profile and HDR Diagnostics | Accept through the registered legacy migration. | Valid `1.43`. |
| Legacy `1.42` before required Impact Assessment | Accept through the registered legacy migration. | Valid `1.42`. |
| Legacy `1.41` before separate pooled FLIP statistics and explicit threshold state | Accept through the registered legacy migration. | Valid `1.41`. |
| Legacy `1.40` before optional event-local LDR-FLIP maps | Accept through the registered legacy migration. | Valid `1.40`. |
| Legacy `1.39` before event-local perceptual-color evidence | Accept through the registered legacy migration. | Valid `1.39`. |
| Legacy `1.38` before explicit Perceptual Background state | Accept through the registered legacy migration. | Valid `1.38`. |
| Legacy `1.37` before symmetric painted-coverage difference | Accept through the registered legacy migration. | Valid `1.37`. |
| Legacy `1.36` before painted-boundary distributions | Accept through the registered legacy migration. | Valid `1.36`. |
| Legacy `1.35` before exact CSS/viewport/entity parameter scales | Accept through the registered legacy migration. | Valid `1.35`. |
| Legacy `1.34` before role-typed Visual Resource alignment | Accept through the registered legacy migration. | Valid `1.34`. |
| Legacy `1.33` before repeated-subject semantic equivalence classes | Accept through the registered legacy migration. | Valid `1.33`. |
| Legacy `1.32` before transform- and rendered-geometry-aware correspondence | Accept through the registered legacy migration. | Valid `1.32`. |
| Legacy `1.31` before structural subject alignment | Accept through the registered legacy migration. | Valid `1.31`. |
| Legacy `1.30` before opaque unsupported-filter source differences | Accept through the registered legacy migration. | Valid `1.30`. |
| Legacy `1.29` before bounded static blending and isolation | Accept through the registered legacy migration. | Valid `1.29`. |
| Legacy `1.28` before bounded static filter graphs | Accept through the registered legacy migration. | Valid `1.28`. |
| Legacy `1.27` before static masking | Accept through the registered legacy migration. | Valid `1.27`. |
| Legacy `1.26` before deterministic clipping | Accept through the registered legacy migration. | Valid `1.26`. |
| Legacy `1.25` before isolated group compositing | Accept through the registered legacy migration. | Valid `1.25`. |
| Legacy `1.24` before nonvisual descriptive-content exclusion | Accept through the registered legacy migration. | Valid `1.24`. |
| Legacy `1.23` before caller-supplied resource bundles | Accept through the registered legacy migration. | Valid `1.23`. |
| Legacy `1.22` without intrinsic raster magnitude | Accept through the registered legacy migration. | Valid `1.22`. |
| Legacy `1.21` with conformance profile `/18` | Accept through the registered legacy migration. | Valid `1.21`. |
| Legacy `1.20` with conformance profile `/17` | Accept through the registered legacy migration. | Valid `1.20`. |
| Legacy `1.19` with the paint-fallback renderer and conformance profile `/16` | Accept through the registered legacy migration. | Valid `1.19`. |
| Legacy `1.18` with the pattern-era renderer and conformance profile `/15` | Accept through the registered legacy migration. | Valid `1.18`. |
| Legacy `1.16` with the solid-color renderer and conformance profile `/13` | Accept through the registered legacy migration. | Valid `1.16`. |
| Legacy `1.14` with the inheritance renderer and conformance profile `/11` | Accept through the registered legacy migration. | Valid `1.14`. |
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
| Optional alignment evidence absent | Accept with uncertainty evidence unreported. | Valid `1.45`. |
| Optional instance context absent | Accept with direct-versus-instance context unreported by the legacy-shaped producer. | Valid `1.45`. |
| Optional Diagnostic source locations absent | Accept with locations unreported. | Valid `1.45`. |
| Legacy optional fields absent | Accept with explicit legacy handling. | Valid `1.45`. |
| Unknown additive top-level field under declared `1.45` | Accept while ignoring the unknown field. | Valid `1.45`. |
| Previous renderer and conformance identities | Accept as a known current-shape report. | Valid `1.45`. |
| Unknown schema version | Reject before interpretation. | Invalid under every released Schema. |
| Unknown renderer identity | Reject before rendered interpretation. | Structurally valid `1.45`. |
| Unknown renderer conformance profile | Reject before rendered interpretation. | Structurally valid `1.45`. |
| Unknown ordering policy | Reject before ranking. | Invalid `1.45`. |
| Unknown Impact Assessment policy | Reject before selecting main events. | Invalid `1.45`. |
