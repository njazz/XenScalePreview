#!/bin/sh
# Rebuilds everything in place: icon.svg, icon-ios.svg, icon-mac-1024.png, icon-ios-1024.png and every PNG in
# Assets.xcassets/AppIcon.appiconset. Needs python3 and node; installs playwright + Chromium if they are missing.
set -e
cd "$(dirname "$0")"
node -e "require('playwright')" 2>/dev/null || npm install
[ -x "$(node -p "require('playwright').chromium.executablePath()")" ] || npx playwright install chromium
python3 make_icon.py
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
node render.js "$t"
a=Assets.xcassets/AppIcon.appiconset
mkdir -p "$a"
cp "$t/mac-1024.png" icon-mac-1024.png
cp "$t/ios-1024.png" icon-ios-1024.png
cp "$t/ios-1024.png" "$a/ios-1024.png"
for m in 16:16x16 32:32x32 128:128x128 256:256x256 512:512x512; do   # size:name, the @2x file is twice the pixels
  s=${m%%:*}; n=${m#*:}
  cp "$t/mac-$s.png" "$a/icon_$n.png"
  cp "$t/mac-$((s * 2)).png" "$a/icon_$n@2x.png"
done
echo "built: svgs, root PNGs and $a"
