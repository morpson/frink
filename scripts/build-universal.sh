#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Frink"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"
BUILD_DIR="$ROOT_DIR/.build/apple/Products/$CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
APP_ICON_SET="$ROOT_DIR/Sources/Frink/Resources/Assets.xcassets/AppIcon.appiconset"
APP_GRAPHICS_DIR="$ROOT_DIR/Sources/Frink/Resources/Graphics"
BUNDLED_FFMPEG_DIR="$ROOT_DIR/vendor/ffmpeg/macos-universal"
FFMPEG_LICENSE_DIR="$ROOT_DIR/vendor/ffmpeg/licenses"

cd "$ROOT_DIR"

swift build \
  --configuration "$CONFIGURATION" \
  --arch arm64 \
  --arch x86_64

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -d "$APP_ICON_SET" ]]; then
  ICONSET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/frink-iconset.XXXXXX")/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  cp "$APP_ICON_SET/mac16.png" "$ICONSET_DIR/icon_16x16.png"
  cp "$APP_ICON_SET/mac32.png" "$ICONSET_DIR/icon_16x16@2x.png"
  cp "$APP_ICON_SET/mac32.png" "$ICONSET_DIR/icon_32x32.png"
  cp "$APP_ICON_SET/mac64.png" "$ICONSET_DIR/icon_32x32@2x.png"
  cp "$APP_ICON_SET/mac128.png" "$ICONSET_DIR/icon_128x128.png"
  cp "$APP_ICON_SET/mac256.png" "$ICONSET_DIR/icon_128x128@2x.png"
  cp "$APP_ICON_SET/mac256.png" "$ICONSET_DIR/icon_256x256.png"
  cp "$APP_ICON_SET/mac512.png" "$ICONSET_DIR/icon_256x256@2x.png"
  cp "$APP_ICON_SET/mac512.png" "$ICONSET_DIR/icon_512x512.png"
  cp "$APP_ICON_SET/mac1024.png" "$ICONSET_DIR/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

if [[ -d "$APP_GRAPHICS_DIR" ]]; then
  mkdir -p "$RESOURCES_DIR/Graphics"
  cp "$APP_GRAPHICS_DIR"/*.png "$RESOURCES_DIR/Graphics/"
fi

if [[ -x "$BUNDLED_FFMPEG_DIR/ffmpeg" ]]; then
  cp "$BUNDLED_FFMPEG_DIR/ffmpeg" "$RESOURCES_DIR/ffmpeg"
  chmod +x "$RESOURCES_DIR/ffmpeg"
fi

if [[ -x "$BUNDLED_FFMPEG_DIR/ffprobe" ]]; then
  cp "$BUNDLED_FFMPEG_DIR/ffprobe" "$RESOURCES_DIR/ffprobe"
  chmod +x "$RESOURCES_DIR/ffprobe"
fi

if [[ -d "$FFMPEG_LICENSE_DIR" ]]; then
  mkdir -p "$RESOURCES_DIR/FFmpegLicenses"
  cp "$FFMPEG_LICENSE_DIR"/* "$RESOURCES_DIR/FFmpegLicenses/"
fi

if [[ -f "$ROOT_DIR/THIRD_PARTY_NOTICES.md" ]]; then
  cp "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$RESOURCES_DIR/THIRD_PARTY_NOTICES.md"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.frink.app</string>
  <key>CFBundleName</key>
  <string>frink</string>
  <key>CFBundleDisplayName</key>
  <string>frink</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "$CODE_SIGN_IDENTITY" ]]; then
  CODESIGN_ARGS=(--force --sign "$CODE_SIGN_IDENTITY" --options runtime)
  if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
    CODESIGN_ARGS+=(--timestamp)
  fi

  if [[ -f "$RESOURCES_DIR/ffmpeg" ]]; then
    codesign "${CODESIGN_ARGS[@]}" "$RESOURCES_DIR/ffmpeg"
  fi

  if [[ -f "$RESOURCES_DIR/ffprobe" ]]; then
    codesign "${CODESIGN_ARGS[@]}" "$RESOURCES_DIR/ffprobe"
  fi

  codesign "${CODESIGN_ARGS[@]}" "$APP_DIR"
fi

echo "$APP_DIR"
