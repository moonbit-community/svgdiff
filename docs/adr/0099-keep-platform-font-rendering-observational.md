# ADR 0099: Keep platform font rendering observational

- Status: accepted
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

CoreText, DirectWrite/ClearType, GDI, browsers, and other native stacks can show what users see on a named platform. They also select or substitute fonts and choose shaping, measuring, antialiasing, pixel geometry, gamma, contrast, smoothing, caching, color-glyph, and device behavior through framework, OS, hardware, user, locale, and application state. A platform or OS version is therefore not a complete Font Execution Profile.

The project already keeps Chromium outside the engine as an independent fixture oracle. The accepted Font Bundle and Font Runtime contracts instead close canonical resources and execution behind project-owned identities and evidence layers.

## Decision

Make platform-native font rendering a permanent non-goal for canonical deterministic Font Execution Profiles and complete-analysis evidence. System discovery, generic families, `local()`, automatic substitution/fallback, downloadable fonts, and network font services are permanently forbidden canonical inputs.

Permit future platform or browser captures only as external Platform Font Observations under `svgdiff-platform-font-observation/1`. A capture using an exact closed Font Bundle may become a named-target conformance observation after repeatability and identity gates. A capture using ambient fonts is always `ambient_unreproducible` and may be exploratory only. Neither kind enters canonical equality, magnitude, coverage, Impact, regions, causality, or Structured Report evidence.

Any observed disagreement can affect product behavior only through a separately reviewed conformance disposition that changes a canonical adapter, support boundary, or Diagnostic. The later multi-renderer decision determines how external observations compare; it cannot promote platform font behavior implicitly.

## Consequences

Svgdiff retains a portable inspectable canonical model while still allowing evidence about real platform output. A native capture requires extensive environment and output identity, and unavailable or hidden state remains an explicit limitation. There is no platform backend, new profile option, report field, dependency, or current font support from this decision.

## Rejected alternatives

- Treat an OS/build name as a deterministic profile: it omits framework, rendering, device, user, locale, font, and hidden implementation state.
- Admit system fonts when their family names are recorded: names do not identify exact bytes, faces, matching, substitution, or fallback.
- Make closed-bundle CoreText or DirectWrite canonical: exact resources do not make the platform implementation portable or inspectable.
- Put browser/native pixels directly in Structured Report: an external observation is not canonical evidence and cannot establish causal completeness.
- Select a majority result across platforms: prevalence is not semantic correctness and pooling destroys target identity.
- Reject every native capture: target-specific observations remain useful as independent conformance and user-environment evidence.
