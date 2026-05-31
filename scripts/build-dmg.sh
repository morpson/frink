#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Frink"
CONFIGURATION="${CONFIGURATION:-release}"
DIST_DIR="$ROOT_DIR/dist"
GUMROAD_DIR="$DIST_DIR/gumroad"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$GUMROAD_DIR/$APP_NAME.dmg"
ZIP_PATH="$GUMROAD_DIR/$APP_NAME.zip"
export CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

echo "=== Starting packaging for Gumroad ==="

# 1. Ensure the app bundle is built
echo "Building universal release binary..."
"$ROOT_DIR/scripts/build-universal.sh"

# Validate distribution
echo "Validating application distribution..."
if [[ -f "$ROOT_DIR/scripts/validate-distribution.sh" ]]; then
  "$ROOT_DIR/scripts/validate-distribution.sh" "$APP_PATH"
fi

# 2. Setup gumroad directory
echo "Creating Gumroad distribution directory..."
mkdir -p "$GUMROAD_DIR"

# Clean up old artifacts
rm -f "$DMG_PATH" "$ZIP_PATH"

# 3. Create ZIP archive
echo "Creating ZIP archive..."
(cd "$DIST_DIR" && zip -qyr "$ZIP_PATH" "$APP_NAME.app")
echo "ZIP archive created at: $ZIP_PATH"

# 4. Create DMG disk image
echo "Creating DMG staging directory..."
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/frink-dmg-staging.XXXXXX")"

# Copy App to staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create symlink to Applications folder
ln -s /Applications "$STAGING_DIR/Applications"

echo "Building DMG using hdiutil..."
# Create temporary uncompressed read-write DMG
TEMP_DMG="$(mktemp "${TMPDIR:-/tmp}/frink-temp-dmg.XXXXXX").dmg"
rm -f "$TEMP_DMG"

# Create disk image from staging folder
hdiutil create -srcfolder "$STAGING_DIR" -volname "$APP_NAME" -fs HFS+ -format UDRW "$TEMP_DMG" -quiet

# Convert DMG to compressed read-only format for distribution
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet

# Clean up staging and temp DMG
rm -rf "$STAGING_DIR"
rm -f "$TEMP_DMG"

echo "DMG disk image created at: $DMG_PATH"
echo "=== Packaging Complete! ==="
