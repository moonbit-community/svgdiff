# Keep the browser oracle outside the engine

Chromium rendering will be an independent conformance oracle under `evaluation/browser-oracle`, not a production dependency or a new canonical evidence layer in the Structured Report.

The oracle records an explicit DPR, viewport, transparent background, browser user agent, Playwright CLI version, source hash, and PNG hash. It runs offline on fixed deterministic fixtures. Keeping this adapter outside the engine preserves a small production interface and lets renderer-conformance policy evolve without changing comparison semantics. Browser observations may justify an adapter fix, narrower completeness claim, or stable Diagnostic only through a separately reviewed conformance item.
