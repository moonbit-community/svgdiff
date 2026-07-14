#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

usage() {
  printf 'Usage: %s <bash|zsh|fish> [--dest DIR]\n' "$0"
}

if [ "$#" -lt 1 ]; then
  usage >&2
  exit 2
fi

shell=$1
shift
dest=
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dest)
      if [ "$#" -lt 2 ]; then
        usage >&2
        exit 2
      fi
      dest=$2
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$shell" in
  bash)
    source_file="$root/completions/svgdiff.bash"
    default_dest="$HOME/.local/share/bash-completion/completions"
    target_name=svgdiff
    ;;
  zsh)
    source_file="$root/completions/_svgdiff"
    default_dest="$HOME/.zfunc"
    target_name=_svgdiff
    ;;
  fish)
    source_file="$root/completions/svgdiff.fish"
    default_dest="$HOME/.config/fish/completions"
    target_name=svgdiff.fish
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ -z "$dest" ]; then
  dest=$default_dest
fi
mkdir -p "$dest"
install -m 0644 "$source_file" "$dest/$target_name"
printf 'Installed %s completion to %s/%s\n' "$shell" "$dest" "$target_name"
if [ "$shell" = zsh ]; then
  printf 'Ensure %s is in fpath before running compinit.\n' "$dest"
fi
