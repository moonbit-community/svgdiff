# Color Profile Decision Evidence

Status: accepted architecture; no beyond-sRGB profile

Last verified: 2026-07-17

[`decision.v1.json`](decision.v1.json) makes the [color-management profile boundary](../../docs/color-management-profiles.md) machine-checkable. It preserves current sRGB behavior, identifies the first future predefined-SDR candidate, stages ICC and HDR work separately, and permanently rejects ambient platform color management and implicit cross-profile equality.

The artifact contains no converted colors, production profile, dependency selection, or report change. Run its dependency-free validator with:

```sh
sh scripts/test-color-profile-decision.sh
```
