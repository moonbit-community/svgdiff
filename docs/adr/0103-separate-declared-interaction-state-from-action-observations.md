# ADR 0103: Separate declared interaction state from action observations

- Status: accepted, not implemented
- Date: 2026-07-17
- Decision owners: svgdiff maintainers
- Supersedes: none

## Context

The current selector matcher depends only on indexed XML state and rejects pseudo-classes. Event-driven pseudo-classes instead depend on document URL, focus, input modality, pointing devices, hit testing, activation, ancestry, target behavior, and sometimes user-agent policy. A raw `:hover=true` flag can violate those relationships. Conversely, a browser action sequence describes attempted input, not necessarily the state reached on every target.

Scripts and animation time are already separate axes. An interaction decision must not re-enable them through event dispatch or an implicit wait policy.

## Decision

Preserve the current interaction-free static Comparison Profile. Define future canonical support through a separate `svgdiff-interaction-state-profile/1` that accepts closed URL, focus, modality, pointer, button, geometry, and processing inputs, then derives pseudo-class match sets through a versioned project-owned state and hit-test evaluator. Reject caller-supplied pseudo-class booleans and impossible or unresolved states.

Initially classify `:target`, `:focus`, `:focus-within`, policy-bound `:focus-visible`, `:hover`, and `:active` as candidates. Keep structural pseudo-classes in static selector work, history-sensitive `:visited` permanently outside canonical analysis, and HTML/platform control states deferred or observational.

Use a distinct future `svgdiff-interaction-observation/1` for exact browser action replay. It records ordered actions and achieved-state postconditions; a trace that does not reach the requested state fails reproduction. Target-local observations cannot define canonical state or report authority.

## Consequences

The model can compare a named interaction checkpoint without confusing semantic state with device history. Before/after target mapping, hit-test conformance, and focus policy become explicit prerequisites. Scripts, events, transitions, and animation remain disabled unless independently profiled.

No product profile, selector grammar, field, Schema, dependency, Diagnostic, fixture, CLI mode, CI job, or release asset changes through this decision.

## Rejected alternatives

- Accept arbitrary pseudo-class match booleans: they bypass state invariants, ancestry, hit testing, and reachability.
- Use only pointer coordinates: focus, target fragments, keyboard modality, buttons, and target-dependent hit testing remain unspecified.
- Treat WebDriver actions as canonical state: actions and default events can reach different states on different targets.
- Let the browser decide state inside the current report: it would make canonical selector applicability depend on an external renderer and ambient UI policy.
- Support `:visited` with a caller history list: history styling is privacy-sensitive and browser-constrained, and it is not required for the terminal Agent task.
