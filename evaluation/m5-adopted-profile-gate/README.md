# M5 Adopted-profile Environment Gate

Status: accepted milestone evidence

Gate identity: `svgdiff-m5-adopted-profile-gate/1`

Last verified: 2026-07-17

This gate validates the universal M5 requirement for platform-native fonts, beyond-sRGB color, multi-renderer comparison, scripts, interaction, animation, and `foreignObject` layout. The current adopted set is explicitly empty.

## Exact claim

- The seven advanced families are cross-checked against their accepted machine decision artifacts and the M5 non-goal manifest.
- Every family already has reserved future identity formats and machine-readable environment/input requirement groups.
- A reserved format is not an adopted profile instance. Adoption additionally requires matching product implementation evidence, an exact profile identity/version/manifest digest, and an environment identity with implementation builds, resources, and limits pinned.
- The current product implementation flags and non-goal manifest agree that no advanced family is adopted.
- The production report profile remains one static sRGB renderer cell and contains no advanced profile instance.

The gate's universal statement is satisfied by a proven empty adopted set. It does not implement a capability, accept a candidate environment, or turn future observation formats into canonical report evidence.

## Reproduce

```sh
sh scripts/test-m5-adopted-profile-gate.sh
```

Negative controls remove required evidence and construct progressively less-incomplete hypothetical adoption records. Only a record with consistent implementation, profile, environment, and adoption-source evidence validates; none exists in the current repository.

The accepted result is:

```text
M5 adopted-profile gate: passed with 0 adopted advanced capabilities
```
