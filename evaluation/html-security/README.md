# Hostile-Source HTML Isolation

Status: production security gate

Last verified: 2026-07-16

The self-contained HTML report renders original SVG source only inside two `srcdoc` iframes with an empty `sandbox` token set. Each preview starts with a fixed `default-src 'none'` Content Security Policy. The top-level report escapes both `srcdoc` attributes and the embedded Structured Report JSON before parsing the JSON with its one fixed presentation script.

The fixed fixtures combine element-boundary text, quotes, ampersands, inline scripts, event handlers, stylesheet imports, and external image references. The gate first parses the generated artifact and checks the exact sandbox, CSP, escaping, and JSON round-trip invariants. It then loads the report in the same pinned offline Chromium environment used by the renderer oracle and verifies that:

- neither preview script nor event handler executes;
- neither preview can mutate the parent report;
- no request is produced for either hostile external URL;
- the report's fixed presentation script still parses the exact embedded JSON.

The same pinned browser gate also exercises the evidence inspector against normal, tied, incomparable, partial, empty, and failed reports. It verifies exact diff inventory counts, explicit Impact-state wording, hover and persistent region overlays on both previews, independent review checkboxes, keyboard selection, accessible control names, and expansion of magnitude, event, region, Changed Fact, conservative possible-cause, and Diagnostic evidence. These checks validate presentation only; the Structured Report remains authoritative.

Run:

```sh
sh scripts/test-html-security.sh
```

This gate proves browser isolation for the generated artifact and fixed hostile classes. It does not impose input, memory, output, or execution-time budgets; those remain separate resource-limit work.
