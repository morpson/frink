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

# Copy background image
mkdir -p "$STAGING_DIR/.background"
cp "$ROOT_DIR/Sources/Frink/Resources/Graphics/dmg_background.png" "$STAGING_DIR/.background/background.png"

echo "Building temporary DMG using hdiutil..."
# Create temporary uncompressed read-write DMG
TEMP_DMG="$(mktemp "${TMPDIR:-/tmp}/frink-temp-dmg.XXXXXX").dmg"
rm -f "$TEMP_DMG"

# Create disk image from staging folder
hdiutil create -srcfolder "$STAGING_DIR" -volname "$APP_NAME" -fs HFS+ -format UDRW "$TEMP_DMG" -quiet

# Mount the temporary DMG
echo "Mounting temporary DMG..."
MOUNT_DIR="/Volumes/$APP_NAME"
if [[ -d "$MOUNT_DIR" ]]; then
  hdiutil detach "$MOUNT_DIR" -force || true
fi
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -quiet

# Run AppleScript to configure Finder view
echo "Configuring Finder window layout..."
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {400, 100, 1040, 740}
    
    set theViewOptions to the icon view options of container window
    set icon size of theViewOptions to 96
    set arrangement of theViewOptions to not arranged
    set background picture of theViewOptions to file ".background:background.png"
    
    -- Position icons: Applications on the left, App on the right
    set position of item "Applications" of container window to {180, 320}
    set position of item "$APP_NAME.app" of container window to {460, 320}
    
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT

# Wait a moment for changes to flush, then unmount
sleep 2
echo "Unmounting temporary DMG..."
hdiutil detach "$MOUNT_DIR" -quiet

# Convert DMG to compressed read-only format for distribution
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet

# Clean up staging and temp DMG
rm -rf "$STAGING_DIR"
rm -f "$TEMP_DMG"

echo "DMG disk image created at: $DMG_PATH"
echo "=== Packaging Complete! ==="
