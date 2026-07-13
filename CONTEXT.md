# SVG Difference Analysis

This context describes differences between two SVG documents in terms that support both exhaustive reporting and prioritization by visual impact.

## Language

**Difference**:
A reported semantic distinction between the two SVG inputs after formatting has been normalized. A Difference may have no visual effect, a subtle visual effect, or a salient visual effect.
_Avoid_: Visual Difference when referring to the general concept

**Formatting Variation**:
A lexical distinction, such as whitespace, attribute order, or equivalent tag-closing syntax, that does not change the parsed SVG meaning. Formatting Variations are normalized and are not Differences.
_Avoid_: Formatting Difference, Cosmetic Difference

**Difference Domain**:
The visual semantic area in which an Atomic Difference occurs: presence, geometry, paint, text, compositing, resource, or document. It answers what changed without encoding equivalence, magnitude, or impact.
_Avoid_: Difference Kind, Severity Class

**Computed Relation**:
The relation between the before and after Computed Appearance facts of an Atomic Difference: equivalent, different, indeterminate, or not applicable because one side has no comparable fact. The relation includes an explicit reason rather than presenting an unexplained status.
_Avoid_: Representation Difference, Visibility Status

**Subtle Visual Difference**:
A Difference that changes the rendered appearance by a small perceptual amount, such as a very small coordinate or opacity change.
_Avoid_: Floating-point Difference, Minor Difference

**Salient Visual Difference**:
A Difference that is readily perceptible or materially changes the composition, identity, or emphasis of the rendered scene.
_Avoid_: Obvious Difference, Major Difference

**Difference Magnitude**:
A vector of domain-appropriate measurements describing the size of a Difference in parameter, geometry, coverage, raster, and perceptual terms under one Comparison Profile. It is evidence rather than a universal scalar or policy judgment.
_Avoid_: Severity, Difference Score

**Presence Magnitude**:
The numerical footprint of inserted or deleted content, including affected entity count, geometric extent, painted coverage, viewport fraction, and Rendered Evidence. It is not an existence boolean or a fixed insertion/deletion score.
_Avoid_: Presence Flag, Added Score, Removed Score

**Impact Assessment**:
A profile-dependent, optional interpretation of Difference Magnitude that may add ordering values or human-facing labels. It never replaces continuous measurements, determines whether a Difference exists, or turns rendered evidence into a visibility boolean.
_Avoid_: Severity, Similarity Score

**Domain Ordering**:
A versioned lexicographic ordering of Differences in the same Domain using the measurements most meaningful for that Domain. It does not make values from unrelated Domains numerically interchangeable.
_Avoid_: Kind Ordering, Universal Score, Global Severity

**Atomic Difference**:
The smallest independently reportable semantic distinction between the SVG inputs, such as a changed paint value, coordinate, or element relationship.
_Avoid_: Raw Difference, Property Diff

**Visual Event**:
A coherent, human-understandable change formed by grouping related Atomic Differences into a layered explanation around one visual outcome, such as an icon group moving or a button changing emphasis. Its boundary follows outcome coherence rather than shared cause alone; it preserves each Difference's layer-specific evidence and never obtains a magnitude by adding measurements across layers or child differences.
_Avoid_: Diff Group, Change Bundle

**Event Rendered Outcome**:
The union of the rendered Difference Regions associated with one Visual Event under the Comparison Profile. Its continuous rendered measurements are computed once over that union, independently of how many Atomic Differences explain the Event.
_Avoid_: Event Score, Summed Impact

**Report Summary**:
A prioritized account of the most visually important Visual Events. It is a navigational view over the complete report, not a replacement for less important events or their Atomic Differences.
_Avoid_: Diff Output, Executive Summary

**Structured Report**:
The complete machine-readable record of all Visual Events, Atomic Differences, classifications, measurements, and relationships produced by one comparison.
_Avoid_: JSON Output, Raw Report

**Diff Report**:
A self-contained HTML artifact that presents the Structured Report through classified difference controls and a direct comparison of both SVGs, while also exposing the complete embedded Structured Report.
_Avoid_: Results Page, HTML Output

**Comparison View**:
The paired rendering of the two original SVG inputs in a Diff Report. It preserves both inputs as separate visual references rather than synthesizing a mixed SVG.
_Avoid_: Preview, Before-and-After Image

**Difference Overlay**:
A transient visual annotation on the Comparison View that localizes the Visual Event currently under inspection, using an outline, mask, or another suitable spatial cue.
_Avoid_: Diff Image, Selection Box

## Comparison Model

**Comparison Profile**:
The declared Comparison Viewport, Comparison DPR, optional Perceptual Background, color space, font and resource environment, and renderer identity under which one comparison is evaluated. It defines the rendering conditions for the canonical Structured Report rather than a family of diagnostic magnifications.
_Avoid_: Probe Configuration, Test Matrix

**Comparison DPR**:
The one device pixel ratio used to rasterize both inputs under a Comparison Profile. It defaults to `1.0` when omitted and describes the canonical raster response rather than a probe for discovering small computed differences.
_Avoid_: Probe Scale, Supersampling Factor

**Comparison Viewport**:
The one viewport used to evaluate and render both SVG inputs. It is either supplied explicitly or derived from identical valid intrinsic viewport declarations; the two inputs never use independent viewports for directly comparable Rendered Evidence.
_Avoid_: Per-Input Viewport, Render Size Guess

**Perceptual Background**:
The explicitly declared background over which transparent rendered results are composited for display-dependent perceptual measurements. Its absence does not prevent transparent-canvas premultiplied-RGBA, geometry, coverage, or alpha measurements.
_Avoid_: Default White, Canvas Color

**Comparison Color Space**:
The declared color interpretation and numeric representation shared by both inputs. Core v1 defaults SVG and CSS color interpretation to sRGB and computes raster measurements in linear-sRGB premultiplied RGBA.
_Avoid_: Display Color Space, Unspecified RGB

**Source Element**:
An element in an input SVG document together with its source attributes, hierarchy, and style provenance. Source Elements provide evidence but do not define identity across inputs.
_Avoid_: Object, Visual Element

**Source Span**:
A half-open interval in the original SVG source that localizes an authored element, attribute, value, or text fragment. Source Spans provide provenance and diagnostics but never define visual identity across inputs.
_Avoid_: Line Number, Node Identity

**Visual Subject**:
Any reportable subject with visual semantics, either a placed Visual Entity or a definitional Visual Resource. Identity follows visual role and correspondence rather than SVG element type, identifier, source position, or current pixel contribution.
_Avoid_: DOM Node, SVG Object

**Visual Entity**:
A Visual Subject with scene placement, geometry, or an instantiated visual role. It may contribute zero under the Comparison Profile and may be represented by different Source Elements in the two inputs.
_Avoid_: Rendered Object, Visible Element

**Visual Resource**:
A Visual Subject that defines or supplies appearance without being a placed scene entity, such as a gradient, filter, clip path, mask, symbol, image asset, or font. Its contribution may be mediated through one or more Visual Entities or remain zero when unreferenced.
_Avoid_: Hidden Entity, Defs Node

**Visual Contribution**:
The continuous direct or mediated coverage, color, raster, and perceptual contribution of a Visual Subject under the Comparison Profile. It may legitimately be zero and is not a membership or visibility flag.
_Avoid_: Visible, Is Rendered, Contribution Boolean

**Nonvisual Metadata**:
Source content without visual semantics under the Comparison Profile, such as accessibility descriptions or custom data attributes. It may be preserved as input provenance but does not become a Visual Subject or Atomic Difference.
_Avoid_: Hidden Visual Entity, Zero-Impact Difference

**Subject Alignment**:
A set-to-set relationship between Visual Subjects from the two inputs that represents insertion, deletion, correspondence, splitting, merging, or reorganization of the same visual content, resource, or role. Source structure and identifiers may support a Subject Alignment but are not authoritative.
_Avoid_: Entity Alignment, Correspondence, Node Match, ID Match

**Primary Subject Alignment**:
The Subject Alignment that anchors a Visual Event's main outcome and localization. Atomic Differences attached to other alignments may still be referenced as contextual evidence.
_Avoid_: Event Owner, Root Entity

**Source Semantics**:
The meaning expressed by an SVG document after Formatting Variations have been normalized but before visual properties are fully resolved. Source Semantics preserve distinctions in how equivalent visual content is authored.
_Avoid_: Text Layer, XML Diff

**Computed Appearance**:
The resolved geometry, paint, typography, visibility, compositing, and relationships of visual content after SVG semantics such as inheritance, references, and transforms have been applied.
_Avoid_: Normalized SVG, Computed Style

**Rendered Evidence**:
Continuous color, coverage, raster, and, when a Perceptual Background is declared, perceptual measurements produced from a Computed Appearance under the Comparison Profile. A legitimate zero measurement does not erase a Difference established by Source Semantics or Computed Appearance.
_Avoid_: Pixel Diff, Screenshot Diff

**Render Observation**:
A rendering-derived observation containing final color, coverage, perceptual, and provenance information under the Comparison Profile. It supplies direct numeric evidence without replacing the Computed Appearance needed to explain the Difference.
_Avoid_: Screenshot, Rasterized SVG

**Contribution Index**:
The relationship from sampled rendered regions back to the Visual Subjects that contributed directly or through dependency paths, including cases where resources, transparency, filtering, or compositing give one region multiple contributors.
_Avoid_: Element ID Buffer, Hit Map

**Deterministic Static SVG**:
SVG content evaluated without scripts, events, animation, or unresolved environmental state under a declared viewport, resource set, font set, background, color space, and renderer version.
_Avoid_: Plain SVG, Static File

**Analysis Coverage**:
The portion of an input for which the engine could establish Source Semantics, Computed Appearance, and Rendered Evidence under the Comparison Profile. Coverage gaps are reported explicitly and never interpreted as equality.
_Avoid_: Support Status, Confidence

**Changed Fact**:
An authored value, structural relationship, resource, or declared environmental input whose semantic value differs between the two comparison artifacts. Changed Facts are the root candidates for explaining a Difference.
_Avoid_: Changed Line, Attribute Diff

**Influence Provenance**:
A conservative may-depend relationship that associates computed or rendered regions with every Changed Fact that could influence them. It may contain false positives but must not remove a possible influence without a sound independence rule.
_Avoid_: Contribution Index, Dependency Trace

**Cause Envelope**:
The set of Changed Facts obtained by intersecting a Difference Region's Influence Provenance from both inputs with all Changed Facts in the comparison. When causal coverage is complete, the Cause Envelope contains every actual cause but may contain additional candidates.
_Avoid_: Root Cause, Cause Guess

**Causal Completeness**:
The conditional guarantee that every actual cause of a Difference Region is contained in its Cause Envelope. It may be claimed only when Changed Fact enumeration, evaluation dependencies, and conservative propagation are complete for every relevant operation.
_Avoid_: Attribution Confidence, Exact Causality
