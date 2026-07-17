# Multi-Renderer and Browser Profile Comparisons

Status: decision research for ISS-154

Last verified: 2026-07-17

## Question

Should svgdiff compare one renderer under several execution profiles, several
renderers under one profile, or both?

The recommended answer is **both, as different typed questions inside a
factorial matrix**. A matrix does not create a new canonical renderer. Each
cell preserves one exact engine/profile result, and each edge says which axis
was held constant. A diagonal that changes engine and profile together is
confounded unless compatible intermediate cells exist.

This is a future evidence-container boundary. It does not change the current
single-profile Structured Report, add a renderer, or implement cross-browser
capture.

## Primary-source findings

### SVG conformance does not appoint a pixel-majority oracle

SVG 2 defines several processing modes and says conformance can be restricted
to a feature set; it does not require every SVG user agent to expose one
identical execution environment. Its viewer criteria also allow bounded output
latitude: visual rendering is required to be within one device pixel or point
of the mathematical result, and accurate sRGB systems within one 8-bit channel
value. A cross-engine pixel disagreement can therefore be useful evidence
without proving that one engine is nonconforming.
[SVG 2 conformance criteria](https://www.w3.org/TR/SVG2/conform.html)

SVG processing mode also controls script, external references, animation, and
interaction. Those are execution-profile inputs, not incidental browser names.
The same source captured in two different modes is not a same-profile engine
comparison.
[SVG 2 processing modes](https://www.w3.org/TR/SVG2/conform.html#processing-modes)

### WPT compares declared pairs, not browser votes

Web Platform Tests reftests pair a test with one or more authored references
and assert `match` or `mismatch`. The harness waits for load, web fonts, and
pending paints before taking a viewport screenshot. When exact equality is not
portable, fuzziness is declared for the particular comparison as both maximum
per-channel difference and total differing pixels.
[WPT reftest contract](https://web-platform-tests.org/writing-tests/reftests.html)

This is evidence for versioned, pair-specific comparators. It is not evidence
for treating the most common browser output as truth. Even WPT's multiple-match
rule means that an authored test may match any accepted reference; it does not
derive a reference from a renderer majority.

WPT also treats browser product, channel, binary, revision, arguments, and
experimental features as explicit runner choices. A result from `chrome dev`
with experimental features is not merely another sample of an unnamed
“browser” profile.
[WPT runner arguments](https://web-platform-tests.org/running-tests/command-line-arguments.html),
[WPT Chrome/Chromium configuration](https://web-platform-tests.org/running-tests/chrome.html)

### Playwright closes some inputs but does not erase engine identity

Playwright binds each library version to specific browser binaries and exposes
Chromium, Firefox, and WebKit as separate products. Its default Chromium
headless shell and opt-in newer headless mode can behave differently, and the
docs explicitly note that platform-dependent features vary by operating
system. Browser family alone is therefore too weak an identity.
[Playwright browser binaries and channels](https://playwright.dev/docs/browsers)

Browser contexts expose material inputs such as viewport, device scale factor,
locale, timezone, color scheme, contrast, reduced motion, forced colors,
JavaScript, offline state, and user agent. Playwright warns that opting out of
an explicit viewport makes tests depend on the host window and become
nondeterministic.
[Playwright BrowserType options](https://playwright.dev/docs/api/class-browsertype)

Screenshot options independently affect animations, caret, clipping,
transparency, and CSS-pixel versus device-pixel output. Capture identity must
therefore include the screenshot procedure, not only the browser version.
[Playwright screenshot API](https://playwright.dev/docs/api/class-page#page-screenshot)

## Current project boundary

The current `StructuredReport` compares `before` and `after` under one exact
Comparison Profile. `schema_version`, `renderer_id`, and
`renderer_conformance_profile_id` identify different contracts and cannot
substitute for one another. Browser pixels are an independent oracle used by a
reviewed conformance disposition, not production truth.
[Core model](../core-model.md),
[ADR 0034](../adr/0034-version-renderer-conformance-separately.md),
[browser oracle](../../evaluation/browser-oracle/README.md), and
[renderer conformance](../../evaluation/renderer-conformance/README.md)

Platform font and host color captures already have stronger restrictions.
Exact-bundle/native or mathematical-target captures may be closed external
observations; ambient font discovery, platform color management, and physical
display output remain `ambient_unreproducible`. Neither observation family may
directly establish Structured Report equality, completeness, magnitude,
Impact, regions, or causality.
[Platform font boundary](../platform-native-font-modes.md) and
[color-management boundary](../color-management-profiles.md)

The matrix must preserve those roles. It associates evidence; it does not
promote an external observation into a canonical cell.

## Recommended typed matrix

For one exact before/after input pair, define a conceptual matrix:

```text
                         execution profile
                    P1                         P2
engine E1   cell(E1,P1) ── profile edge ── cell(E1,P2)
               │                              │
          engine edge                    engine edge
               │                              │
engine E2   cell(E2,P1) ── profile edge ── cell(E2,P2)
```

The matrix supports three separate questions:

| Question | Required constant | Varied axis | Maximum claim |
| --- | --- | --- | --- |
| Profile sensitivity | exact engine target and non-profile environment | one declared execution-profile set | this engine's outcome is or is not sensitive to the declared profile change |
| Cross-engine conformance observation | exact execution profile and non-engine environment | engine target | the named engine targets agree or disagree under that profile |
| Full factorial interaction | complete compatible rectangle | both axes, one edge at a time | agreement/disagreement pattern and engine-profile interaction; never a new truth |

“Profile” can contain several declared components, but an edge that changes
several components supports only set-level sensitivity. Attribution to one
component requires that component alone to vary, or a separately versioned
factorial design that exposes its interactions.

## Cell identity

Every cell must be immutable and content-addressed. It records all fields below
or explicitly records why a field is unavailable.

1. **Matrix and input identity**: container version, matrix ID, before/after
   source hashes, resource-bundle manifests and byte hashes, source role,
   processing mode, and requested static state.
2. **Engine target identity**: project renderer ID or browser/product family,
   channel, complete version/build/revision, binary or source hash, frontend and
   graphics backend, headless mode, feature flags, policies, harness/tool
   version, and launch arguments.
3. **Execution-profile identity**: complete Comparison Profile inputs plus
   independently versioned font execution, color execution, resource, time,
   interaction, animation, and any future platform profile identities. A label
   such as `chromium`, `wide-gamut`, or `macOS` is not a profile.
4. **Environment identity**: OS image/build, architecture, runtime/system
   libraries, CPU/GPU/software path and driver, locale, timezone, media/user
   preferences, sandbox, network state, display or virtual target, unresolved
   hidden state, and a closure classification.
5. **Viewport and capture identity**: CSS viewport, DPR/output scale, canvas and
   clip, transparent/background behavior, animation/caret policy, capture API,
   dimensions, pixel format, alpha representation, color space/profile,
   dynamic range, post-processing, and output artifact hash.
6. **Evidence role**: `canonical_project_report`,
   `closed_external_observation`, or `ambient_unreproducible`. The role limits
   claims even when pixels happen to match.
7. **Result**: exact Structured Report and schema identity when the engine can
   produce one; otherwise named raster/artifact observations, coverage and
   Diagnostic inventory, repetition count and byte-agreement, logs, and
   artifact links.
8. **Failure**: typed unavailable, unsupported, timeout, crash, resource-limit,
   capture, or validation outcome. Failure is a cell result, never an empty or
   zero-valued observation.

Engine and environment stay separate. A browser that can run only on another
OS does not create an engine-only edge; it creates a named target observation
whose engine and platform both changed.

## Per-evidence compatibility

Compatibility is decided for each edge and evidence layer, not once for the
whole matrix. An edge records its comparator ID, held-constant fields, changed
fields, and one of `comparable_equal`, `comparable_different`, `incomparable`,
or `unavailable`.

An edge is comparable only when:

- before/after source bytes, resource locators/order/bytes, processing state,
  and time are identical;
- the edge varies only its declared axis; every other relevant engine, profile,
  and environment field is equal;
- both cells completed the relevant evidence layer with compatible coverage;
- corresponding facts, subjects, events, or pixels have a versioned matching
  rule rather than guessed array or ID correspondence;
- numeric methods, units, denominators, alpha, color semantics, background,
  dimensions, coordinate grid, and output encoding are compatible; and
- any tolerance or normalization is named and versioned for that exact edge.

Source or computed evidence may be comparable when raster evidence is not. A
different output size, DPR, color execution profile, HDR/SDR domain, or pixel
grid is not silently resampled or converted. It remains raster-incomparable
until an explicit cross-profile comparator defines the transform and its claim
limits. Reports from different color profiles retain the existing prohibition
on direct equality and ranking.

A common profile is executable only if both engines consume its declared
inputs. Silently ignored flags, fallback resources, hidden fonts, host color
management, or unsupported processing mode make the cross-engine edge
incomparable or ambient; identical-looking pixels do not repair the contract.

## Edge and diagonal classifications

### Same-engine profile edge

With the engine target and non-profile environment held exact, this edge may
report profile sensitivity for every compatible evidence item. It does not say
which profile is correct, and it does not weaken either cell's own
profile-scoped equality conclusion.

### Same-profile engine edge

With the execution profile and non-engine environment held exact, this edge may
report engine agreement or disagreement. A disagreement is conformance input,
not a disposition. It changes a canonical adapter, support boundary,
Diagnostic, tolerance, or `renderer_conformance_profile_id` only through a
separate reviewed decision.

If OS, platform APIs, fonts, color management, display path, or capture
semantics also change, classify the edge as `target_sensitive`, not
`engine_sensitive`.

### Diagonal

An edge from `(E1,P1)` to `(E2,P2)` is `confounded` because engine and profile
both changed. It may describe the two named outputs but cannot attribute the
difference.

The diagonal becomes decomposable only when `(E1,P2)` and `(E2,P1)` also exist
and all four edge comparisons are compatible. The report then preserves both
paths:

```text
(E1,P1) -> (E1,P2) -> (E2,P2)
(E1,P1) -> (E2,P1) -> (E2,P2)
```

Different edge outcomes across the two paths are an
`engine_profile_interaction`, not an error to average away. The rectangle
localizes sensitivity to typed edges but does not prove an internal renderer
cause.

### Missing, failed, and incomparable cells

A missing cell is `not_requested`; an attempted cell has its typed result.
Neither is inferred from neighboring cells. A failed, partial, ambient, or
incompatible cell cannot vote, contribute zero, or establish invariance. The
strongest permitted summary is `insufficient_evidence`, with direct links to
the missing fields, failures, coverage gaps, or incompatible domains.

## Agent-facing conclusions

The future container should derive a lossless conclusion index while retaining
every cell and edge:

| Classification | Required evidence |
| --- | --- |
| `invariant_within_matrix` | every requested compatible edge agrees for the named evidence item; scope lists the exact engines and profiles |
| `profile_sensitive` | at least one comparable same-engine profile edge differs |
| `engine_sensitive` | at least one comparable same-profile, same-environment engine edge differs |
| `target_sensitive` | renderer target differs but engine-only isolation is unavailable |
| `engine_profile_interaction` | a compatible rectangle produces different edge patterns across levels |
| `confounded` | only a diagonal engine-plus-profile comparison supports the observation |
| `insufficient_evidence` | missing, failed, partial, ambient, unmatched, or incompatible evidence blocks the requested conclusion |

Each conclusion must name its evidence layer and comparator, list every
supporting and disagreeing cell/edge ID, retain null and error cases, and state
its exact matrix scope. `invariant_within_matrix` never means universally
renderer-independent.

No renderer majority, plurality, median image, averaged mask, union mask,
intersection mask, minimum error, or “closest browser” becomes semantic truth.
Counts may summarize inventory only; they cannot erase a minority disagreement
or choose a canonical cell. Impact, magnitude, and equality remain cell-local
unless a separately versioned compatible cross-cell method is accepted.

## Rejected alternatives

1. **Same-engine profiles only**: useful for sensitivity, but cannot expose a
   renderer implementation divergence under a fixed profile.
2. **Cross-engine comparisons only**: useful for conformance observations, but
   cannot tell whether a changed output came from the profile rather than the
   engine.
3. **One generic `renderer_diff` relation**: hides the held-constant axis and
   makes confounded diagonals look causal.
4. **Majority or reference-browser truth**: neither SVG conformance nor WPT
   establishes this rule; it discards minority evidence and can make correlated
   implementations outvote a conforming one.
5. **Implicit resampling, color conversion, or tolerance**: changes the
   measurement question and makes incompatible cells appear comparable.
6. **Embed the matrix in Structured Report now**: prematurely couples a future
   experiment container to the stable single-profile report and observation
   boundaries.

## Implementation and reconsideration gates

The deferred multi-renderer implementation should not begin until it has:

- a versioned cell, edge, comparator, and conclusion schema outside Structured
  Report;
- at least two exact engine targets and two execution profiles with a closed
  four-cell fixture rectangle;
- repeatable capture, hostile-resource limits, offline behavior, and exact
  engine/environment/output identity validation;
- versioned cross-cell fact/subject/event correlation and per-evidence
  compatibility checks;
- negative controls for hidden fonts, color management, platform changes,
  dimensions, failed cells, and confounded diagonals;
- fixtures showing engine sensitivity, profile sensitivity, interaction,
  invariance, and insufficient evidence without majority collapse; and
- Agent evaluation showing that the derived index improves explanations while
  preserving direct access to every contrary or unavailable observation.

Promoting any external browser or platform cell into canonical evidence remains
governed by its own renderer, font, color, resource, determinism, and
conformance decisions. This matrix decision cannot do so indirectly.

The no-majority rule should be reconsidered only if a normative authority or a
project-owned mathematical reference defines an explicit hierarchy for one
feature. Even then, that hierarchy is a versioned comparator/disposition for
the named feature, not a vote across engines.

## Conclusion

Adopt a typed factorial model that permits both same-engine profile sensitivity
and same-profile cross-engine conformance observations. Preserve current
single-profile canonical reports as cells, keep external platform/browser
captures observational, require one-axis edges for attribution, classify
engine-plus-profile diagonals as confounded, and give Agents a linked lossless
summary instead of a consensus image.
