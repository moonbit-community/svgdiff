# Core V1 Scope

Status: accepted in part; unresolved deferred items are marked explicitly

This document records both the initial correctness claim and capabilities deliberately left for later versions. Presentation and HTML interaction are outside this core scope document.

## Correctness claim

Core v1 compares Deterministic Static SVG under a fully declared Comparison Profile. A complete result means the engine analyzed all supported source semantics, computed appearance, and rendered evidence under those conditions; it does not mean the inputs are equivalent under other environments or future interactive states.

## In scope

- two well-formed static SVG artifacts;
- normalized Source Semantics while preserving authored representation distinctions;
- Computed Appearance and visually meaningful Visual Subjects under a fixed viewport, including entities and resources whose Visual Contribution is zero;
- caller-supplied or embedded non-font resources;
- deterministic Render Observations under the Comparison Profile;
- one common Comparison Viewport, supplied explicitly or derived from identical valid intrinsic viewport declarations;
- one common Comparison DPR, defaulting to `1.0` and recorded in the Structured Report;
- transparent-canvas linear premultiplied-RGBA evidence independent of an optional explicitly declared Perceptual Background;
- sRGB SVG and CSS color interpretation with linear-sRGB premultiplied-RGBA raster arithmetic;
- set-to-set Subject Alignments;
- multidimensional Atomic Differences and Visual Events anchored to one Primary Subject Alignment;
- continuous Difference Magnitude measurements and Domain Ordering;
- conservative Influence Provenance and causally complete Cause Envelopes for fully covered regions;
- a complete Structured Report with Diagnostics and declared Analysis Coverage.

## Explicit v1 non-goals

- executing scripts;
- evaluating event-driven or user-interaction state;
- evaluating SMIL, CSS, or script-driven animation timelines;
- rendering static `foreignObject` content through an HTML/CSS layout engine; its Source Semantics remain reportable while Computed Appearance and Rendered Evidence are indeterminate;
- implicitly fetching network resources during comparison;
- relying on unspecified system fonts, locale, background, viewport, color space, or renderer version;
- claiming equality across browsers or across rendering engines;
- treating unsupported features, missing resources, or failed measurements as equality;
- making HTML presentation behavior part of the core comparison contract.
- treating changes to pure Nonvisual Metadata, such as accessibility descriptions or custom data attributes, as visual Atomic Differences.
- inferring or merging Visual Events across different Primary Subject Alignments through spatial clustering, shared resources, hierarchy, theme detection, or other outcome-coherence heuristics.
- producing directly comparable Rendered Evidence from independently chosen per-input viewports.
- silently assuming a white or other Perceptual Background for display-dependent perceptual metrics.
- silently converting embedded ICC profiles, Display-P3, or other wide-gamut content into the v1 sRGB Comparison Color Space.
- claiming complete font resolution, text shaping, font-dependent layout, or glyph raster evidence.

## Required behavior for out-of-scope content

The engine must not silently discard out-of-scope content. It records:

- a Diagnostic identifying the unsupported or unresolved feature;
- the affected Source Elements or regions when known;
- the evidence layers that could and could not be analyzed;
- reduced Analysis Coverage;
- `partial` or `failed` analysis status when the gap can affect conclusions.

An unsupported feature may still have source-level differences. Those differences remain reportable even when computed or rendered measurements are indeterminate.

## Deferred decisions

The following capabilities require separate decisions before they may be classified as v1 work or explicit non-goals:

- exact Contribution Index propagation through filters, masks, transparency, and blending;
- deterministic font loading, fallback selection, shaping, and font fingerprinting;
- platform-native font rendering modes;
- multiple-renderer or cross-browser comparison profiles;
- resource bundles beyond embedded and explicitly supplied assets.
- post-v1 cross-subject Visual Event aggregation and its exact outcome-coherence criteria.

Each deferred capability must eventually be moved into either **In scope** or **Explicit v1 non-goals**. It must not remain implicit during implementation.

## Renderer ownership

Core v1 first evaluates pure-MoonBit community dependencies behind an internal rendering seam. A project-owned renderer is created as a separate workspace-managed MoonBit module only when a concrete acceptance case proves that required correctness or provenance cannot be achieved through the dependency or a focused upstream extension.

## Source Semantics ownership

Core v1 owns strict authored parsing and Source Span provenance in the separate workspace-managed `source_semantics` module. The module rejects incomplete or malformed input rather than repairing it, preserves raw authored values independently of computed SVG normalization, and exposes no renderer-specific types. `moonbit-community/XMLParser@0.2.5` was rejected for this seam because it accepted required well-formedness failures and did not expose element or attribute Source Spans.
