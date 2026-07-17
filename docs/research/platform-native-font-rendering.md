# Platform-Native Font Rendering Profiles

Status: decision research; no platform-native font mode is implemented

Last verified: 2026-07-17

## Question

Should Core Text, DirectWrite, GDI, browser text, or system-font rendering be
accepted as svgdiff comparison profiles, or should platform-native rendering be
a permanent non-goal?

The answer depends on which promise a profile makes. The current deterministic
font direction fixes caller-supplied bytes through `svgdiff-font-bundle/1` and
fixes shaping, outline, and coverage execution through a separately pinned
HarfBuzz/FreeType runtime. A platform API can answer a different and useful
question -- “what did this named host render?” -- but it cannot silently answer
the canonical question -- “what is the reproducible visual difference under the
declared svgdiff semantics?”

## Recommendation

Make platform-native font rendering a **permanent non-goal for canonical
deterministic complete-analysis profiles**. Do not let Core Text, DirectWrite,
GDI, a browser, installed fonts, generic families, or platform fallback satisfy
the deterministic text acceptance gates, report equality, causal completeness,
or the canonical renderer identity.

Use exactly three classes:

| Class | Admission | Allowed claims |
| --- | --- | --- |
| Canonical Font Execution Profile | Platform-native execution is permanently excluded. Use the closed Font Bundle plus pinned project runtime. | Canonical complete-analysis claims only after the font implementation gates pass. |
| Exact closed-bundle native/browser capture | A separately named external observation with exact supplied bytes, selected faces, host, framework, modes, and output identity. | Evidence about one named target; conformance/oracle and user-reproduction claims only. |
| Ambient/system-font capture | Exploratory `ambient_unreproducible` evidence when installed resources, fallback, defaults, or host state remain open. | “This host rendered these captured pixels” only; no baseline, reproducibility, complete-analysis, equality, magnitude, or causal claim. |

Permit a future, separately named **external observational/oracle profile** only
when a concrete user need justifies its implementation. Such a profile records a
host-specific observation and may be used to:

- reproduce a user report on a named macOS or Windows environment;
- compare the canonical renderer with a captured platform or browser result;
- maintain renderer-conformance fixtures; or
- expose platform divergence without averaging or choosing one host as truth.

Keep that observer outside the canonical comparison engine and its Font Execution
Profile. It should produce an independently versioned capture artifact that an
evaluation or presentation layer may associate with a report. Native pixels must
never directly alter complete-analysis availability, equality, magnitude, Impact,
Difference Regions, Cause Envelopes, or Diagnostics produced by the engine; any
later guard or adapter change requires a separate reviewed conformance decision.

An observational profile must never be called portable, canonical, complete, or
deterministic merely because it is repeatable on one machine. It must not replace
Source Semantics, Computed Appearance, shaped-run evidence, Difference Regions,
or Cause Envelopes. A missing or undeclared platform input makes the observation
`ambient_unreproducible` or unavailable; it must not trigger an implicit fallback
to another platform path. Only the exact closed-bundle class may enter a versioned
oracle baseline. The ambient class is exploratory evidence and must remain outside
regression acceptance.

This is not a recommendation to implement these modes now. Current browser
capture already supplies the needed oracle role for non-font renderer work. Add a
native-font observer only after a named acceptance question cannot be answered by
the canonical runtime plus the existing browser oracle.

## Why the profile classes must remain separate

### Canonical deterministic complete analysis

A canonical profile is a closed executable contract. It must identify the exact
font resources, selection and fallback policy, shaping inputs and implementation,
layout rules, outline/raster behavior, resource limits, and final-pixel pipeline.
It must preserve intermediate evidence so an Agent can distinguish a selected
face, shaped run, positioned glyph, outline, coverage mask, and composited pixel.
Agreement must be tested across every supported target, or target identity must
be part of the profile.

The accepted pinned HarfBuzz/FreeType direction can be built and audited as part
of svgdiff, can reject all undeclared resources, and can expose project-owned
intermediate records. The platform frameworks discussed here are operating-system
components. Their implementation and data can change with the host, and their
high-level APIs deliberately perform matching, substitution, and rendering
choices that are not all part of an SVG input.

### External observational/oracle profile

An observational profile is a record of an independently implemented renderer in
a completely described environment. Its pixels are evidence about that renderer,
not a normative reinterpretation of the SVG. It can disagree with the canonical
profile without either result being deleted. It can be used to classify a
conformance gap, but it cannot by itself prove authored equivalence, canonical
rendered equality, a unique cause, or cross-platform visibility.

The current Chromium oracle already follows this separation: it records browser
identity and captured pixels, while the production renderer remains independently
identified. A future platform-font observer should reuse that conceptual model,
not become a selectable substitute inside an otherwise canonical profile.

## Platform findings

### Core Text and Core Graphics

Core Text is capable enough to build a useful macOS observation. Apple documents
character-to-glyph conversion, ligatures and kerning, automatic font substitution
(cascading), font descriptors, collections, metrics, and glyph access. A font
descriptor can be created from supplied data, and process-scoped registration can
make a font discoverable to descriptor matching. These APIs mean a capture tool
can avoid installing a font globally and can often identify the selected font.

They do not close the canonical profile:

- `CTFontCreateWithName` prefers a PostScript name but otherwise performs
  fallback matching and returns the best match, so a requested name is not font
  identity.
- Core Text advertises automatic substitution/cascading. Unless the application
  supplies and verifies every selected face, cascade behavior imports the host's
  visible font collection and platform policy.
- `CTFontCreateForString` chooses the best substitute from the current font's
  cascade list, while `CTFontCopyDefaultCascadeListForLanguages` returns a
  language-sensitive ordered substitution list. Language and cascade state are
  therefore material inputs, not diagnostic decoration.
- `CTFontCollectionCreateFromAvailableFonts` explicitly collects all fonts
  available to the current application. Using it makes the process-visible font
  inventory part of the observation.
- Registration scope and descriptor visibility are process/session state. A
  capture must prove that only the intended process-scoped resources were
  admitted and must record any selected fallback outside them.
- Core Graphics antialiasing, font smoothing, subpixel positioning, and subpixel
  quantization are graphics-context state. The output also depends on the context
  type, transform, backing scale, pixel format, glyph phase, and OS implementation.

A Core Text observer should therefore load exact bundle bytes where possible,
record actual selected faces and glyphs, and fail the “closed fonts” claim if any
glyph comes from an unidentified cascade face. Even with closed bytes, the result
remains a macOS observation identified by the exact OS/framework environment, not
the canonical svgdiff raster.

### DirectWrite

DirectWrite is also technically suitable for a Windows observation. Microsoft
documents both custom collections and in-memory font loaders, so an observer can
construct a collection from caller-supplied resources rather than use the system
collection. This is preferable to installing fonts or asking DirectWrite to
download remote fonts.

DirectWrite nevertheless exposes several independent choices that affect layout
or pixels:

- natural, GDI-classic, and GDI-natural measuring modes use different advance
  semantics; the GDI-compatible modes are tied to display-oriented metrics;
- rendering modes include aliased, GDI-compatible, natural, symmetric-natural,
  ClearType variants, and outline paths; `DEFAULT` delegates the choice to the
  implementation based on the font and size;
- rendering parameters include gamma, enhanced contrast, grayscale contrast,
  ClearType level, pixel geometry, and rendering mode; monitor-derived parameters
  explicitly bind output to monitor/system state; and
- ClearType versus grayscale antialiasing is a separate text-antialias choice in
  current DirectWrite APIs.

A DirectWrite observer must use a custom in-memory collection, select one explicit
measuring mode, text-antialias mode, rendering mode, and complete custom rendering
parameter record. It must not use `DEFAULT`, monitor-derived parameters, the
system font collection, downloadable fonts, or automatic fallback unless those
inputs are deliberately being observed and completely recorded. The exact Windows
build and DirectWrite implementation remain part of observation identity.

These restrictions make DirectWrite useful as an independent oracle but do not
make its output the same contract as the pinned unhinted grayscale canonical
runtime. In particular, GDI-compatible metrics and ClearType pixels intentionally
answer platform-display questions that the canonical profile excludes.

### GDI

GDI should be a permanent non-goal even as a newly implemented general-purpose
observer. Retain it only as an explicitly requested legacy compatibility probe.

Microsoft's documentation describes `CreateFont` as creating a logical font that
the font mapper resolves to an available physical font. The mapper may substitute
a different name, may choose among raster, vector, TrueType, or device fonts, and
may synthesize styles. Default antialias behavior can depend on the user's system
font-smoothing setting. ClearType additionally depends on display stripe order,
orientation, color depth, output device, system smoothing type, and contrast.

This makes the GDI path unusually difficult to close and identify, while
DirectWrite already provides the relevant modern Windows observation with custom
font sets and explicit rendering parameters. If a real application rendered an
SVG through a GDI-dependent stack and exact reproduction is the user question,
capture that stack under a `legacy_gdi_observation` identity. Do not expose GDI as
a routine svgdiff font profile or use it as a conformance authority.

### Browser and system-font behavior

SVG 2 delegates substantial text selection and layout behavior to CSS and
requires `@font-face`. CSS Fonts 4 explicitly leaves the installed-font set
undefined, permits it to vary by user agent, platform, locale, privacy policy, and
user customization, and states that installed fallback can differ between user
agents. Generic families are aliases to locally installed fonts. `local()` asks
the user agent to activate a locally installed face and can continue to another
source when it is unavailable.

Therefore an exact browser executable is necessary but insufficient identity for
a font observation. The same browser build can see different installed fonts,
generic mappings, locale, privacy exposure, system substitutions, or platform
font backends. SVG's `text-rendering` property is also a hint: the user agent may
trade speed, legibility, and geometric precision through antialiasing and hinting
choices. SVG does not define one required raster result.

For a closed browser-font oracle, rewrite or package fixture fonts as verified
`@font-face` byte resources, use collision-free family names, prohibit `local()`,
generic families, network fetches, and system fallback, and verify the actual
selected face for every glyph where the browser instrumentation permits it. This
still yields a result for an exact browser/OS/backend capture identity. If a test
intentionally observes ordinary web/system behavior instead, record the complete
known environment and mark font selection as open whenever the actual selected
resource bytes cannot be proven.

Browser pixels remain especially valuable as an external compatibility oracle
because real SVG consumers are browsers. They are not a replacement for the
canonical profile's inspectable shaping, geometry, and causal layers.

## Inputs that become ambient without an explicit observation contract

The following values can change selection, geometry, or pixels but are not fully
declared by an ordinary SVG document:

1. **Font resources:** installed and user-installed font sets; exact bytes and
   collection face; duplicate names; platform substitutions; process/session
   registrations; downloadable fonts; generic-family mappings; fallback and
   last-resort faces; synthetic bold or oblique; bitmap and color-glyph resources.
2. **Selection and shaping:** platform matcher/cascade version; family model;
   language and locale; script, direction, BiDi and run segmentation; feature and
   variation coordinates; optical sizing; missing-glyph and cluster fallback.
3. **Layout:** API and measuring mode; DPI and device scale; CSS/SVG text-layout
   implementation; rounding; transform; glyph origin and subpixel phase; line and
   baseline policy.
4. **Rasterization:** OS/framework implementation; hinting/interpreter behavior;
   antialias and text-rendering mode; grayscale versus LCD; pixel geometry; gamma,
   contrast, stem darkening, embedded-strike selection, and color-glyph path.
5. **Output pipeline:** graphics backend and context type; CPU/GPU path where it
   can change output; target pixel format and alpha convention; color space;
   background/compositing; clipping; viewport; monitor orientation and properties.
6. **Host and browser:** exact OS build and architecture; framework/library build;
   browser build/revision, platform backend, command line, headless mode, sandbox,
   feature flags, locale, device scale factor, and font-access/privacy policy.

The existence of an API knob does not prove that all implementation behavior has
been made portable. Conversely, a platform can be useful as an oracle even when
some implementation internals cannot be named, provided the profile says that it
is a captured host observation and does not overclaim reproducibility.

## Minimum observation identity

A future `svgdiff-platform-font-observation/1` record should be separate from the
canonical Comparison Profile and Font Execution Profile. At minimum it should
contain:

| Area | Required identity or evidence |
| --- | --- |
| Observation kind | `coretext`, `directwrite`, `legacy_gdi`, or `browser`; never a generic `native` label. |
| Host | OS product, exact build, architecture, target ABI, locale, and a capture-tool build hash. |
| Framework | Selected API generation plus framework/DLL/browser file version or build revision; loaded component paths and hashes when legally and technically obtainable. |
| Fonts | Font Bundle Fingerprint and manifest digest for supplied resources; exact `(resource_id, face_index)` for every selected bundle face; hashes for every selected non-bundle face; explicit closed/open selection status. |
| Selection | Ordered family request, custom collection/registration identity, fallback/cascade policy, actual face per run or glyph, synthetic-style policy, language, script, direction, features, and variations. |
| Layout | SVG/CSS layout profile, measuring mode, viewport, DPI/device scale, transforms, origin/phase, and rounding policy. |
| Raster | Explicit antialias/rendering mode, hinting choice, grayscale/LCD choice, gamma, contrast, pixel geometry, stem-darkening or equivalent state, and color/bitmap/SVG glyph policy. |
| Output | Context/backend, dimensions, pixel format, alpha convention, color space, background, compositing policy, and captured image hash. |
| Browser-only | Exact executable/revision, platform font backend, command line and feature flags, headless mode, sandbox, offline proof, DPR, user-data/font-access policy, and selected-face evidence. |
| Completeness | Exactly `closed_bundle_oracle` or `ambient_unreproducible`, plus which inputs were verified, merely recorded, or inaccessible; any inaccessible selected font or automatic default requires `ambient_unreproducible`. |

The observation should also retain the authored SVG hash, exact capture tool and
protocol version, stdout/stderr or structured failure, and repeated-capture
agreement. Host paths and timestamps may be diagnostic metadata but must not be
treated as rendering identity unless their contents are independently hashed.

No closed-bundle observational profile should be accepted into a regression
baseline until it passes repeated clean-process captures and one negative control
proving that a changed material input changes identity. An
`ambient_unreproducible` capture is never a regression baseline. Cross-host
agreement is useful evidence, not a reason to erase the host-specific identities.

## Alternatives considered

### Treat each platform API as an ordinary supported renderer profile

Rejected. “Profile” would falsely imply the same closure and evidence depth as a
canonical comparison. Platform APIs can import installed resources and host
policy, and their output does not expose all intermediate svgdiff evidence.

### Declare every platform-native path a permanent non-goal

Rejected as too broad. Real users may need to know why a canonical result differs
from Safari/macOS, a Windows application, or Chromium. A bounded observer provides
independent evidence without weakening canonical semantics.

### Make browser output canonical because browsers are the primary SVG consumer

Rejected. SVG and CSS intentionally permit user-agent and platform choices, and
browser font selection can depend on installed resources and privacy policy. A
browser is an excellent conformance oracle but not one portable font definition.

### Canonicalize Core Text and DirectWrite with bundled fonts and explicit knobs

Rejected for the complete-analysis profile. Supplying exact fonts and explicit
settings removes important ambient inputs, but the OS framework implementation,
shaping/layout behavior, rasterizer, and target remain external. The result can be
a strong closed-font observation, not the cross-target canonical runtime.

### Normalize native pixels until platforms agree

Rejected. Normalization would discard the platform behavior the observer exists
to measure. Compare observations under the existing multidimensional evidence
model and classify disagreements; do not average, threshold, or silently rewrite
them into equality.

## Reconsideration triggers

Revisit this decision only when at least one of these is true:

1. a concrete Agent or user task requires explaining platform-specific text that
   the canonical runtime and existing browser oracle cannot answer;
2. a platform exposes a documented, redistributable or fully identity-pinnable
   font execution stack with caller-supplied bytes, closed fallback, explicit
   shaping/layout/raster inputs, and inspectable intermediate results;
3. a maintained capture protocol proves stable repeated output and selected-face
   identity on a versioned OS image and demonstrates value beyond current
   conformance fixtures; or
4. terminal acceptance is expanded to include exact parity with a named native
   application rather than portable deterministic SVG semantics.

Even then, adding an observer does not automatically admit it as canonical. That
requires a separate ADR, a complete execution identity, hostile-input and resource
limits, layer-preserving evidence, cross-target policy, and an Agent acceptance
case that cannot be answered by the existing deterministic profile.

## Decision consequence

The roadmap choice is neither “platform pixels are canonical” nor “never inspect
platform pixels.” Platform-native font rendering remains outside every canonical
deterministic complete-analysis profile. Core Text, DirectWrite, and browser text
may later be implemented as independently identified external observations;
GDI remains legacy-probe-only. The canonical font path continues to use exact
bundle resources and the project-owned pinned runtime seam, while platform
captures may challenge it as oracles without changing its meaning.

## Primary sources

All sources below were accessed on 2026-07-17.

### W3C

- [CSS Fonts Module Level 4](https://www.w3.org/TR/css-fonts-4/), especially
  generic and system families, `@font-face` `src`, the undefined installed-font
  set, matching, installed fallback, and font taxonomy.
- [SVG 2 text](https://www.w3.org/TR/SVG2/text.html), especially its reliance on
  CSS text/font behavior, complex shaping, SVG text layout, and `@font-face`.
- [SVG 2 painting and rendering hints](https://www.w3.org/TR/SVG/painting.html#RenderingHints),
  especially `text-rendering` as a user-agent optimization hint.

### Apple

- [Core Text overview](https://developer.apple.com/documentation/coretext/),
  including shaping, automatic substitution/cascading, descriptors, collections,
  metrics, and glyph access.
- [`CTFontCreateWithName`](https://developer.apple.com/documentation/coretext/ctfontcreatewithname%28_%3A_%3A_%3A%29?language=objc),
  including best-match and fallback name behavior.
- [`CTFontCreateForString`](https://developer.apple.com/documentation/coretext/1509506-ctfontcreateforstring?language=objc),
  for best-substitute selection from a font's cascade list.
- [`CTFontCopyDefaultCascadeListForLanguages`](https://developer.apple.com/documentation/coretext/ctfontcopydefaultcascadelistforlanguages%28_%3A_%3A%29?language=objc),
  for the language-sensitive ordered fallback list.
- [`CTFontCollectionCreateFromAvailableFonts`](https://developer.apple.com/documentation/coretext/ctfontcollectioncreatefromavailablefonts%28_%3A%29?language=objc),
  for the complete font set visible to the current application.
- [`CTFontManagerCreateFontDescriptorFromData`](https://developer.apple.com/documentation/coretext/ctfontmanagercreatefontdescriptorfromdata%28_%3A%29?language=objc),
  for creating a descriptor from supplied bytes.
- [`CTFontManagerRegisterFontURLs`](https://developer.apple.com/documentation/coretext/3227897-ctfontmanagerregisterfonturls?language=objc),
  for registration visibility and lifetime behavior.
- [`CTFontManagerScope`](https://developer.apple.com/documentation/coretext/ctfontmanagerscope?language=objc),
  for process, session, user, and persistent registration scopes.
- [`CGContext.setShouldAntialias`](https://developer.apple.com/documentation/coregraphics/cgcontext/1455178-setshouldantialias),
  for graphics-context antialiasing state.
- [`CGContextSetShouldSmoothFonts`](https://developer.apple.com/documentation/coregraphics/cgcontext/setshouldsmoothfonts%28_%3A%29?language=objc),
  together with the related font-smoothing, subpixel-positioning, and
  subpixel-quantization graphics-state controls.

### Microsoft

- [DirectWrite custom font sets](https://learn.microsoft.com/en-us/windows/win32/directwrite/custom-font-sets-win10),
  including system collections, custom resources, in-memory loaders, remote fonts,
  and WOFF/WOFF2 handling.
- [DirectWrite custom font collections](https://learn.microsoft.com/en-us/windows/win32/directwrite/custom-font-collections),
  including application-defined collection/file loaders and streams.
- [`DWRITE_RENDERING_MODE`](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/ne-dwrite-dwrite_rendering_mode),
  for automatic, GDI-compatible, natural, symmetric, aliased, and outline modes.
- [`DWRITE_MEASURING_MODE`](https://learn.microsoft.com/en-us/windows/win32/api/dcommon/ne-dcommon-dwrite_measuring_mode),
  for natural and display/GDI-compatible measurement semantics.
- [`IDWriteRenderingParams`](https://learn.microsoft.com/en-us/windows/win32/api/dwrite/nn-dwrite-idwriterenderingparams),
  for gamma, contrast, ClearType level, pixel geometry, and monitor-derived state.
- [`IDWriteFactory1::CreateCustomRenderingParams`](https://learn.microsoft.com/en-us/windows/win32/api/dwrite_1/nf-dwrite_1-idwritefactory1-createcustomrenderingparams),
  for the explicit DirectWrite raster-parameter surface.
- [`CreateFontW`](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-createfontw),
  for GDI logical-to-physical mapping, substitution, quality, synthesis, and
  system smoothing behavior.
- [ClearType antialiasing](https://learn.microsoft.com/en-us/windows/win32/gdi/cleartype-antialiasing),
  for stripe orientation, device restrictions, system settings, and contrast.
- [Font installation and deletion](https://learn.microsoft.com/en-us/windows/win32/gdi/font-installation-and-deletion),
  for GDI's system font table and session/process-visible font resources.

### Selected canonical-runtime contrast

- [HarfBuzz getting started](https://harfbuzz.github.io/getting-started.html),
  for explicit font objects, shaped glyph advances/offsets, selectable shapers,
  and platform integration boundaries.
- [FreeType glyph retrieval](https://freetype.org/freetype2/docs/reference/ft2-glyph_retrieval.html),
  for explicit hinting targets and grayscale, monochrome, and LCD render modes.
- [FreeType driver properties](https://freetype.org/freetype2/docs/reference/ft2-properties.html),
  for interpreter version, stem darkening, environment properties, and other
  raster-affecting configuration that the canonical runtime must pin or disable.

### Browser implementation and capture

- [Blink's text stack](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/third_party/blink/renderer/platform/fonts/README.md),
  for its distinct CSS-to-font, web/system matching, shaping, and iterative
  system-fallback stages.
- [Playwright browser management](https://playwright.dev/docs/browsers), for the
  binding between a Playwright release and specific browser binaries, the headed
  versus headless-shell distinction, OS-dependent capabilities, and hermetic
  browser installation options.
