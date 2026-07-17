# SVG Script Runtime Boundary

Status: decision research for ISS-155

Last verified: 2026-07-17

## Question

Should svgdiff execute SVG scripts in a sandboxed deterministic runtime, or
should script execution remain a permanent non-goal?

The recommended answer is: **make script execution a permanent non-goal for
canonical deterministic comparison and complete Structured Report claims**.
Continue to detect script-bearing inputs, retain independently supported static
evidence, and make the affected coverage partial. If a concrete later use case
requires execution, admit only a separately versioned external script
observation for one exact browser, environment, declared event trace, resource
set, and capture checkpoint. Such an observation must not acquire canonical
Source Semantics, equality, Cause Envelope completeness, or Impact authority.

This rejects a product-owned scripted runtime, not every possible observation
of scripted SVG in a browser. It also does not decide event-state, animation
timeline, `foreignObject`, or future resource-acquisition semantics. Those are
separate Phase 10 decisions and prerequisites for any meaningful dynamic
observation.

## Primary-source findings

### SVG already defines a complete script-disabled processing mode

SVG 2 treats script execution, external references, declarative animation, and
interaction as independent high-level processing-mode features. Secure static
mode disables all four. Disabling script means that no `script` element, event
attribute, or script provided by another Web-platform feature runs. Disabling
external references turns every external fetch attempt into a network error;
disabling interaction prevents user input from affecting the document.
[SVG 2 processing modes](https://www.w3.org/TR/SVG/conform.html#processing-modes)

This is stronger than “load the document and wait at time zero.” SVG 2 says
that disabling declarative animation is not equivalent to pausing an animated
document at `0s`: an animation scheduled to begin at `0s` is not applied at
all. Static comparison is therefore a distinct processing contract, not one
sample of a dynamic document.
[SVG 2 feature definitions](https://www.w3.org/TR/SVG/conform.html#processing-modes-features)

### Enabling SVG script means enabling the Web execution model

An SVG event attribute is ECMAScript executed when its event is dispatched.
All SVG elements support event attributes for the events supported by the user
agent. SVG scripts can add or remove DOM event listeners; SVG animation may
also begin or end in response to events. The SVG `script` element is defined as
equivalent to the HTML `script` element, and its functions have document-wide
global scope. External script URLs are fetched through the SVG linking model.
[SVG 2 scripting and interactivity](https://www.w3.org/TR/SVG/interact.html),
[SVG 2 event attributes](https://www.w3.org/TR/SVG/interact.html#EventAttributes),
[SVG 2 `script`](https://www.w3.org/TR/SVG/interact.html#ScriptElement)

Script can mutate reachable DOM, schedule work, dispatch events, and create
resource references, rewriting the graph the analyzer aligns and traces. SVG 2
also says DOM or animation changes can move a dynamic document into and out of
error. A snapshot must therefore identify an exact dynamic state and rendering
checkpoint; successful parsing is insufficient.
[SVG 2 dynamic error processing](https://www.w3.org/TR/SVG/conform.html#ErrorProcessing)

### Browser event-loop completion is not a generic snapshot condition

The HTML event loop coordinates scripts, events, rendering, networking, DOM
reactions, callbacks, and other work. It has multiple task queues, and task
queues are sets rather than FIFO queues because a user agent chooses the first
runnable task from a selected queue. The standard permits user agents to
associate task sources with separate queues and prioritize them differently,
while preserving ordering only within one task source.
[HTML event loops](https://html.spec.whatwg.org/multipage/webappapis.html#event-loops)

Timers, promises and microtasks, resource completion, observers, animation
frames, workers, and repeating callbacks can continually create more work.
Consequently, “wait until scripts finish” is not a well-defined universal
checkpoint. A dynamic profile would need a declared event/action sequence,
virtual-time schedule, microtask and rendering-update rules, resource-completion
policy, and an explicit capture command. It must treat timeout, nontermination,
unbounded DOM growth, and pending work as typed outcomes, never as a stable
empty diff.

WebDriver's input model shows what a reproducible interaction input would need
to resemble: typed input sources are grouped into explicit ticks, and the next
tick begins after the user agent can process DOM events from the current tick.
The specification also warns that default actions may generate additional
implementation-dependent events. A generic `click at (x,y)` label is therefore
not a closed cross-browser event-state identity.
[WebDriver actions and ticks](https://w3c.github.io/webdriver/#actions)

### ECMAScript and Web APIs expose undeclared state even without network I/O

Ordinary script execution can observe values that are not in either SVG:

- `Date.now()` returns the actual UTC time at the occurrence of the call;
- `Math.random()` uses an implementation-defined algorithm or strategy, and
  distinct realms must produce distinct sequences;
- `crypto.getRandomValues()` uses cryptographically strong random bytes and is
  expected to seed from high-quality entropy such as an operating-system
  source;
- local time conversion and locale-sensitive formatting depend on host time
  zone and internationalization data; and
- browser APIs expose storage, permissions, device and media state, workers,
  networking, user-agent settings, and implementation-defined behavior.

[ECMAScript `Date.now`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-date.now),
[ECMAScript `Math.random`](https://tc39.es/ecma262/multipage/numbers-and-dates.html#sec-math.random),
[Web Cryptography `getRandomValues`](https://w3c.github.io/webcrypto/#Crypto-method-getRandomValues)

Freezing wall-clock time and replacing `Math.random` would close only two
inputs. Cryptographic entropy, locale and time-zone data, feature detection,
task scheduling, layout and renderer identity, storage, permissions, resource
responses, and any admitted device API would still need an explicit rule. If a
profile permits arbitrary script while silently replacing or deleting these
APIs, it implements a new language-host subset rather than ordinary browser SVG
scripting.

### Security sandboxing and deterministic execution are different contracts

The HTML sandbox model can set a sandboxed-scripts flag, which blocks script
execution. The `allow-scripts` token removes that flag and also relaxes the
sandboxed-automatic-features flag. Other sandbox flags can still restrict
origin, navigation, forms, popups, modals, downloads, or device-oriented APIs,
but they do not define deterministic values for every remaining script-visible
input.
[HTML sandboxing flags](https://html.spec.whatwg.org/multipage/browsers.html#sandboxing-flag-set)

Chromium describes its process sandbox as a least-privilege security boundary:
it limits access to confidential information and persistent machine changes,
and assumes sandboxed code may be malicious. Renderer processes still execute
Web content and request permitted work through browser services. The sandbox
does not claim to fix task scheduling, time, randomness, resource responses,
DOM state, browser build behavior, or pixels.
[Chromium sandbox design](https://chromium.googlesource.com/chromium/src/+/main/docs/design/sandbox.md),
[Chromium multi-process architecture](https://www.chromium.org/developers/design-documents/multi-process-architecture/)

Therefore “run it in Chromium's sandbox” addresses host compromise risk but not
svgdiff's reproducibility, coverage, attribution, or equality requirements. A
production design would need both an OS/browser security boundary and a closed
semantic execution profile.

### Current browser automation closes useful inputs, but not the whole world

Playwright browser contexts are isolated, non-persistent sessions that do not
write browsing data to disk. Routes can abort requests or replay a declared HAR,
offline mode can be set, permissions can be controlled, and a context clock can
replace `Date`, timers, animation-frame callbacks, idle callbacks,
`performance`, and event timestamps.
[Playwright BrowserContext](https://playwright.dev/docs/api/class-browsercontext),
[Playwright clock](https://playwright.dev/docs/clock)

These are useful building blocks, not a complete deterministic runtime. Routing
and HAR replay miss service-worker-handled requests unless service workers are
blocked; permissions vary by product/version; the clock does not replace
randomness, entropy, all asynchronous sources, or browser scheduling; and
context isolation does not make renderer behavior portable.

[Playwright route and HAR limitations](https://playwright.dev/docs/api/class-browsercontext#browser-context-route),
[Playwright service-worker network limitation](https://playwright.dev/docs/network#missing-network-events-and-service-workers)

The correct conclusion is that a closed observation is technically possible
for a deliberately small, declared scenario. It is not evidence that arbitrary
SVG script can be admitted to canonical complete analysis by adding one
`sandbox = true` option.

## Current project boundary

The current product compares two supplied SVG strings under one deterministic
static Comparison Profile. It performs no implicit network or filesystem I/O,
uses exact caller-supplied resource bundles, and distinguishes `complete`,
`partial`, and `failed` from rendered zero. Dynamic script or animation
references are outside the conservative local-reference graph claim.
[Core model](../core-model.md),
[current v1 scope](../v1-scope.md),
[Resource Outcome Policy](../resource-outcome-policy.md), and
[Local Reference Safety](../reference-safety.md)

Canonical support would require execution provenance through script reads,
branches, tasks, events, mutations, resources, style updates, rendering, and
capture while still enumerating differences and keeping evidence layers
separate. Listing all script bytes as possible causes stays conservative but
does not close runtime inputs and is likely too noisy. Crash, timeout, resource
limit, rejected API, pending work, or incomplete capture can never prove dynamic
equality.

## Options evaluated

### Option A: keep canonical execution script-free

Use a secure-static-style contract. Detect script-bearing constructs, preserve
supported static evidence, emit precise Diagnostics, and make affected layers
partial. This matches an SVG processing mode, preserves no-implicit-I/O and
auditable equality/causality, and leaves the remaining Phase 10 decisions
independent. The cost is explicit: svgdiff cannot claim a post-script browser
state.

### Option B: pin a browser plus a deterministic observation harness

A pinned browser, OS sandbox, isolated state, blocked or bundled network,
controlled clock, explicit actions, limits, and capture checkpoint can be
repeatable for a bounded scenario. It remains external: APIs must each be
closed, engine scheduling and pixels remain target identity, and screenshots do
not supply mutation provenance or canonical completeness. Use only for a named
Agent task that existing evidence cannot answer.

### Option C: embed a standalone ECMAScript interpreter

Reject. Script-compatible SVG needs DOM, events, CSSOM, layout, resources,
tasks, animation, and rendering, not only ECMAScript. A custom subset duplicates
the Web platform without browser-conformance evidence. A future transformation
DSL would not be SVG script execution.

### Option D: execute scripts once, then diff serialized DOM snapshots

Reject as a canonical shortcut. It loses the inputs, branches, events, tasks,
mutations, errors, and resource history that produced the DOM. A snapshot may be
an external-observation artifact, never the execution contract.

## Recommendation

Adopt the following boundary:

1. **Canonical permanent non-goal.** No canonical Comparison Profile executes
   SVG scripts, event attributes, dynamically created script, or script exposed
   through embedded Web content. Scripted visual outcomes cannot contribute to
   complete equality, canonical magnitude, Impact, Difference Regions, or Cause
   Envelope completeness.
2. **Fail closed at coverage.** Encountered script-capable content that could
   affect the compared state must produce a stable Diagnostic and partial
   affected layers. Independently supported static facts remain available.
   Analysis failure is reserved for malformed input, safety/admission failure,
   or inability to produce a usable bounded report, consistent with the current
   status contract.
3. **No implicit execution by dependencies.** Parsers, renderers, browser
   oracles, HTML presentation, and resource decoders must never execute input
   script as a side effect of canonical comparison.
4. **Separate future observation.** A later `svgdiff-script-observation/1`
   artifact may record one closed target execution. It is external evidence and
   may be associated with a Structured Report or future multi-renderer matrix;
   it cannot upgrade that report's authority or coverage.
5. **Ambient execution is unusable for inference.** A capture with ambient
   network, storage, fonts, permissions, devices, clock, entropy, events, or
   unresolved APIs is `ambient_unreproducible`. It may document “this target
   produced these bytes” but cannot be a baseline, equality oracle, or complete
   Agent input.

This is the smallest decision that preserves the terminal goal. The product is
for an Agent that needs reliable visual-semantic differences and possible
causes. It is better to state that an arbitrary dynamic outcome is not computed
than to provide precise-looking pixels whose state, repeatability, or causes are
not closed.

## Required shape of any future external script observation

If reconsidered, the observation must record at least:

- source/resource hashes; observation, harness, browser/build/binary, OS,
  renderer/backend, flags, and sandbox identities;
- origin, CSP, network/service-worker, storage/cache, permissions, and API rules;
- locale/time zone, viewport/DPR, media, fonts, color and capture identities;
- virtual time, timers, animation frames, randomness, entropy, and worker rules;
- typed event/action trace and exact rendering/capture checkpoint;
- hard CPU, time, memory, DOM, task, timer, worker, navigation, and output limits;
- exception, API, request, event, mutation, timeout, crash and pending-work logs;
  and
- repeated-run hashes, disagreement, artifacts, and closure classification.

Before and after must use the same observation profile. A missing required
input, rejected-but-reached API, timeout, crash, nondeterministic repeat, or
incompatible output makes the result unavailable or insufficient evidence; it
must never serialize as measured zero.

## Reconsideration and implementation gates

Do not implement a script observer until all of these gates pass:

1. **Use-case gate:** a concrete Agent task is documented that cannot be
   answered by static Structured Reports plus existing browser observations.
2. **Event gate:** Phase 10 accepts a versioned event-state and WebDriver-style
   action-trace contract, including target resolution and event ordering.
3. **Timeline gate:** Phase 10 accepts the common document-time and capture
   model for SMIL, CSS, and script-driven changes.
4. **Resource gate:** every reachable script, fetch, image, font, stylesheet,
   module, worker, and other external byte is blocked or supplied by a closed
   exact bundle with fixed response semantics.
5. **API-closure gate:** every exposed Web API is classified as deterministic,
   profile-supplied, virtualized, rejected, or fatal-on-use. Unknown APIs fail
   closed.
6. **Security gate:** untrusted execution runs behind an independently reviewed
   OS/browser sandbox, no host credentials or writable project workspace are
   exposed, and all IPC and output are bounded.
7. **Checkpoint gate:** load, event dispatch, virtual-time advancement,
   microtasks, rendering updates, and capture have a versioned finite algorithm;
   pending or repeating work has a typed outcome.
8. **Identity gate:** browser, OS, harness, policy, resources, environment, and
   output contracts have immutable identities distinct from Structured Report
   Schema, canonical renderer, and renderer-conformance IDs.
9. **Repeatability gate:** adversarial fixtures covering time, both random
   sources, locale/time zone, network, service workers, storage, workers,
   exceptions, infinite loops, task races, DOM growth, and dynamic resource
   creation repeat byte-identically on every supported target or are precisely
   classified unavailable.
10. **Authority gate:** Agent and product docs prove that observations cannot
    establish canonical equality, source/computed completeness, minimal causes,
    or browser-majority truth.

Passing these gates would justify a bounded external observation, not removal of
the canonical permanent non-goal. Promoting any dynamic execution into canonical
complete analysis would require a separate decision and runtime provenance model
that satisfies every current completeness and causal obligation.

## Risks of the recommendation

- Some interactive SVG pairs will remain partial even when a human can reproduce
  a visible scripted difference in a browser.
- Source-only script diagnostics can be conservative and noisy because arbitrary
  script may or may not affect the requested visual state.
- External observers added later may tempt consumers to treat a repeatable pixel
  capture as canonical evidence; the separate schema and authority rules must be
  enforced mechanically.
- Browser and Web API evolution can invalidate an observation allowlist or turn
  a previously rejected path into a new reachable dependency. Observation
  profiles therefore need explicit versioning and upgrade review.

These risks are visible and bounded. Executing arbitrary script in the canonical
pipeline would instead hide open state beneath a `complete`-looking report and
would weaken the product's central guarantees.

## Source register

All external sources below are primary specifications, first-party browser or
automation documentation, and were accessed on 2026-07-17.

| Source | Decision-relevant evidence |
| --- | --- |
| [SVG 2 conformance and processing modes](https://www.w3.org/TR/SVG/conform.html) | Secure static mode, script/external/animation/interaction feature separation, dynamic error states, sub-resource restrictions. |
| [SVG 2 scripting and interactivity](https://www.w3.org/TR/SVG/interact.html) | Event attributes, DOM listeners, script element, external scripts, script-driven DOM mutation. |
| [HTML event loops](https://html.spec.whatwg.org/multipage/webappapis.html#event-loops) | Multiple task sources and queues, user-agent scheduling latitude, rendering/network/DOM coordination. |
| [HTML sandboxing flags](https://html.spec.whatwg.org/multipage/browsers.html#sandboxing-flag-set) | Script blocking versus `allow-scripts`, origin and capability restrictions. |
| [ECMAScript numbers and dates](https://tc39.es/ecma262/multipage/numbers-and-dates.html) | Real-time `Date.now`, implementation-defined `Math.random`, host time-zone and locale dependencies. |
| [Web Cryptography](https://w3c.github.io/webcrypto/) | OS/high-quality entropy expectation for `getRandomValues`. |
| [WebDriver actions](https://w3c.github.io/webdriver/#actions) | Typed action ticks and implementation-specific additional event behavior. |
| [Chromium sandbox design](https://chromium.googlesource.com/chromium/src/+/main/docs/design/sandbox.md) | Least-privilege security goal and broker/target architecture, not deterministic semantics. |
| [Playwright BrowserContext](https://playwright.dev/docs/api/class-browsercontext) | Isolated contexts, routing/HAR, service-worker limits, permissions, offline mode. |
| [Playwright clock](https://playwright.dev/docs/clock) | Explicitly listed virtualized time-related APIs and ordering constraints. |
