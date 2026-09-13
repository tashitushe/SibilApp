#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SIGN_ID="-"   # ad-hoc; change to a Developer ID for real distribution

echo "==> Building TemplateRuntime"
(cd "$ROOT/Template" && swift build -c release)

echo "==> Building SibilApp"
(cd "$ROOT/Generator" && swift build -c release)

TEMPLATE_BIN="$ROOT/Template/.build/release/TemplateRuntime"
GENERATOR_BIN="$ROOT/Generator/.build/release/SibilApp"

DIST="$ROOT/dist"
rm -rf "$DIST"
mkdir -p "$DIST"

TEMPLATE_APP="$DIST/Template.app"
GENERATOR_APP="$DIST/SibilApp.app"

echo "==> Assembling Template.app"
mkdir -p "$TEMPLATE_APP/Contents/MacOS" "$TEMPLATE_APP/Contents/Resources"
cp "$TEMPLATE_BIN" "$TEMPLATE_APP/Contents/MacOS/TemplateRuntime"
chmod +x "$TEMPLATE_APP/Contents/MacOS/TemplateRuntime"
cp "$ROOT/Template/Info.plist" "$TEMPLATE_APP/Contents/Info.plist"
cp "$ROOT/assets/AppIcon_generic.icns" "$TEMPLATE_APP/Contents/Resources/AppIcon.icns"
cat > "$TEMPLATE_APP/Contents/Resources/config.json" <<EOF
{"url": "https://example.com", "title": "WebApp"}
EOF

echo "==> Assembling SibilApp.app"
mkdir -p "$GENERATOR_APP/Contents/MacOS" "$GENERATOR_APP/Contents/Resources"
cp "$GENERATOR_BIN" "$GENERATOR_APP/Contents/MacOS/SibilApp"
chmod +x "$GENERATOR_APP/Contents/MacOS/SibilApp"
cp "$ROOT/Generator/Info.plist" "$GENERATOR_APP/Contents/Info.plist"
cp "$ROOT/assets/AppIcon_forge.icns" "$GENERATOR_APP/Contents/Resources/AppIcon.icns"
cp -R "$TEMPLATE_APP" "$GENERATOR_APP/Contents/Resources/Template.app"

echo "==> Code signing (ad-hoc)"
codesign --force --deep --sign "$SIGN_ID" "$TEMPLATE_APP"
codesign --force --deep --sign "$SIGN_ID" "$GENERATOR_APP"

echo "==> Done: $GENERATOR_APP"
