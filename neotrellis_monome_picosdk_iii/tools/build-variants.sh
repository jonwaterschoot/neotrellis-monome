#!/usr/bin/env bash
# Builds the firmware for each board / grid size combination and copies the
# UF2s to build/variants/uf2s/ with descriptive names.
#
# Usage (from Git Bash or any POSIX shell, in neotrellis_monome_picosdk_iii/):
#   tools/build-variants.sh            # all variants
#   tools/build-variants.sh dinkii-128 # just one
#
# Tool locations default to the Raspberry Pi Pico VS Code extension's
# ~/.pico-sdk install; override with PICO_SDK_PATH, PICO_TOOLCHAIN_PATH,
# CMAKE and NINJA.
set -euo pipefail

cd "$(dirname "$0")/.."

PICO_HOME="${HOME}/.pico-sdk"
PICO_SDK_PATH="${PICO_SDK_PATH:-$(ls -d "$PICO_HOME"/sdk/* | tail -1)}"
PICO_TOOLCHAIN_PATH="${PICO_TOOLCHAIN_PATH:-$(ls -d "$PICO_HOME"/toolchain/* | tail -1)}"
CMAKE="${CMAKE:-$(ls -d "$PICO_HOME"/cmake/*/bin/cmake* | tail -1)}"
NINJA="${NINJA:-$(ls -d "$PICO_HOME"/ninja/*/ninja* | tail -1)}"

# name  PICO_BOARD  BOARDTYPE  GRIDCOUNT
VARIANTS="
pico-128    pico          1 3
pico-64     pico          1 2
pico-16     pico          1 1
dinkii-128  board_dinkii  3 3
dinkii-64   board_dinkii  3 2
dinkii-16   board_dinkii  3 1
"

date=$(date +%Y%m%d)
out=build/variants/uf2s
mkdir -p "$out"

echo "$VARIANTS" | while read -r name board boardtype gridcount; do
  [ -z "$name" ] && continue
  [ $# -gt 0 ] && [[ " $* " != *" $name "* ]] && continue
  dir="build/variants/$name"
  echo "== $name (PICO_BOARD=$board BOARDTYPE=$boardtype GRIDCOUNT=$gridcount)"
  "$CMAKE" -S . -B "$dir" -G Ninja -DCMAKE_MAKE_PROGRAM="$NINJA" \
    -DPICO_SDK_PATH="$PICO_SDK_PATH" -DPICO_TOOLCHAIN_PATH="$PICO_TOOLCHAIN_PATH" \
    -DPICO_BOARD="$board" -DBOARDTYPE="$boardtype" -DGRIDCOUNT="$gridcount" >/dev/null
  "$CMAKE" --build "$dir" >/dev/null
  cp "$dir/neotrellis-iii.uf2" "$out/neotrellis-iii-$name-$date-jonwtr.uf2"
done

ls -la "$out"
