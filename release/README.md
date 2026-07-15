# Native Release Bundle

Status: native packaging and publication contract

Last verified: 2026-07-14

Run `sh scripts/package-release.sh`. From a clean checkout, it builds the native release executable and creates `dist/svgdiff-<version>-<os>-<architecture>/` with:

- `svgdiff`, or `svgdiff.exe` on Windows, the current-host native executable;
- `LICENSE`, the complete Apache License 2.0 text used by this project and all currently resolved dependencies;
- `THIRD_PARTY_NOTICES.md`, the exact dependency versions, relationships, repositories, manifest-declared licenses, and disclosure of missing package-local license files;
- `provenance.json`, project-owned build facts and product contract identities;
- `SHA256SUMS`, SHA-256 digests for every other file in the bundle.

The command normalizes supported targets to `linux-x64`, `windows-x64`, and `macos-arm64`. It checks [`dependencies.v1.json`](dependencies.v1.json) against `moon tree` before packaging. A dirty worktree is rejected by default. `--allow-dirty` exists only for local inspection and records `source.dirty: true`; do not publish such a bundle. Add `--archive` to create a `.tar.gz` containing the complete bundle directory.

Verify a bundle with:

```sh
cd dist/svgdiff-<version>-<os>-<architecture>
shasum -a 256 -c SHA256SUMS
```

## Published binaries

A pushed tag exactly matching `v<moon.mod version>` starts [the release workflow](../.github/workflows/release.yml). The workflow never creates or moves a tag. It builds and tests all three supported targets, packages clean archives, captures canonical reports from each packaged executable, and requires byte-identical determinism bundles before publication. The GitHub Release contains:

- `svgdiff-<version>-linux-x64.tar.gz`;
- `svgdiff-<version>-windows-x64.tar.gz`;
- `svgdiff-<version>-macos-arm64.tar.gz`;
- `SHA256SUMS`, covering those three archives.

The publication job refuses to replace an existing release. Verify the downloaded archives with `sha256sum -c SHA256SUMS`, then extract the selected archive and verify its internal `SHA256SUMS` with `sha256sum -c` or `shasum -a 256 -c`. On Windows PowerShell, use `Get-FileHash <archive> -Algorithm SHA256` and compare the result with the matching `SHA256SUMS` entry before extraction.

To release after the version change and validation commit are on the intended branch, create and push the matching tag explicitly:

```sh
sh scripts/check-release-tag.sh v0.5.0
git tag -a v0.5.0 -m "svgdiff v0.5.0"
git push origin v0.5.0
```

Replace `0.5.0` with the current `moon.mod` version. The workflow rejects any mismatch before packaging and uses `--verify-tag` before publication.

This metadata is an unsigned project attestation. The release does not claim SLSA conformance, an SBOM, hermetic or cross-toolchain reproducible builds, malware scanning, code signing, or macOS notarization. The fixed hosted matrix and canonical corpus are tested; that is not exhaustive proof over all platform environments or SVG inputs.
