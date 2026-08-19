#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_root="$root/dist"
archive=false

usage() {
  printf 'Usage: %s [--output DIR] [--archive]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      test "$#" -ge 2 || { usage >&2; exit 2; }
      output_root=$2
      shift 2
      ;;
    --archive)
      archive=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

cd "$root"
version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' modules/svgdiff/moon.mod)
case "${RUNNER_OS-$(uname -s)}" in
  Linux) platform=linux-x64; executable=svgdiff ;;
  Windows) platform=windows-x64; executable=svgdiff.exe ;;
  macOS|Darwin) platform=macos-arm64; executable=svgdiff ;;
  *) printf 'Unsupported release platform\n' >&2; exit 1 ;;
esac

moon build --target native --release modules/svgdiff/cmd/svgdiff
binary="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
bundle="$output_root/svgdiff-$version-$platform"
rm -rf "$bundle" "$bundle.tar.gz"
mkdir -p "$bundle"
cp "$binary" "$bundle/$executable"
cp LICENSE "$bundle/LICENSE"
chmod +x "$bundle/$executable"

if command -v shasum >/dev/null 2>&1; then
  (cd "$bundle" && shasum -a 256 LICENSE "$executable" >SHA256SUMS)
else
  (cd "$bundle" && sha256sum LICENSE "$executable" >SHA256SUMS)
fi

printf 'Created %s\n' "$bundle"
if [ "$archive" = true ]; then
  tar -czf "$bundle.tar.gz" -C "$output_root" "$(basename "$bundle")"
  printf 'Created %s\n' "$bundle.tar.gz"
fi
