# Native Release Bundle

Status: current-host release packaging contract

Last verified: 2026-07-14

Run `sh scripts/package-release.sh`. From a clean checkout, it builds the native release executable and creates `dist/svgdiff-<version>-<os>-<architecture>/` with:

- `svgdiff`, the current-host native executable;
- `LICENSE`, the complete Apache License 2.0 text used by this project and all currently resolved dependencies;
- `THIRD_PARTY_NOTICES.md`, the exact dependency versions, relationships, repositories, manifest-declared licenses, and disclosure of missing package-local license files;
- `provenance.json`, project-owned build facts and product contract identities;
- `SHA256SUMS`, SHA-256 digests for every other file in the bundle.

The command checks [`dependencies.v1.json`](dependencies.v1.json) against `moon tree` before packaging. A dirty worktree is rejected by default. `--allow-dirty` exists only for local inspection and records `source_dirty: true`; do not publish such a bundle.

Verify a bundle with:

```sh
cd dist/svgdiff-<version>-<os>-<architecture>
shasum -a 256 -c SHA256SUMS
```

This metadata is an unsigned project attestation. It does not claim SLSA conformance, an SBOM, hermetic or reproducible builds, malware scanning, code signing, notarization, cross-platform testing, or publication. CI release automation and supported-platform binaries remain separate roadmap items.
