# Structured Report Prototype Verdict

Status: inherited-fill Source Semantics slice complete

## Verdict

The layered report abstraction is feasible for the tested slice. MoonBit can preserve authored evidence through a separate source layer, compare resolved scene facts through `mizchi/svg`, obtain canonical raster response through `mizchi/svg` plus `mizchi/pixelmatch`, distinguish resource changes from entity outcomes, represent zero contribution numerically, preserve indeterminate analysis without coercing it to zero, and serialize the resulting report as JSON.

The prototype is not production code. Authored values are read from `Milky2018/xml@0.4.0` namespace-aware events and recovered through dependency-provided Source Spans rather than fixture-specific string splitting. The source-only inherited-fill path represents `<svg>` / `<g>` / `<rect>` hierarchy, resolves the nearest declaration without calling `mizchi/svg`, and keeps one Changed Fact separate from every affected rect resolution. Resource, text, comparison, and alignment logic remain scenario-specific.

## Acceptance scenarios

| Scenario | Result | Validated behavior |
|---|---|---|
| `red` to `#ff0000` | PASS | Source Difference retained; computed paint equivalent; Event raster magnitude zero |
| `x=1.0` to `x=0.99999` | PASS | Computed position differs by approximately `-0.00001 CSS px`; canonical current renderer reports 16 changed pixels |
| `red` to `blue` | PASS | Source, computed, and rendered evidence all present; 64 of 256 pixels differ |
| Referenced gradient stop change | PASS | Separate Resource and Entity Atomic Differences share one entity-anchored Event; raster magnitude computed once |
| Zero-opacity rect insertion | PASS | Presence footprint records 64 CSS px² bounds, zero painted area, and zero changed pixels without a visibility boolean |
| Unreferenced gradient stop change | PASS | Resource Difference remains reportable with zero rendered contribution and no invented Entity outcome |
| Font-dependent text change | PASS | Source Difference retained; computed relation is indeterminate; Diagnostic reduces coverage; rendered outcome is `not_computed` with no magnitude |
| JSON round trip | PASS | Schema version, resolved profile, Atomic Differences, Events, rendered status, and Diagnostics survive serialization and parsing |
| XML formatting variation | PASS | Attribute order, quote style, tag-closing style, and declaration whitespace do not create Atomic Differences |
| Presentation attribute to inline style | PASS | Declaration origin remains reportable at Source Semantics while computed paint stays equivalent and rendered magnitude stays zero |
| Multiple solid-rect properties | PASS | Changed `x`, `fill`, and `opacity` facts are all enumerated and share one Event rendered outcome |
| Unsupported CSS | PASS | Stylesheet/class coverage produces a Diagnostic and partial analysis instead of equality |
| Declared-fact JSON | PASS | Authored value, normalized value, origin, and Source Span survive serialization |
| Inherited `fill` | PASS | The nearest ancestor declaration resolves with owner, origin, inheritance depth, authored value, and Source Span provenance |
| Declaration moved to parent | PASS | Source provenance changes while the resolved fill remains equivalent; renderer-backed evidence is explicitly `not_computed` |
| One ancestor affects multiple rects | PASS | One Changed Fact lists both affected rects and both Atomic Differences reference that fact |

## Model findings

1. The resolved `mizchi/svg` scene graph is sufficient to establish computed equivalence for the tested solid colors, geometry values, and gradient stops, but it cannot preserve authored spellings such as `red` versus `#ff0000` by itself.
2. Resource and entity results can remain separate Atomic Differences while one Event owns the union rendered magnitude. Copying raster measurements into each Atomic Difference is unnecessary and risks double-counting.
3. Rendered outcomes need an explicit status and optional magnitude. `not_computed` cannot be represented by numeric zero.
4. A Visual Resource remains reportable when unreferenced, and scene lookup is enough to avoid the tested false Entity outcome. General dependency propagation still requires Influence Provenance.
5. Public MoonBit records derived with `ToJson` can represent the proposed layered JSON without a custom serializer for this slice.
6. A Declared Visual Fact needs separate authored and normalized values: the authored slice preserves provenance, while normalized value plus declaration origin determines Source Semantics equality.
7. Presentation attributes and inline style can share one fact abstraction without erasing their cascade provenance.
8. Changed Facts and per-subject resolved facts must be separate records: one ancestor declaration can influence multiple rects without duplicating the root fact.
9. A renderer-independent source path can resolve supported inheritance and emit a conservative partial report; unavailable Computed Appearance value semantics or Rendered Evidence remain explicit Diagnostics.
10. Schema `0.3-prototype` adds Changed Facts, resolved source pairs, and Atomic Difference references so inheritance provenance survives JSON without duplicating ancestor changes.

## Deliberate prototype shortcuts

- General geometry and opacity declared-fact comparison still covers only the first `rect`; the source-only fill path supports multiple `<rect>` elements under `<svg>` and `<g>`.
- Resolves only ordinary inherited `fill` declarations. Stylesheets, selectors, CSS custom properties, `currentColor`, paint servers, explicit `inherit`, general CSS syntax, and cross-document Subject Alignment remain unsupported and produce Diagnostics where encountered.
- Gradient, resource, and text paths still recognize fixed fixture identifiers and one fixed dependency pattern.
- Uses fixed `16 x 16` profile dimensions instead of implementing Comparison Viewport resolution.
- Uses the current renderer's RGBA8 output; it does not validate the accepted linear-sRGB premultiplied arithmetic contract.
- Does not implement Subject Alignment, general event construction, complete Changed Fact enumeration, Cause Envelopes, Difference Regions in JSON, perceptual metrics, profile background handling, or renderer identity pinning.
- Treats all font-dependent text computation as the documented V1 TODO.

## Next production question

Establish Subject Alignment for multiple source subjects without treating authored IDs or source order as authoritative identity. The inherited-fill slice now proves hierarchical extraction and one-to-many Changed Fact influence, but it aligns only report-local subject IDs and does not yet validate general visual correspondence.
