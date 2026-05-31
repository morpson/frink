#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Frink"
APP_DIR="${1:-$ROOT_DIR/dist/$APP_NAME.app}"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

for executable in "$APP_DIR/Contents/MacOS/$APP_NAME" "$RESOURCES_DIR/ffmpeg" "$RESOURCES_DIR/ffprobe"; do
  if [[ ! -x "$executable" ]]; then
    echo "Missing executable: $executable" >&2
    exit 1
  fi

  lipo "$executable" -verify_arch x86_64 arm64
done

if otool -L "$RESOURCES_DIR/ffmpeg" | grep -E '/(usr/local|opt/homebrew|Cellar)/'; then
  echo "Bundled ffmpeg links against local package-manager libraries." >&2
  exit 1
fi

if [[ ! -f "$RESOURCES_DIR/FFmpegLicenses/FFmpeg-LICENSE.md" ]]; then
  echo "Missing bundled FFmpeg license files." >&2
  exit 1
fi

plutil -lint "$APP_DIR/Contents/Info.plist"
"$RESOURCES_DIR/ffmpeg" -hide_banner -version >/dev/null

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
