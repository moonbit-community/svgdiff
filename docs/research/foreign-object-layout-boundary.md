# Static `foreignObject` Layout Boundary

Evidence snapshot: 2026-07-17

This note asks what svgdiff must own before it can claim visual-semantic completeness for static `foreignObject` content. It does not change the current Comparison Profile.

## Conclusion

General static HTML inside `foreignObject` requires an HTML element-semantics
layer, the CSS cascade, a box/line layout and painting engine, a deterministic
font path, closed resources, and the outer SVG composition path. XML parsing or
an SVG rasterizer alone cannot supply that result. Embedding a pinned browser is
one possible implementation, but its output is canonical only if svgdiff closes
and identities all of those inputs; otherwise it remains a target-local browser
observation.

The answer is narrower than “all `foreignObject` needs an HTML engine.” SVG
allows arbitrary non-SVG namespaces, including MathML. An HTML/CSS engine can
cover a declared XHTML vocabulary, but general foreign-language support needs a
registry of separately admitted language evaluators. Unknown namespaces remain
unsupported rather than being coerced to HTML or empty content. SVG 2 explicitly
describes foreign content as being rendered by other user-agent processes and
does not require an SVG user agent to support arbitrary foreign object types
([SVG 2 embedded content](https://svgwg.org/svg2-draft/embedded.html#ForeignObjectElement)).

A much smaller project-owned canonical subset is viable. It must have its own
profile identity and must say “supported rectangular XHTML subset,” never
“HTML/CSS equivalent.” The first tracer should avoid text and ordinary flow; a
useful prose subset should wait for the accepted deterministic font runtime and
real line-layout work.

## Current project boundary

- The current secure-static profile does not implement `foreignObject`; its unsupported-input property test forbids complete equality.
- `mizchi/svg@0.2.1` explicitly skips `foreignObject` cases and supplies no hidden HTML layout support.
- Current inputs are XML SVG strings parsed by `Milky2018/xml`; svgdiff does not run an HTML parser, construct an HTML document, load resources, execute scripts, or inspect a browser layout tree.
- Font, color, script, interaction, animation, resource, and multi-renderer contracts remain independent and unimplemented where documented.
- Schema `1.44`, renderer/conformance identity, public interfaces, CLI behavior, and release assets remain unchanged.

## The semantic chain that must not be collapsed

### 1. Parsing and expanded names

`foreignObject` does not itself select one universal parsing algorithm.

For an SVG delivered in an XML serialization, XML namespace declarations
determine every element's expanded name. The default namespace applies to
unprefixed element names in its scope, but not directly to unprefixed attributes
([Namespaces in XML 1.0, namespace defaulting](https://www.w3.org/TR/xml-names/#defaulting)).
Therefore this common fragment is XHTML only because of the explicit namespace:

```xml
<foreignObject width="100" height="50">
  <div xmlns="http://www.w3.org/1999/xhtml">text</div>
</foreignObject>
```

Without that `xmlns`, an inherited SVG default namespace makes `div` an
SVG-namespaced element. It must not be silently reclassified as HTML. The HTML
Standard separately defines the XML syntax for XML resources and bases it on
XML plus Namespaces in XML
([HTML: XML syntax](https://html.spec.whatwg.org/multipage/xhtml.html#the-xhtml-syntax)).

When an SVG fragment is instead parsed by the HTML parser, SVG
`foreignObject` is an HTML integration point: qualifying child tokens re-enter
HTML parsing, while nested `svg` and `math` switch namespaces according to the
foreign-content tree builder
([HTML tree construction](https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign),
[HTML integration points](https://html.spec.whatwg.org/multipage/parsing.html#html-integration-point)).
That HTML repair behavior is not interchangeable with XML parsing. Profile
identity must name the input MIME/serialization, parser algorithm and version,
namespace policy, entity/DTD policy, encoding, and parse-error behavior.

### 2. Outer SVG integration

The `foreignObject` `x`, `y`, `width`, and `height` geometry defines a
positioning rectangle. For document fragments, that rectangle is a CSS
containing block in the current SVG coordinate system; transforms affect its
scale, absolutely positioned descendants use it, and `overflow` controls
clipping. Zero width or height disables rendering
([SVG 2 placement](https://svgwg.org/svg2-draft/embedded.html#Placement)).

Foreign output is then subject to the outer SVG transform, clipping, masking,
filters, opacity, blending, and compositing
([SVG 2 `foreignObject`](https://svgwg.org/svg2-draft/embedded.html#ForeignObjectElement)).
A nested SVG descendant is not ordinary HTML content: a nested `svg` root must
establish a new SVG fragment and viewport before SVG descendants render
([SVG 2 coordinate systems](https://svgwg.org/svg2-draft/coords.html#EstablishingANewSVGViewport)).

Consequently, solving inner layout does not prove final pixels when the outer
effect or raster path is guarded. Svgdiff must retain separate coverage for the
positioning rectangle, inner layout, foreign painting, and outer composition.

### 3. Static HTML still requires a layout engine

CSS first cascades and inherits values, then generates a box tree, anonymous
boxes and fragments; each inner display type selects a formatting context such
as flow, table, flex, grid, or ruby
([CSS Display 3](https://www.w3.org/TR/css-display-3/#intro)). General HTML
therefore requires more than computed declarations. It requires the selected
formatting algorithms, containing blocks, intrinsic/percentage sizing,
positioning, line construction, bidi/writing modes, fragmentation, overflow,
painting order, and device-space rounding.

Inheritance follows the element tree, so inherited properties can cross the
SVG/XHTML boundary. The cascade also has user-agent, user, author, animation,
transition, and important origins; `revert` can expose lower origins
([CSS Cascade 5](https://www.w3.org/TR/css-cascade-5/#cascading-origins),
[inheritance](https://www.w3.org/TR/css-cascade-5/#inheriting)). Selector
matching observes element namespaces, and CSS `@namespace` changes which
elements a selector can match
([Selectors 4 namespaces](https://www.w3.org/TR/selectors-4/#type-nmsp)). A
canonical profile must pin or forbid every origin, selector family, namespace
mapping, presentational hint, and custom-property behavior it can encounter.

HTML defaults are part of the visible result. The HTML rendering section
defines a suggested/default-rendering UA stylesheet with namespace-qualified
block, margin, list, table, link, hidden, and other rules; conforming
“supporting the suggested default rendering” UAs treat its expectations as
requirements
([HTML rendering](https://html.spec.whatwg.org/multipage/rendering.html#rendering)).
Replacing that sheet with a project-owned minimal sheet is valid only as a new
canonical subset, not as a browser-equivalence claim.

Intrinsic and percentage sizes can depend cyclically on content and containing
blocks
([CSS Sizing 3](https://www.w3.org/TR/css-sizing-3/#percentage-sizing)).
Overflow values distinguish visible painting, clipping, and scroll-container
behavior
([CSS Overflow 3](https://www.w3.org/TR/css-overflow-3/#overflow-properties)).
These facts rule out a shortcut that merely maps HTML element bounds to SVG
rectangles after parsing.

## Independent execution axes

Even a static DOM leaves these independent inputs:

| Axis | Canonical requirement | Current relationship |
| --- | --- | --- |
| Markup/host language | Exact expanded names, HTML/XML mode, element semantics, presentational hints | New foreign-language profile field |
| Cascade/layout | Exact UA sheet, author grammar, origins, selectors, formatting algorithms, precision and rounding | Not supplied by current SVG cascade |
| Fonts/text | Closed Font Bundle, matching, shaping, bidi, line breaking, glyph raster and fallback | Reference the accepted font contracts; not implemented |
| Replaced resources | Exact before/after bundle bytes, MIME/decoder, intrinsic size, orientation and failure | Reference resource contracts; no implicit fetch/path access |
| Color/paint | Exact color profile, system-color policy, gradients/images, alpha and compositing | Reference color profile; system colors are ambient unless pinned |
| Script/custom elements | No execution in canonical analysis; no script-defined DOM or custom-element upgrade | Permanent script-free canonical boundary |
| Interaction/state | Explicit state profile; links, focus, selection, scroll offsets, controls otherwise unsupported | Reference interaction contract |
| Animation/transitions | Disabled profile is distinct from a sample at time zero | Reference animation-timeline contract |
| Forms/widgets/media | Exact current values, validation, media frame and platform appearance, or explicit exclusion | Initially unsupported/observation-only |
| Environment | Viewport, DPR, media queries, zoom, locale, language, writing mode, reduced-motion/contrast/color preferences | Every admitted value fixed in profile |
| Outer SVG | Geometry, transforms, overflow, effects, stacking, compositing and raster conformance | Current guards remain authoritative |

CSS font matching explicitly depends on an implementation-defined installed
font set and platform/locale choices
([CSS Fonts 4](https://www.w3.org/TR/css-fonts-4/#font-matching-algorithm)).
Canonical foreign text therefore cannot use ambient fonts or generic-family
fallback.

HTML form controls can have native appearance and UA-specific widget layout
([HTML widgets](https://html.spec.whatwg.org/multipage/rendering.html#widgets)).
They are not deterministic rectangles derived from attributes. System colors
similarly reflect browser, OS, user, color-scheme, and forced-color choices
([CSS Color 4 system colors](https://www.w3.org/TR/css-color-4/#css-system-colors)).
Both remain unsupported in the first canonical subsets.

## Recommended canonical boundary

Reserve `svgdiff-foreign-object-layout-profile/1` as a future profile identity.
It admits one named foreign-language evaluator and never implies support for an
unlisted namespace or CSS feature.

### Smallest viable tracer: rectangular XHTML

The first implementation slice should be deliberately unambitious:

1. XML-parsed SVG only; one explicit XHTML-namespace `div` tree; no HTML repair, nested SVG/MathML, custom, or unknown elements.
2. Character data is empty or XML whitespace; text requires the font and line-layout profiles.
3. Only element-attached `style`; no stylesheet, `@import`, selectors, pseudo-elements, presentational hints, user styles, animation, transition, or variables.
4. Each box explicitly declares `position`, `left`, `top`, `width`, `height`, and `box-sizing` in finite non-negative CSS px. Admit only reviewed absolute rectangular containing blocks; reject auto, percentages, intrinsic sizing, flow, floats, flex, grid, tables, columns, ruby, logical properties, writing modes, and fragmentation.
5. Paint only transparent or solid sRGB backgrounds and reviewed solid borders, fixed clipping, and source-over alpha. Reject images, gradients, shadows, filters, blends, transforms, opacity groups, generated content, and scrolling UI.
6. Admit outer `foreignObject` only when its SVG geometry, transform, overflow, stacking, and composition are independently admitted.

This slice answers whether the boundary integration and causal model work. It
does not yet address the main prose use case. The next useful slice adds normal
block/inline flow only after closed font selection, shaping, line breaking,
bidi, writing modes, whitespace, baselines, glyph paint, and raster conformance
have their own tests.

General HTML support must not be described as an incremental extension of this
rectangle placer. It is a separate breadth claim requiring each relevant CSS
formatting module and HTML rendering rule to pass the ownership gate.

### Exact profile identity

Every profile instance must include or hash:

1. profile version, canonical manifest hash, exact before/after source hashes;
2. MIME/serialization, encoding, XML/HTML parser and namespace algorithms,
   entity/DTD and parse-repair policy;
3. admitted namespace-to-language evaluator registry and exact vocabulary/spec
   snapshots;
4. DOM/element semantics, presentational hints, UA stylesheet bytes, user-style
   policy, cascade origins/layers, selector and computed-value implementations;
5. supported layout modules, box generation, containing-block, intrinsic-size,
   line/bidi/writing-mode, overflow, painting-order, precision and rounding
   policies;
6. outer SVG geometry/effect/compositor and renderer-conformance identities;
7. Font Bundle, Font Execution, resource-bundle, color, script, interaction,
   animation-timeline and accessibility/source-audit profile references;
8. viewport, CSS px mapping, DPR, zoom, media type/features, locale, language,
   timezone where observable, color scheme, forced colors and preference values;
9. evaluator source/build/dependency/toolchain/target identity, raster format,
   antialiasing and output normalization;
10. all input, DOM, CSS, selector, box, fragment, text, glyph, image, surface,
    work, recursion, time and output limits plus deterministic failure policy.

Changing any rendering-relevant field changes profile identity. A schema
version, browser version, font hash, or viewport alone is never sufficient.

## Evidence layers and causality

Keep these records distinct and link them by typed provenance edges:

1. source bytes, spans, markup and authored declarations;
2. parsed nodes with exact expanded names and parse provenance;
3. cascaded/computed styles and dependency provenance;
4. used box tree, anonymous boxes, fragments, containing blocks and overflow;
5. shaped text runs and positioned glyphs;
6. decoded/replaced resource content and intrinsic metrics;
7. painted foreign fragments before outer SVG effects;
8. outer transformed/composited pixels and rendered difference regions;
9. coverage, Atomic Differences, Visual Events and conservative Cause
   Envelopes.

A screenshot can establish target-local pixels and regions. It cannot recover
complete computed style, box correspondence, shaped runs, resource selection,
or causal contribution. DevTools snapshots may be additional target evidence,
but their private data model is not a canonical semantic layer.

## Outcome taxonomy

Do not coerce any of these outcomes to transparent content, zero area, or
equality:

| Outcome family | Required classification/claim limit |
| --- | --- |
| Malformed XML/namespace | Existing parse failure, or exact namespace error; no repaired-HTML substitution |
| Unsupported language/element | Preserve source and expanded name; foreign computed/rendered coverage limited |
| Unsupported CSS/HTML behavior | Preserve declarations and any independent outer geometry; computed/layout/paint partial |
| Missing/blocked/invalid resource | Preserve locator and bundle result; no network, file, or fallback substitution |
| Font/layout/paint unavailable | Preserve upstream evidence; no system fallback or zero-size box |
| Script/dynamic/custom-element dependency | Canonical execution disabled; source retained and affected layers partial |
| Interaction/form/widget/media state | Unsupported or explicit external observation; never guessed from attributes alone |
| Privacy-sensitive/ambient value | `:visited`, system colors, user styles/preferences, native widget or scroll state unavailable unless exact observation identity closes it |
| Outer SVG effect unavailable | Inner evidence may remain valid; final composition/rendered completeness limited |
| Limit exceeded | Typed stage and exact limit; no truncated DOM, box tree, text, resource or raster treated as complete |
| Evaluator/conformance divergence | Retain each cell and profile; disagreement is sensitivity, not majority truth |
| External target failure/ambient drift | Observation failed or ambient-unreproducible; canonical report unchanged |

## External browser observation

A future `svgdiff-foreign-object-observation/1` may capture one exact target. It
must record the source/resource/font hashes; load/referencing mode; browser
binary/build/flags; OS, architecture, graphics/font/color backends; UA sheet and
feature policy where obtainable; viewport, DPR, zoom, media/preferences,
locale/language; script/interaction/animation state; requested and achieved
capture phase; DOM/style/layout snapshot method; raster format/color/alpha;
repeat agreement; errors; and unavailable ambient inputs.

The load mode matters because SVG processing modes independently enable or
disable script, external references, declarative animation, and interaction.
Secure static disables all four, and disabled external references behave as
network failures
([SVG Integration processing modes](https://www.w3.org/TR/svg-integration/#processing-modes)).

Browser output remains target-local. It cannot upgrade current Structured
Report coverage, become canonical because two browsers agree, or identify which
engine is correct when targets diverge. Cross-target work belongs in the
accepted typed multi-renderer matrix and must retain all confounders.

## Security and resource limits

Canonical admission starts secure-static: no scripts or event-handler
execution, no custom-element upgrade, no user interaction, no declarative
animation, and no implicit external acquisition. SVG Integration explicitly
includes HTML scripts in its script-execution feature definition
([SVG Integration features](https://www.w3.org/TR/svg-integration/#features)).

The initial subset rejects `iframe`, `object`, `embed`, media, forms, canvas,
nested documents, external stylesheets, CSS `url()`/`@import`, `@font-face`,
navigation, downloads, network/service workers, storage, and host APIs. Later
resources resolve only through exact caller-supplied before/after bundles. XML
external entities and DTD acquisition stay disabled.

Before implementation, fix independent limits for encoded bytes, XML depth and
nodes, namespaces and attributes, CSS bytes/tokens/rules/selectors, cascade
matches, computed properties, boxes and anonymous boxes, fragments, intrinsic
size iterations, bidi/text/glyph work, fonts and decoded resources, paint
commands, clip/effect nesting, pixels/surfaces, outer composition, diagnostics,
report bytes, elapsed work and cancellation. Crossing a boundary returns a
typed unavailable/limit result; partial output is never complete evidence.

## Rejected shortcuts

- Treat every child name inside XML `foreignObject` as HTML.
- Feed an XML subtree to the HTML fragment parser and call repaired output the
  authored tree.
- Render only the `foreignObject` rectangle or serialize child text into SVG
  `<text>`.
- Reuse the current SVG author-cascade subset as a general HTML computed-style
  engine.
- Ignore UA styles because the input contains author CSS.
- Use `getBoundingClientRect()` values as complete layout or causal evidence.
- Use ambient fonts, generic families, system colors, native controls, locale,
  scroll state, or resource cache without profile identity.
- Disable scripts/resources and then treat affected content as visually empty.
- Pin only a browser version while leaving OS, backends, preferences, fonts,
  resources, load mode, capture phase, and limits implicit.
- Accept browser screenshots as canonical, infer equality from identical
  screenshots, or vote several engines into semantic truth.
- Claim general HTML/CSS support after the rectangular tracer passes.

## Staged implementation gates

1. **Contract only**: accept the authority split, identity, evidence layers, outcomes, and Agent wording without product changes.
2. **Namespace/source inventory**: report expanded names and declarations while retaining partial rendered coverage; test XML-vs-HTML counterexamples.
3. **Rectangular XHTML tracer**: implement the absolute solid-box subset with negative controls and outer-effect guards.
4. **Independent conformance**: compare box/paint records and pixels with a pinned browser; disposition every divergence.
5. **Closed prose slice**: after Font Bundle/Runtime implementation, add bounded block/inline flow, line breaking, bidi, writing mode, glyph, shaped-run, and line-fragment evidence.
6. **Closed replaced resources**: add admitted resource types through exact bundles, intrinsic sizing, decoding, color, and final composition gates.
7. **Additional formatting modules**: admit flex, grid, tables, effects, generated content, or MathML one reviewed family at a time.
8. **External observation**: add a target-local artifact only after exact replay and ambient-state reporting.
9. **General-support reconsideration**: use “general HTML” only after the selected HTML/CSS surface, defaults, fonts, resources, environment, security, limits, and conformance are closed; arbitrary foreign namespaces remain separate.

## Reconsideration triggers

Reconsider the selected ownership only when a concrete dependency supplies
in-memory XML/XHTML fragment admission, deterministic fixed-environment CSS
layout and paint, exact-source builds, no-I/O controls, typed intermediate box
evidence, hard resource limits, compatible licensing, and a maintainable
MoonBit boundary. A headless browser that exposes screenshots but not closed
inputs or stable semantic evidence is an observation target, not that
dependency.

Any scope expansion requires an Agent acceptance case showing that the added
evidence improves report-only identification of what changed, how much, where,
and why; negative controls for unsupported inputs; mutation evidence preserving
real causes; deterministic replay; renderer dispositions; security/resource
tests; and a new profile identity. Until those gates exist, the current
`foreignObject` coverage guard is the correct complete-analysis behavior.
