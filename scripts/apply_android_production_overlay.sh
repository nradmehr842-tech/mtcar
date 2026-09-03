#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID="$ROOT/mobile/android"
OVERLAY="$ROOT/mobile/android_overlay"

if [ ! -d "$ANDROID/app/src/main" ]; then
  echo "Android project not found: $ANDROID"
  exit 1
fi

PKG="$ANDROID/app/src/main/kotlin/ir/mediatelecom/mtcar"
rm -rf "$ANDROID/app/src/main/kotlin"
mkdir -p "$PKG"
cp "$OVERLAY/app/src/main/kotlin/ir/mediatelecom/mtcar/"*.kt "$PKG/"

cp "$OVERLAY/AndroidManifest.xml" "$ANDROID/app/src/main/AndroidManifest.xml"

for D in "$OVERLAY"/res/*; do
  [ -d "$D" ] || continue
  DEST="$ANDROID/app/src/main/res/$(basename "$D")"
  mkdir -p "$DEST"
  cp -R "$D/"* "$DEST/"
done

echo "MTcar production Android overlay applied."
