# Structured Report Prototype Verdict

Status: first scenario-driven vertical slice complete

## Verdict

The layered report abstraction is feasible for the tested slice. MoonBit can preserve authored evidence through a separate source layer, compare resolved scene facts through `mizchi/svg`, obtain canonical raster response through `mizchi/svg` plus `mizchi/pixelmatch`, distinguish resource changes from entity outcomes, represent zero contribution numerically, preserve indeterminate analysis without coercing it to zero, and serialize the resulting report as JSON.

The prototype is not production code. Authored values are read from `Milky2018/xml@0.4.0` namespace-aware events and recovered through dependency-provided Source Spans rather than fixture-specific string splitting, while comparison and alignment logic remain fixture-specific.

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

## Model findings

1. The resolved `mizchi/svg` scene graph is sufficient to establish computed equivalence for the tested solid colors, geometry values, and gradient stops, but it cannot preserve authored spellings such as `red` versus `#ff0000` by itself.
2. Resource and entity results can remain separate Atomic Differences while one Event owns the union rendered magnitude. Copying raster measurements into each Atomic Difference is unnecessary and risks double-counting.
3. Rendered outcomes need an explicit status and optional magnitude. `not_computed` cannot be represented by numeric zero.
4. A Visual Resource remains reportable when unreferenced, and scene lookup is enough to avoid the tested false Entity outcome. General dependency propagation still requires Influence Provenance.
5. Public MoonBit records derived with `ToJson` can represent the proposed layered JSON without a custom serializer for this slice.

## Deliberate prototype shortcuts

- Recognizes only fixture identifiers `box`, `gradient`, and `label`.
- Looks up only the fixture element names and identifiers even though the source parser itself handles strict nested markup and source spans.
- Handles one changed semantic facet per ordinary rect comparison and one fixed gradient dependency pattern.
- Uses fixed `16 x 16` profile dimensions instead of implementing Comparison Viewport resolution.
- Uses the current renderer's RGBA8 output; it does not validate the accepted linear-sRGB premultiplied arithmetic contract.
- Does not implement Subject Alignment, general event construction, complete Changed Fact enumeration, Cause Envelopes, Difference Regions in JSON, perceptual metrics, profile background handling, or renderer identity pinning.
- Treats all font-dependent text computation as the documented V1 TODO.

## Next production question

Replace the prototype source extractor with a real Source Semantics parser and test whether authored nodes can be linked reliably to the normalized `mizchi/svg` scene graph without losing changed facts. Until that mapping is demonstrated, the prototype validates report composition but not exhaustive SVG difference extraction.
