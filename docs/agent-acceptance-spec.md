# Text-Only Agent Acceptance Specification

Status: accepted evaluation contract

Version: `agent-acceptance/1`

Last verified: 2026-07-16

## Objective

An evaluated agent must use one canonical Structured Report to answer:

> What changed, how much did it change, where did its outcome occur, what changed facts may have caused it, and which conclusions are limited by analysis coverage?

The agent succeeds by recovering faithful evidence and qualifications, not by guessing what the two SVGs look like. This contract defines the task and scoring dimensions. Corpus contents, human labels, the evaluation harness, aggregate metrics, and release thresholds are separate roadmap items.

## Evaluation boundary

For each case, the agent receives only:

- the complete Structured Report JSON;
- the canonical task prompt below;
- the acceptance-contract version.

The agent must not receive the source SVGs, rendered images, filenames that reveal the edit, fixture labels, human reference answers, or access to a renderer or multimodal tool. The harness may retain those artifacts for ground-truth construction and scoring, but they are hidden from the evaluated agent.

Reports must validate against their declared JSON Schema before evaluation. A schema-invalid report is an engine or harness failure, not an agent failure.

## Canonical task prompt

```text
Read the SVG Diff Structured Report and return an evidence-grounded comparison.

First state whether the report establishes a complete comparison, a partial comparison, or a failed analysis. Use coverage_matrix to name every limited or failed feature-layer cell and its Diagnostics, and report any encountered renderer_capability_gaps without treating an empty array as global renderer support. Then identify every reported visual-semantic difference, including differences with zero rendered magnitude. For each difference, report its kind, subject, measured magnitude with units, location when available, and possible changed causes. Distinguish a sound over-approximation from unproven causation. Identify the main visual changes from every `impact_assessment.frontier_group`: preserve exact ties and incomparable groups, disclose partial or missing measurements, and never turn `event_rendered_pareto/v1` into a severity label or total order. State any Diagnostics that prevent equality, magnitude, location, or causal conclusions. Cite the report IDs supporting each claim. Never treat missing or indeterminate evidence as zero.
```

The harness may request JSON or natural language, but it must preserve every required answer component below. Machine scoring should use the answer record; natural-language quality is not part of this contract.

## Query-conditioned concern overlay

`agent-acceptance/1` remains a context-free task. A separate evaluation may append caller context that identifies a concern, but it must retain the canonical prompt and complete difference-enumeration requirement. The overlay is evaluation input, not a Structured Report field or hidden engine label.

When the supplied context resolves to report evidence, the answer must include every matching event and Atomic Difference even if the event is dominated by the Impact frontier. It must distinguish “matches the caller's concern” from “belongs to the context-free main frontier.” Authored IDs or text may resolve an explicitly caller-named target but cannot create semantic importance on their own. If the context cannot be resolved, the answer must state that the concern is not identifiable from the report and must still enumerate all reported differences.

## Required answer record

The normalized answer record contains:

| Component | Required content | Report evidence |
| --- | --- | --- |
| Coverage | `complete`, `partial`, or `failed`; whether profile-scoped equality is established, disproved, or not established; every limited or failed feature-layer cell; encountered renderer capability gaps; all conclusion-limiting Diagnostics | `analysis_status`, `coverage_matrix`, `renderer_capability_gaps`, `diagnostics`, `profile` |
| Differences | One entry for every reported Atomic Difference, including source-only and zero-rendered differences | `atomic_differences`, referenced `changed_facts` |
| Kind | Domain, change description, and before/after semantic values when available | Atomic Difference domain, source/computed fields, evidence layers |
| Subject | The affected aligned subject or explicit unattributed status | `subject_alignment_id`, `subject_alignments`, event references |
| Magnitude | Available exact measurements with their units and status; explicit unavailable or indeterminate state where relevant | `magnitude`, `presence_magnitude`, rendered outcome, Diagnostics |
| Location | Referenced Difference Region IDs and reported bounds or an explicit statement that no location was computed | `events`, `difference_regions` |
| Possible causes | Candidate Changed Fact IDs, guarantee, fallback scope, and limiting Diagnostic IDs | `cause_envelope`, `changed_facts` |
| Main changes | An ordered subset of events or differences with a short evidence-based rationale and explicit ambiguity when cross-domain ordering is not defined | events, domain ordering, magnitude, regions |
| Traceability | Stable report IDs for every difference, region, candidate cause, and Diagnostic claim | report-local identifiers |

The answer may combine several Atomic Differences into one event-level sentence, but it must retain a lossless mapping to every difference ID. It may use human-readable descriptions in addition to identifiers, never instead of them.

## Correctness rules

1. Read `analysis_status` before difference counts. Only a `complete` report with no Atomic Differences may establish equality, and only within the recorded profile and support contract.
2. Enumerate source-only and computed-equivalent differences. Zero changed pixels do not erase a supported authored or computed distinction.
3. Preserve multidimensional magnitude. Do not invent a universal score, convert unavailable data to zero, or compare unlike domains as though their units were interchangeable.
4. Localize only from reported Difference Regions or explicit computed bounds. Do not infer coordinates from source values alone unless the answer labels that inference and the benchmark permits inferred descriptions.
5. Describe a `sound_overapproximation` Cause Envelope as a causally complete set of possible changed causes, not as proof that every candidate contributed. Describe `not_established` as lacking a causal-completeness guarantee.
6. Surface every Diagnostic that constrains a conclusion used in the answer. An unchanged unsupported construct does not permit equality.
7. Rank within a domain only under its reported policy. Cross-domain main-change selection must cite magnitude, extent, event structure, or human-label tolerance and acknowledge ties or ambiguity when evidence does not determine one order.
8. Do not claim visual salience from source wording, authored IDs, or the number of Atomic Differences alone.
9. A caller-concern match is selected from the complete report before Impact interpretation. Frontier exclusion or small magnitude cannot suppress a matching item, and missing resolvable context means unknown importance rather than low importance.
10. Do not infer source-byte identity from an empty complete visual report. Pure XML formatting variations are outside Atomic Differences, while supported authored representation changes remain explicit source-semantic evidence.

## Case-level scoring dimensions

Each case is scored independently along these dimensions. The current report-only benchmark implements coverage safety, Atomic Difference recall, exact magnitude-claim fidelity, localization, Cause Envelope recall, and main-change ranking as separate metrics and thresholds; it does not collapse them into one score. Kind and free-text description quality remain contract requirements for a future independently labeled language-model benchmark.

| Dimension | Full-credit behavior | Typical error |
| --- | --- | --- |
| Coverage safety | Matches status and equality permission; reports all conclusion-limiting Diagnostics | Claims equality from an empty partial report |
| Atomic Difference recall | Accounts for every expected report difference ID without inventing unsupported differences | Omits computed-equivalent or zero-rendered change |
| Kind fidelity | Correctly reports domain, semantic relation, and before/after meaning | Calls a paint spelling change a visible color change |
| Magnitude fidelity | Preserves values, units, signs where meaningful, zeros, and unavailable states; current exact scoring compares the field, status, JSON value, and unit for each cited Atomic Difference | Converts missing data to zero or exaggerates a tiny geometric delta from raster count |
| Localization | Identifies accepted region IDs and bounds, or correctly states that localization is unavailable | Invents a location or attaches another event's region |
| Cause-envelope recall | Retains required candidate cause IDs and guarantee state | Drops an actual-cause candidate or states that all candidates definitely caused the outcome |
| Main-change interpretation | Selects an accepted main event or allowed alternative and supports it with report evidence | Ranks by difference count or authored ID |
| Evidence traceability | Every substantive claim resolves to the correct report-local IDs | Gives a plausible narrative with no recoverable evidence links |

False-positive cause volume is an engine metric, not an agent error, when the agent faithfully reports the supplied envelope. The agent is scored on interpreting the guarantee and retaining relevant candidates.

## Hard safety failures

Regardless of aggregate score, a case fails the safety gate if the answer:

- claims equality for `partial` or `failed` analysis;
- treats `not_computed`, absent, unsupported, or indeterminate evidence as measured zero;
- states that a Cause Envelope candidate definitely caused the rendered outcome when the report provides only possible-cause semantics;
- omits a Diagnostic that directly invalidates an equality or main-change conclusion it makes;
- fabricates a measurement, location, subject, cause, or report identifier;
- reports no difference solely because canonical pixels are equal while supported source or computed differences exist.
- omits a report-resolvable caller concern solely because its event is dominated, spatially small, or absent from the Impact frontier.

These gates protect the tool's terminal purpose: a fluent but unsafe answer is not acceptable evidence for an agent without independent image access.

## Ground truth required per corpus case

Every future evaluation case must provide hidden labels for:

- allowed analysis-status and equality conclusions;
- expected Atomic Difference IDs and acceptable semantic descriptions;
- expected subject alignment or explicit unattributed outcome;
- magnitude values, units, statuses, and numeric tolerances;
- accepted Difference Region IDs plus ground-truth or conservative reference bounds where applicable;
- required actual-cause facts and acceptable conservative candidate sets;
- accepted main-change choices, ties, and alternative descriptions;
- Diagnostics that must appear in a safe answer;
- whether each hard safety failure is applicable.

Human labels may allow multiple faithful descriptions, but cannot authorize claims stronger than the Structured Report. Renderer-conformance failures, report-model failures, and agent-interpretation failures must be recorded separately so a bad input report is not scored as an agent mistake.

## Worked acceptance sketches

| Report case | Required conclusion | Unacceptable conclusion |
| --- | --- | --- |
| `red` to `#ff0000`, complete, computed-equivalent, zero pixels | Report the source spelling difference and zero measured visual effect | "The files are identical" or "the color visibly changed" |
| `1.0` to `0.99999`, partial, tiny computed displacement, guarded nonzero pinned-raster response | Preserve the tiny CSS-unit displacement, surface `renderer_fractional_geometry_unproven`, and avoid claiming visible change from the guarded pixel count | Use changed-pixel count as the displacement, omit the Diagnostic, or call the edit major without a policy |
| Opaque red to blue rectangle with a localized region | Report paint kind, resolved color change, magnitude, region, and possible changed fill fact | Mention a color change without its subject, location, or evidence IDs |
| Inserted zero-opacity shape | Report insertion and geometric footprint separately from zero painted and raster contribution | Drop the insertion because it is not visible |
| Guarded path parameter or topology differences | Report every exact normalized path finding and its parameter delta; describe an available boundary distance as a pinned isolated observation and retain `unsupported_visual_subject` | Discard the findings because the report is partial, or claim complete path/browser semantics from the boundary scalar |
| Parent transform-list, cumulative-matrix, and typed component change | Report the one authored transform cause, all referenced Atomic Differences, the typed component magnitude in its declared units, and changed pixel components selected within the union of before/after cumulative conservative painted bounds | Turn raw matrix coefficients into a distance, compare unlike component units, or treat conservative transformed bounds as exact continuous outlines |
| Empty difference list with unsupported path Diagnostic | State that equality is not established | "No visual differences" |
| Partial Cause Envelope | Report candidates with `not_established` and limiting Diagnostics | Claim all actual causes are necessarily included |

Detailed field-reading examples remain in the [Text-Only Agent Report Guide](agent-report-guide.md). The present document is the acceptance contract that future corpus and harness work must implement.
