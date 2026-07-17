# Deterministic Color-Management Profiles Beyond sRGB

Status: decision research; only the current v1 sRGB profile is implemented

Last verified: 2026-07-17

## Question and conclusion

Which color-management modes beyond v1 sRGB can support canonical svgdiff
equality and magnitude, and which must remain experiments or observations?

The answer is staged:

| Family | Classification |
| --- | --- |
| Current fixed sRGB | Implemented canonical baseline; unchanged. |
| CSS Color 4 predefined SDR spaces | First future canonical candidate after a complete output, float-pipeline, conformance, and schema decision. |
| Full-range RGB PNG `cICP` naming the same admitted SDR mathematics | Candidate within that future CSS SDR profile after exact precedence, decoder, depth, and range gates. |
| Exact bundled ICC v4 RGB matrix/TRC input | Deferred canonical candidate under one pinned transform implementation, media-relative colorimetric intent, and black-point compensation off. |
| Arbitrary ICC/custom profiles and non-RGB input | Deferred experiment. |
| PQ/HLG HDR reference space | Deferred experiment. |
| Browser, OS, CMM, or physical-display output | External observation only. |
| Ambient platform color management or direct equality across profiles | Permanent non-goal. |

[ADR 0024](../adr/0024-use-srgb-semantics-and-linear-srgb-raster-math.md)
fixes current source interpretation to sRGB and raster math to linear-sRGB
premultiplied RGBA. The [Core Comparison Model](../core-model.md) and [v1
scope](../v1-scope.md) keep wide-gamut, ICC, HDR, and high-bit-depth input behind
precise Diagnostics. [ISS-144](../../issues/ISS-144.md) implemented detection,
not conversion. None of that behavior changes through this research decision.

The accepted current contract is [Color-Management Profile
Boundary](../color-management-profiles.md). This note preserves the primary
evidence and implementation alternatives behind it.

## CSS predefined SDR spaces are the narrowest closed extension

[CSS Color 4 section
10](https://www.w3.org/TR/css-color-4/#predefined) defines the primaries, white
points, transfer functions, conversions, component ranges, and sample code for
`srgb`, `srgb-linear`, `display-p3`, `display-p3-linear`, `a98-rgb`,
`prophoto-rgb`, `rec2020`, `xyz-d50`, and `xyz-d65`, with Lab/LCH and
Oklab/OkLCh conversions. These are mathematical encodings, not host profile
lookups, so project-owned scalar formulas can close them without a monitor,
installed profile, network resource, or platform CMM.

Two common labels must not import platform assumptions:

- CSS [`display-p3`](https://www.w3.org/TR/css-color-4/#predefined-display-p3)
  is an SDR D65 space with P3 primaries and the sRGB transfer function. It does
  not mean “use this Mac display.”
- CSS [`rec2020`](https://www.w3.org/TR/css-color-4/#predefined-rec2020) is the
  predefined SDR BT.2020 encoding. BT.2020 primaries do not imply PQ or HLG;
  those belong to BT.2100 and the separate HDR family.

CSS permits valid extended-range colors outside a destination gamut. A canonical
engine must therefore preserve finite negative and greater-than-one components
through conversion, interpolation, and compositing. RGBA8 clipping or a display
gamut map is a projection, not the equality oracle.

A later concrete profile must select one reference output. Unbounded D65 XYZ
`f64` is the research recommendation because it is linear-light and has no RGB
device-gamut boundary. [CSS Color HDR compositing](https://www.w3.org/TR/css-color-hdr-1/#compositing)
likewise recommends CIE XYZ, or an unbounded linear RGB space with equivalent
results, while retaining out-of-gamut values until final device transfer. This
recommendation is not selected product behavior; it needs a separate executable
decision and conformance corpus.

### Interpolation is independent profile evidence

Color-space admission does not determine interpolation. [CSS Color 4 section
13.1](https://www.w3.org/TR/css-color-4/#interpolation-space) distinguishes
encoded and linear RGB, rectangular perceptual spaces, polar spaces, and hue
paths. [Section
13.3](https://www.w3.org/TR/css-color-4/#interpolation-alpha) requires alpha
premultiplication during interpolation, except that polar hue is not
premultiplied. Missing and powerless components have separate carry-forward
rules.

Every admitted operation must therefore identify its interpolation space,
encoded-versus-linear behavior, missing-component rules, polar hue direction,
alpha order, and clipping point. CSS Color 5 `color-mix()` and custom profiles
add further rules and remain later gates; see [CSS Color 5 sections
3](https://www.w3.org/TR/css-color-5/#color-mix) and
[9](https://www.w3.org/TR/css-color-5/#interpolation).

SVG also retains its own boundary. SVG 2
[`color-interpolation`](https://www.w3.org/TR/SVG/painting.html#ColorInterpolationProperty)
has `auto`, `sRGB`, and `linearRGB`, initially `sRGB`, and controls gradient
interpolation plus graphics compositing/blending; filters have a separate
property. `auto` explicitly permits a user-agent choice. Canonical execution
must resolve it through a named profile or diagnose it, never inherit a browser
default. Parser-only Display P3 support cannot lift complete analysis while a
downstream gradient, mask, filter, blend, image, or metric remains sRGB-only.

## Alpha and compositing

[PNG Third Edition section
4.3](https://www.w3.org/TR/png-3/#4Concepts.ColorSpaces) states that gamma does
not apply to alpha: alpha is a full-range linear fraction of opacity. The same
separation must hold across CSS, ICC, and HDR execution.

- Transform straight/unassociated color components, never premultiplied RGB.
- For nonzero alpha, unpremultiply before color conversion and premultiply in
  the profile's declared encoded or linear operation representation afterward.
- Preserve authored/computed latent color at zero alpha; rendered premultiplied
  output is transparent black, so a real source difference can have zero raster
  error.
- Follow the operation-specific premultiplied interpolation rules rather than
  storing gamma-encoded premultiplied display bytes.
- Preserve extended-range values through the declared source-over composition;
  the profile must state encoded-versus-linear behavior, and clipping before
  alpha multiplication changes translucent edges.
- Keep transparent-canvas raw evidence separate from the explicit Perceptual
  Background. A wide-gamut profile cannot guess a display background.

## ICC identity and behavior

ICC is a transform architecture, not one algorithm. [ICC.1:2022
v4.4](https://www.color.org/specifications/ICC.1-2022-05.pdf) defines profile
classes, a D50 Profile Connection Space, tag-based transforms, profile versions,
and four rendering intents.

Exact profile bytes are input identity. The ICC Profile ID is an optional MD5
computed with several header fields zeroed and can legally be all zero; it cannot
replace a project SHA-256 over supplied bytes. Similar profile names, nominal
spaces, primaries, or Profile IDs do not prove identical transforms.

Rendering intent is also insufficient alone. ICC.1 permits application-selected
intent, stores intent-specific AToB/BToA transforms, and states that perceptual
and saturation color rendering are vendor-specific. A standard perceptual
algorithm is deliberately not required. Deterministic execution therefore needs
exact source and destination resources, active transform path, actual intent,
CMM/build identity, and fixed flags.

The first credible ICC slice is deliberately narrow:

- ICC v4 RGB input/display/color-space profiles with bounded monotonic
  matrix/parametric-or-table TRCs;
- exact bundle bytes and hashes; no path, network, installed name, or display
  lookup;
- parsed version, class, data space, PCS, Profile ID, tag inventory, and active
  transform evidence;
- media-relative colorimetric input-to-reference conversion, black-point
  compensation off, and failure when that path is absent;
- one exact project reference destination or project-owned PCS conversion;
- fixed unbounded float formats, implementation/build/target identity, and
  strict byte, table, operation, memory, and time limits; and
- rejection of grayscale, ICC v2, CLUT/MPE, DeviceLink, Abstract, named-color,
  CMYK, n-channel, iccMAX/ICC.2, malformed, or unsupported profiles.

Arbitrary LUTs and perceptual intent can reproduce one exact pinned execution,
but their parser, interpolation, security, and cross-target surface is much
larger. CSS Color 5
[`@color-profile`](https://www.w3.org/TR/css-color-5/#at-profile) additionally
fetches ICC data by URL and permits broader classes. Any future svgdiff support
must instead use exact locator matching in the existing explicit resource bundle;
implicit fetching remains outside comparison.

## Embedded PNG and JPEG identity

Container bytes, decoded samples, active color metadata, profile bytes, and
converted pixels are separate evidence.

PNG permits `cICP`, `iCCP`, `sRGB`, or paired `cHRM`/`gAMA`. Its normative
precedence is `cICP`, `iCCP`, `sRGB`, then `cHRM`/`gAMA`; see [PNG section
4.3](https://www.w3.org/TR/png-3/#4Concepts.ColorSpaces) and
[`iCCP`](https://www.w3.org/TR/png-3/#11iCCP). A future record must retain every
encountered chunk plus the active interpretation:

- encoded and decoded-sample hashes;
- exact chunk order, validity, bytes or bounded hashes;
- decompressed ICC SHA-256 rather than the arbitrary `iCCP` profile name;
- all four `cICP` code points, including full/narrow range;
- `sRGB` intent and exact `cHRM`/`gAMA` integers;
- sample depth/type, alpha, decoder identity, and converted-pixel hash.

Only full-range RGB `cICP` values exactly naming mathematics admitted by the
selected CSS SDR profile are candidates for its first slice. Arbitrary
`gAMA`/`cHRM`, ICC, narrow-range, unknown/private, and HDR tuples remain deferred.

PNG [`mDCV` and `cLLI`](https://www.w3.org/TR/png-3/#11mDCV) describe mastering
and content-light metadata that may optimize target tone mapping; the spec calls
the optimization subjective. Metadata cannot determine canonical HDR display
pixels without a pinned target and tone-map policy.

Baseline JPEG splits ICC bytes across APP2 `ICC_PROFILE` segments with one-based
sequence and total counts. The official [ICC embedding technical
note](https://www.color.org/technotes/ICC-Technote-ProfileEmbedding.pdf) defines
reconstruction. Reject missing, duplicate, inconsistent, and out-of-range chunks
rather than concatenating in file order. Retain segment positions/counts/hashes,
the reconstructed profile hash, encoded/sample hashes, precision, components,
sampling, decoder/upsampling identity, and converted-pixel hash. Matching ICC
bytes do not prove matching pixels when JPEG decoding differs.

Metadata-only changes can be source/resource differences with equal converted
pixels. Identical sample values under different active profiles can produce a
real computed/rendered difference. One content hash must not collapse them.

## HDR ambiguity

[ITU-R BT.2100](https://www.itu.int/rec/R-REC-BT.2100) defines materially
different PQ and HLG systems. [CSS Color HDR section
8](https://www.w3.org/TR/css-color-hdr-1/#predefined) exposes `rec2100-pq`,
`rec2100-hlg`, and `rec2100-linear` separately and specifies 203 cd/m² HDR
Reference White in its model.

PQ is display-referred and absolute-luminance encoded up to 10,000 cd/m². HLG is
relative and includes display/viewing adaptation. Neither is ordinary Rec.2020
SDR. Correct reference decoding still does not determine target pixels: peak and
black luminance, ambient flare, gamut, headroom, reference-white placement,
surround, user brightness, and tone/gamut mapping all affect output.

A bounded HDR reference experiment must separately fix PQ, HLG, or linear
BT.2100; primaries/white point; signal range and precision; scene/display state;
reference white and luminance limits; HLG system gamma/viewing input; metadata
precedence; mixed SDR/HDR compositing; unbounded linear-light reference output;
and any metric. It answers whether reference signals differ, not whether two
physical displays look alike.

A target-display profile additionally needs destination profile, peak/black,
headroom, viewing conditions, tone/gamut map, quantization, dithering, and
implementation identity. Until a concrete use case closes them, it remains an
external observation. Adaptive
[`hdr-color()`](https://www.w3.org/TR/css-color-hdr-1/#funcdef-hdr-color) is also
deferred because its result depends on current headroom.

## Conversion implementation options

### Project-owned predefined-space math

For CSS predefined SDR, a small scalar `f64` module should implement the exact
W3C transfer functions, matrices, chromatic adaptation, Lab/Oklab conversions,
interpolation, and reference conversion. Pin constants, evaluation order,
exception handling, and rounding. Use W3C and independent vectors, but make one
checked-in corpus authoritative for the profile revision.

Avoid fast-math, target-varying fused operations, locale, long-double drift,
architecture-specific SIMD, unordered iteration, and implicit integer
quantization. Require byte-exact repeated and cross-target results; otherwise
target/numeric-backend identity remains part of the profile.

### Little CMS

[Little CMS 2.18](https://www.littlecms.com/LittleCMS2.18%20API.pdf) is a mature
MIT-licensed CMM candidate with in-memory profiles, explicit formats/intents,
float transforms, contexts, and flags. It is the practical first ICC experiment,
not deterministic by name alone: its API exposes optimization/cache flags,
black-point compensation, proofing, gamut checks, plug-ins, CLUT choices, and
intent fallback.

A wrapper must pin exact source/build, use an isolated no-plug-in context and
memory-only loading, preflight the required intent, fix formats and every flag,
reject fallback, bound work, and expose only project records. Compare the initial
matrix/TRC slice against project PCS math. A library update creates a new
execution identity.

### skcms

[skcms](https://skia.googlesource.com/skcms/) is a compact BSD-licensed
alternative with explicit profiles, pixel/alpha formats, float transforms, and
ICC/PQ/HLG paths. It is useful as an independent oracle or possible bounded
backend. Its architecture-specific scalar/SIMD paths and single-precision
representation require a dedicated supported-target experiment; source
inspection does not prove byte-identical output or the needed ICC/intent subset.

Platform ColorSync, Windows Color System, browser screenshots, GPU display
pipelines, installed profiles, and synthetic ICC conversion of every CSS space
are rejected canonical shortcuts.

## External observations

Browser and platform pixels are useful conformance evidence, not canonical
Structured Report evidence. An exact observation must identify source/resource
hashes; executable/build/flags/backend; OS, architecture, CMM, GPU/driver;
embedded and destination profile bytes; decoder; viewport/DPR; surface format,
depth, alpha, and readback; HDR transfer, reference white, headroom, brightness,
viewing state, metadata, and mapping; output encoding, quantization, dithering,
background, and repeatability.

If target profile, mapping, or system CMM cannot be proved, classify the capture
as `ambient_unreproducible`. Observation pixels never directly alter canonical
equality, coverage, Diagnostics, magnitude, regions, Impact, or Cause Envelopes.
They may become versioned fixtures or motivate a separately reviewed guard.

## Alternatives and reconsideration

| Alternative | Disposition |
| --- | --- |
| Expand current sRGB in place | Reject; it changes old report meaning. |
| Convert immediately to bounded sRGB8 | Reject; it clips gamut/HDR and changes interpolation, alpha edges, and magnitude. |
| Use Display P3 or linear Rec.2020 as universal output | Reject; each remains an RGB gamut and cannot contain every valid extended value. |
| Use a generic `wide_gamut`, `icc`, or `hdr` flag | Reject; it omits conversion, interpolation, output, and viewing identity. |
| Use ambient host/display color management | Permanent canonical non-goal. |
| Accept CSS Color 4 predefined SDR | First future candidate after complete gates. |
| Accept bundled ICC v4 RGB matrix/TRC | Deferred conditional candidate. |
| Accept ICC v2, arbitrary LUT/MPE, CMYK/n-channel, DeviceLink, or iccMAX | Deferred experiment; no current need justifies the surface. |
| Canonical PQ/HLG reference comparison | Deferred experiment with explicit luminance/viewing semantics. |
| Universal HDR display equality | Permanent non-goal. |
| Browser/platform screenshot | External observation only. |

Reconsider when representative inputs justify the work; a scalar CSS prototype
passes official, independent, extended-range, alpha, and cross-target vectors; a
bounded ICC prototype proves hostile-input safety and non-fallback; or a named
HDR use case states reference-versus-target intent and every luminance, viewing,
mapping, and output input. A material stable-spec change also requires a new
profile revision rather than silently changing old meaning.

## Acceptance gates

1. Immutable color-execution identity independent of schema and renderer IDs.
2. Strict syntax/metadata parsing with provenance and invalid/boundary coverage.
3. Official and independent conversion vectors, including transfer breakpoints,
   extended range, D50/D65 adaptation, and round trips.
4. Zero/tiny/partial/full-alpha and conversion/premultiplication-order tests.
5. Every downstream paint/effect/metric either executes the profile or emits a
   precise limiting Diagnostic.
6. Strict PNG precedence and JPEG ICC reconstruction with separate container,
   sample, profile, decoder, and converted-pixel evidence.
7. Repeated, optimization-level, clean-process, and supported-target exactness.
8. Bounded parsing/transforms, fuzzing, and native sanitizer evidence.
9. Independent browser/CMM observations with every divergence classified.
10. Negative controls proving no installed profile, display, CMM default,
    network, GPU transform, brightness, or headroom enters canonical execution.
11. Agent-visible separation of source-different, computed-equivalent,
    rendered-equivalent, profile-only, and out-of-gamut cases.
12. Compatibility evidence preserving current sRGB meaning and Diagnostics.

## Decision consequence

The first future canonical candidate is closed CSS Color 4 predefined SDR
mathematics under one fully instantiated `svgdiff-color-execution-profile/1`.
Exact full-range RGB PNG `cICP` may join when it names the same mathematics.
Bundled ICC v4 RGB matrix/TRC follows only after a pinned transform passes its
gates. HDR reference comparison remains experimental; actual display/browser
output remains observational. Ambient color management and direct cross-profile
equality remain permanent non-goals.
