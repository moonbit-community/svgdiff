#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=${TMPDIR:-/tmp}/svgdiff-module-package-$$
version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' "$root/moon.mod")
archive="$root/_build/publish/Milky2018-svgdiff-$version.zip"
codec_version=$(awk -F '"' '$1 ~ /^version = / { print $2; exit }' "$root/modules/raster_codec/moon.mod")
codec_archive="$root/_build/publish/Milky2018-svgdiff-raster-codec-$codec_version.zip"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

cd "$root"
moon package --list >/dev/null 2>&1
test -f "$archive"
unzip -Z1 "$archive" | sed '/\/$/d' >"$tmp/package-list.txt"

(
  cd modules/raster_codec
  moon package --list >/dev/null 2>&1
)
test -f "$codec_archive"
unzip -Z1 "$codec_archive" | sed '/\/$/d' >"$tmp/codec-package-list.txt"

while IFS= read -r path; do
  case "$path" in
    LICENSE | PACKAGE.mbt.md | moon.mod | moon.pkg | pkg.generated.mbti | svgdiff.mbt | html_report.mbt | css_color | css_color/moon.pkg | css_color/pkg.generated.mbti | engine | engine/moon.pkg | engine/pkg.generated.mbti)
      ;;
    css_color/*.mbt)
      case "$path" in
        *_test.mbt | *_wbtest.mbt)
          printf 'Registry package contains a test source: %s\n' "$path" >&2
          exit 1
          ;;
      esac
      ;;
    engine/*.mbt)
      case "$path" in
        *_test.mbt | *_wbtest.mbt)
          printf 'Registry package contains a test source: %s\n' "$path" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      printf 'Registry package contains an unexpected path: %s\n' "$path" >&2
      exit 1
      ;;
  esac
done <"$tmp/package-list.txt"

while IFS= read -r path; do
  case "$path" in
    LICENSE | README.mbt.md | moon.mod | moon.pkg | pkg.generated.mbti | jpeg_decode.mbt | jpeg_tables.mbt | png_color.mbt | png_decode.mbt | png_filter.mbt | types.mbt)
      ;;
    *)
      printf 'Raster codec package contains an unexpected path: %s\n' "$path" >&2
      exit 1
      ;;
  esac
done <"$tmp/codec-package-list.txt"

for required in LICENSE PACKAGE.mbt.md moon.mod moon.pkg svgdiff.mbt html_report.mbt css_color/moon.pkg css_color/color.mbt engine/moon.pkg engine/structured_report.mbt; do
  grep -Fx "$required" "$tmp/package-list.txt" >/dev/null
done

unzip -q "$archive" -d "$tmp/svgdiff"
unzip -q "$codec_archive" -d "$tmp/svgdiff-raster-codec"
mkdir -p "$tmp/consumer"

cat >"$tmp/moon.work" <<EOF
members = [
  "svgdiff",
  "svgdiff-raster-codec",
  "consumer",
]
EOF

cat >"$tmp/consumer/moon.mod" <<EOF
name = "svgdiff-package-consumer"
version = "0.0.0"
preferred_target = "native"

import {
  "Milky2018/svgdiff@$version",
}
EOF

cat >"$tmp/consumer/moon.pkg" <<'EOF'
import {
  "Milky2018/svgdiff",
}

pkgtype(kind: "executable")

supported_targets = "+native"
EOF

cat >"$tmp/consumer/main.mbt" <<'EOF'
///|
fn main {
  let before = "<svg width='16' height='16'><rect width='8' height='8' fill='red'/></svg>"
  let after = "<svg width='16' height='16'><rect width='8' height='8' fill='blue'/></svg>"
  let report = @svgdiff.compare(
    before,
    after,
    @svgdiff.ComparisonProfile::v1_default(),
  )
  guard report.schema_version == "1.37" else { abort("wrong schema") }
  guard report.analysis_status == "complete" else { abort("incomplete report") }
  guard report.atomic_differences.length() > 0 else { abort("missing difference") }
  let resource_svg = "<svg xmlns='http://www.w3.org/2000/svg'><image href='asset.png'/></svg>"
  let bundled = @svgdiff.compare_with_resources(
    resource_svg,
    resource_svg,
    @svgdiff.ComparisonProfile::v1_default(),
    {
      entries: [
        {
          locator: "asset.png",
          media_type: "image/png",
          bytes: Bytes::default(),
        },
      ],
    },
    @svgdiff.ResourceBundle::empty(),
  )
  guard bundled.analysis_status == "partial" else {
    abort("resource bundle API unavailable")
  }
}
EOF

(
  cd "$tmp"
  moon check --target native
  moon run --target native consumer
)

printf 'MoonBit publication package and independent consumer: ok\n'
