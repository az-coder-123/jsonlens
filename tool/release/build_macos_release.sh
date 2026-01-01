#!/usr/bin/env bash
set -euo pipefail

# Build and package macOS release for JSONLens
# Usage: ./tool/release/build_macos_release.sh

RELEASE_DIR="release/macos"
BUILD_DIR="build/macos/Build/Products/Release"

echo "1/5: Ensuring Flutter dependencies..."
flutter pub get

echo "2/5: Building macOS release..."
flutter build macos --release

echo "3/5: Locating .app bundle..."
APP_PATH=$(find "$BUILD_DIR" -maxdepth 1 -type d -name "*.app" | head -n 1)
if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: .app bundle not found in $BUILD_DIR"
  exit 1
fi
APP_NAME=$(basename "$APP_PATH")
echo "Found app: $APP_NAME"

echo "4/5: Copying to release directory..."
mkdir -p "$RELEASE_DIR"
rm -rf "$RELEASE_DIR/$APP_NAME"
cp -R "$APP_PATH" "$RELEASE_DIR/"

echo "5/5: Creating ZIP artifact..."
pushd "$RELEASE_DIR" >/dev/null
rm -f "${APP_NAME}.zip"
zip -r "${APP_NAME}.zip" "${APP_NAME}"
# Remove the copied .app bundle to keep only the zip artifact
rm -rf "${APP_NAME}"
popd >/dev/null

echo "Done ✅"
echo "Artifacts in: $RELEASE_DIR/"
if [[ -f "$RELEASE_DIR/${APP_NAME}.zip" ]]; then
  echo " - Zip: $RELEASE_DIR/${APP_NAME}.zip"
fi
if [[ -d "$RELEASE_DIR/$APP_NAME" ]]; then
  echo " - App bundle: $RELEASE_DIR/$APP_NAME (still present)"
else
  echo " - App bundle removed; only the zip artifact remains."
fi
