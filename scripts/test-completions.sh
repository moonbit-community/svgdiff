#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-completions-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
bash -n completions/svgdiff.bash
if command -v zsh >/dev/null 2>&1; then
  zsh -n completions/_svgdiff
fi
if command -v fish >/dev/null 2>&1; then
  fish -n completions/svgdiff.fish
fi

moon run --target native cmd/svgdiff -- --help >"$tmp/help.txt"
options=$(sed -n '/^Options:/,/^$/s/^  \(--[a-z-]*\).*/\1/p' "$tmp/help.txt")
test "$(printf '%s\n' "$options" | wc -l | tr -d ' ')" -eq 7
for option in $options; do
  grep -q -- "$option" "$tmp/help.txt"
  grep -q -- "$option" completions/svgdiff.bash
  grep -q -- "$option" completions/_svgdiff
  grep -q -- "${option#--}" completions/svgdiff.fish
done

bash -c '
  source completions/svgdiff.bash
  complete -p svgdiff | grep -q "complete -F _svgdiff svgdiff"
  COMP_WORDS=(svgdiff --ag)
  COMP_CWORD=1
  _svgdiff
  test "${COMPREPLY[*]}" = "--agent-json"
'
touch "$tmp/before.svg"
SVGDIFF_COMPLETION_TMP="$tmp" bash -c '
  source completions/svgdiff.bash
  cd "$SVGDIFF_COMPLETION_TMP"
  COMP_WORDS=(svgdiff be)
  COMP_CWORD=1
  _svgdiff
  test "${COMPREPLY[*]}" = "before.svg"
'

for shell in bash zsh fish; do
  dest="$tmp/$shell"
  first=$(sh scripts/install-completions.sh "$shell" --dest "$dest")
  first_hash=$(find "$dest" -type f -exec shasum -a 256 {} \; | awk '{print $1}')
  second=$(sh scripts/install-completions.sh "$shell" --dest "$dest")
  second_hash=$(find "$dest" -type f -exec shasum -a 256 {} \; | awk '{print $1}')
  test "$first" = "$second"
  test "$first_hash" = "$second_hash"
done

HOME="$tmp/home" sh scripts/install-completions.sh bash >/dev/null
HOME="$tmp/home" sh scripts/install-completions.sh zsh >/dev/null
HOME="$tmp/home" sh scripts/install-completions.sh fish >/dev/null
test -f "$tmp/home/.local/share/bash-completion/completions/svgdiff"
test -f "$tmp/home/.zfunc/_svgdiff"
test -f "$tmp/home/.config/fish/completions/svgdiff.fish"

printf 'Shell completions: options: synchronized, installation: deterministic\n'
