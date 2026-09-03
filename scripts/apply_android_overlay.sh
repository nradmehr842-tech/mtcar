#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE="$ROOT/mobile"
ANDROID="$MOBILE/android"

rm -rf "$ANDROID/app/src/main/kotlin"/*
mkdir -p "$ANDROID/app/src/main/kotlin/ir/mediatelecom/mtcar"
cp "$MOBILE/android_overlay/app/src/main/kotlin/ir/mediatelecom/mtcar/MainActivity.kt" \
  "$ANDROID/app/src/main/kotlin/ir/mediatelecom/mtcar/MainActivity.kt"

MANIFEST="$ANDROID/app/src/main/AndroidManifest.xml"
python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
perms='''\n    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.SEND_SMS" />\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n    <uses-permission android:name="android.permission.VIBRATE" />\n'''
if 'android.permission.SEND_SMS' not in s:
    s=s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'+perms)
s=s.replace('android:label="mtcar"', 'android:label="MTcar"')
s=s.replace('android:name=".MainActivity"', 'android:name="ir.mediatelecom.mtcar.MainActivity"')
p.write_text(s)
PY

# Keep target SDK supplied by the installed Flutter template.
