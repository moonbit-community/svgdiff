# Benchmark Failure Attribution

Status: current benchmark policy

Policy version: `svgdiff-failure-classification/1`

Last verified: 2026-07-14

Benchmark results distinguish observations from regressions and preserve the pipeline layer responsible for each condition.

| Domain | Meaning | Evidence source |
| --- | --- | --- |
| `renderer_conformance` | A pinned renderer behavior is known to diverge from the accepted SVG semantics or conformance oracle. | Explicit renderer Diagnostics for style precedence, fractional geometry/opacity, gradient rasterization, and group compositing. |
| `feature_coverage` | The requested SVG semantic is outside the currently proven analyzer or deterministic profile. | Unsupported or deferred capability Diagnostic. |
| `input_failure` | The input cannot form a usable comparison document. | Parse or input Diagnostic such as `svg_parse_failed`. |
| `report_model` | The report was produced, but a report-layer localization, causal-recall, or causal-precision metric missed its gate. | Failed `report_*` threshold check. |
| `agent_interpretation` | The report evidence was available, but the text-only answer missed safety, recall, ranking, localization, causal, or evidence-reference gates. | Failed `agent_*` or invalid-reference threshold check. |
| `unclassified` | A new Diagnostic or threshold metric lacks an explicit policy entry. | Classifier fallback that requires policy review. |

A Diagnostic is an observation, not automatically a regression. The curated unsupported-path case intentionally yields `feature_coverage`; its presence explains absent path conclusions without blaming the renderer or agent. A threshold failure is a regression under the selected threshold policy.

The region-overlap baseline is `0.75`: three of four browser-valid localizable cases currently pass, while unsupported path localization remains the one planned report-model gap. The earlier `0.8` value counted a pinned-renderer micro-geometry artifact as a fifth reference region; the browser oracle proved that outcome has zero changed canonical pixels, so the annotation and denominator were corrected together.

`scripts/run-agent-benchmark.sh` writes `failures.json` before returning the threshold gate status. Therefore a failing adapter still leaves enough evidence to attribute the failure. The classifier never infers renderer blame from a generic partial report: only an explicit renderer-conformance Diagnostic may enter that domain.

Update `failure-classification.v1.json` when a Diagnostic or gated metric is added. Unknown values remain `unclassified` until that review occurs.
