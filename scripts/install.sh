#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
bindir=${SVGDIFF_INSTALL_DIR:-"$HOME/.local/bin"}

usage() {
  printf 'Usage: %s [--bindir DIR]\n' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bindir)
      if [ "$#" -lt 2 ]; then
        usage >&2
        exit 2
      fi
      bindir=$2
      shift 2
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

if ! command -v moon >/dev/null 2>&1; then
  printf 'MoonBit is required to build svgdiff: https://www.moonbitlang.com/download/\n' >&2
  exit 1
fi

cd "$root"
moon build --target native --release cmd/svgdiff >/dev/null
binary="$root/_build/native/release/build/Milky2018/svgdiff/cmd/svgdiff/svgdiff.exe"
if [ ! -x "$binary" ]; then
  printf 'Release binary was not produced at %s\n' "$binary" >&2
  exit 1
fi

mkdir -p "$bindir"
install -m 0755 "$binary" "$bindir/svgdiff"
printf 'Installed svgdiff to %s/svgdiff\n' "$bindir"

case ":${PATH:-}:" in
  *:"$bindir":*)
    printf 'The install directory is already on PATH.\n'
    ;;
  *)
    printf 'Add it to this shell with: export PATH="%s:$PATH"\n' "$bindir"
    ;;
esac
