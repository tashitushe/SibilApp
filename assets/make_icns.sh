#!/bin/bash
# usage: make_icns.sh <source.png> <output.icns>
set -e
SRC="$1"
OUT="$2"
DIR="$(mktemp -d)/icon.iconset"
mkdir -p "$DIR"

for size in 16 32 64 128 256 512; do
  sips -z $size $size "$SRC" --out "$DIR/icon_${size}x${size}.png" >/dev/null
  double=$((size*2))
  sips -z $double $double "$SRC" --out "$DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$DIR" -o "$OUT"
rm -rf "$(dirname "$DIR")"
echo "wrote $OUT"
