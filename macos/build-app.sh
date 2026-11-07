#!/bin/bash
# Build "WXGUARD PRO.app" and a downloadable ZIP of it.
#
#     bash macos/build-app.sh [--out dist/macos] [--arch universal|x86_64|arm64]
#
# Needs macOS with the Xcode Command Line Tools (swiftc, iconutil) and Node.js 22+ to assemble the
# web client. The resulting app needs neither: it serves its own copy of the client and opens it in
# an installed Chromium browser. It is ad-hoc signed only (not notarized), see macos/README.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/dist/macos"
ARCH="universal"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$(mkdir -p "$2" && cd "$2" && pwd)"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
case "$ARCH" in universal) ARCHES=(x86_64 arm64) ;; x86_64|arm64) ARCHES=("$ARCH") ;; *) echo "bad --arch" >&2; exit 2 ;; esac

APP_NAME="WXGUARD PRO"
VERSION="$(node -p "require('$ROOT/web/package.json').version")"
BUILD="$(git -C "$ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo local)"
WORK="$OUT/work"
APP="$OUT/$APP_NAME.app"
ZIP="$OUT/WXGUARD-PRO-macOS.zip"
MIN_MACOS="12.0"

rm -rf "$WORK" "$APP" "$ZIP"
mkdir -p "$WORK" "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "== web client"
node "$ROOT/web/tools/package.mjs" --out "$APP/Contents/Resources/web"
# The app is the server; the packaged folder's own Node/Windows starters do not apply inside it.
rm -f "$APP/Contents/Resources/web/serve.mjs" "$APP/Contents/Resources/web/start-macos.command" \
      "$APP/Contents/Resources/web/start-windows.bat"

echo "== launcher (${ARCHES[*]})"
SLICES=()
for arch in "${ARCHES[@]}"; do
  swiftc -O -swift-version 5 -target "$arch-apple-macos$MIN_MACOS" \
    -o "$WORK/launcher-$arch" "$ROOT/macos/app/main.swift"
  SLICES+=("$WORK/launcher-$arch")
done
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/$APP_NAME"

echo "== icon"
ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
if qlmanage -t -s 1024 -o "$WORK" "$ROOT/web/assets/wxguard-icon.svg" >/dev/null 2>&1 \
   && [ -f "$WORK/wxguard-icon.svg.png" ]; then
  for size in 16 32 128 256 512; do
    sips -z $size $size "$WORK/wxguard-icon.svg.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$WORK/wxguard-icon.svg.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
else
  echo "warning: could not render the icon; the app will use the generic icon" >&2
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>com.thelogsarescreaming.wxguardpro</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.weather</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "== sign (ad-hoc) and zip"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
(cd "$OUT" && ditto -c -k --keepParent "$APP_NAME.app" "$(basename "$ZIP")")
(cd "$OUT" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
rm -rf "$WORK"

echo
lipo -info "$APP/Contents/MacOS/$APP_NAME"
du -sh "$APP" "$ZIP"
echo "built $APP"
