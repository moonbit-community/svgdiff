# Terminal Operational Readiness Gate

Status: accepted terminal evidence

Gate identity: `svgdiff-terminal-operational-gate/1`

Last verified: 2026-07-17

This gate composes five independent operational obligations for the fourth terminal acceptance item: deterministic report output, installation, hostile-input handling, versioned contracts, and reproducible behavior on the supported native matrix.

## Exact claim

- Determinism covers repeated canonical report bytes and closed report-local references for identical inputs, profile, and implementation.
- Installation covers the documented source installer and checksummed current-host release archive, including provenance, license, dependency notices, direct PATH use, and deterministic reinstall.
- Hostile-input security covers strict parsing, no script execution or implicit network access, fixed admission budgets, unsafe reference-graph rejection, bounded failed reports, deterministic fuzz/adversarial suites, and sandboxed offline HTML previews.
- Versioning covers module/CLI, Structured Report Schema, Agent projection, renderer/conformance, ordering, Impact, and explicit compatibility dispatch.
- Supported-environment reproducibility covers native release behavior and exact canonical report bytes on Ubuntu 24.04 x64, Windows Server 2025 x64, and macOS 15 arm64 through the fixed CI and release matrices.

The hostile-input claim is not process or multi-tenant isolation, an arbitrary-input hard deadline or peak-memory limit, exhaustive fuzz proof, or permission to expose the CLI as an unauthenticated upload service. The distribution claim is not bit-identical executables, cross-toolchain reproducibility, signing, notarization, or SLSA attestation. Local cross-platform controls validate aggregation semantics but do not emulate three operating systems; the hosted matrix is the cross-environment enforcement surface.

## Reproduce

```sh
sh scripts/test-terminal-operational-gate.sh
```

The script validates manifest and workflow negative controls, runs focused resource-limit tests, and composes the existing installation, release, determinism, versioning, compatibility, CLI, fuzz, adversarial, and pinned-browser HTML-security suites.

The accepted result is:

```text
Terminal operational readiness gate: passed
```
