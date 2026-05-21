#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="GHAlerter"
VOLUME_NAME="GH Alerter"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
DMG_DIR="$DIST_DIR/dmg-staging"
DMG_MOUNT="$DIST_DIR/dmg-mount"
RW_DMG_PATH="$DIST_DIR/GHAlerter-rw.dmg"
DMG_PATH="$DIST_DIR/GHAlerter-signed-notarized.dmg"

cleanup() {
  if hdiutil info | grep -Fq "$DMG_MOUNT"; then
    hdiutil detach "$DMG_MOUNT" -quiet || true
  fi
}
trap cleanup EXIT

if [[ -z "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  cat >&2 <<'EOF'
DEVELOPER_ID_APPLICATION is required.

Example:
  export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
EOF
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "$DEVELOPER_ID_APPLICATION"; then
  cat >&2 <<EOF
Signing identity was not found in the active keychain:
  $DEVELOPER_ID_APPLICATION

Run:
  security find-identity -v -p codesigning

Then set DEVELOPER_ID_APPLICATION to the exact "Developer ID Application: ..." value.
EOF
  exit 1
fi

"$ROOT_DIR/scripts/build-app.sh"
swift "$ROOT_DIR/scripts/generate-dmg-background.swift"

xattr -cr "$APP_DIR" || true

codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
spctl --assess --type execute --verbose=4 "$APP_DIR" || true
xattr -cr "$APP_DIR" || true
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -rf "$DMG_DIR" "$DMG_MOUNT" "$RW_DMG_PATH" "$DMG_PATH"
mkdir -p "$DMG_DIR" "$DMG_MOUNT"
ditto --noextattr --noacl "$APP_DIR" "$DMG_DIR/$APP_NAME.app"
xattr -cr "$DMG_DIR/$APP_NAME.app" || true
codesign --verify --deep --strict --verbose=2 "$DMG_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_DIR/Applications"
mkdir -p "$DMG_DIR/.background"
cp "$ROOT_DIR/Sources/GHAlerterApp/Resources/DmgBackground.png" "$DMG_DIR/.background/DmgBackground.png"
cp "$ROOT_DIR/Sources/GHAlerterApp/Resources/AppIcon.icns" "$DMG_DIR/.VolumeIcon.icns"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_DIR" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  "$RW_DMG_PATH"

hdiutil attach "$RW_DMG_PATH" -mountpoint "$DMG_MOUNT" -nobrowse -quiet

osascript <<OSA
tell application "Finder"
  set dmgFolder to POSIX file "$DMG_MOUNT" as alias
  open dmgFolder
  delay 1
  set containerWindow to front window
  set current view of containerWindow to icon view
  set toolbar visible of containerWindow to false
  set statusbar visible of containerWindow to false
  set bounds of containerWindow to {100, 100, 820, 560}
  set viewOptions to icon view options of containerWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 104
  set background picture of viewOptions to POSIX file "$DMG_MOUNT/.background/DmgBackground.png"
  set position of item "$APP_NAME" of dmgFolder to {205, 250}
  set position of item "Applications" of dmgFolder to {520, 250}
  update dmgFolder without registering applications
  delay 1
  close containerWindow
end tell
OSA

cp "$ROOT_DIR/Sources/GHAlerterApp/Resources/AppIcon.icns" "$DMG_MOUNT/.VolumeIcon.icns"
SetFile -a C "$DMG_MOUNT"
SetFile -a V "$DMG_MOUNT/.VolumeIcon.icns"
if [[ ! -f "$DMG_MOUNT/.VolumeIcon.icns" ]]; then
  echo "DMG volume icon file was not copied." >&2
  exit 1
fi
if ! GetFileInfo -a "$DMG_MOUNT" | grep -q C; then
  echo "DMG custom volume icon attribute was not set." >&2
  exit 1
fi
xattr -cr "$DMG_MOUNT/$APP_NAME.app" || true
codesign --verify --deep --strict --verbose=2 "$DMG_MOUNT/$APP_NAME.app"

sync
hdiutil detach "$DMG_MOUNT" -quiet
hdiutil convert "$RW_DMG_PATH" -format UDZO -o "$DMG_PATH"

codesign \
  --force \
  --timestamp \
  --sign "$DEVELOPER_ID_APPLICATION" \
  "$DMG_PATH"

codesign --verify --verbose=2 "$DMG_PATH"

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait
else
  cat >&2 <<'EOF'
Notarization credentials are required.

Preferred:
  export NOTARYTOOL_PROFILE="gh-alerter"

Create it with:
  xcrun notarytool store-credentials gh-alerter

Alternative:
  export APPLE_ID="you@example.com"
  export APPLE_TEAM_ID="TEAMID"
  export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
EOF
  exit 1
fi

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

echo "Built $DMG_PATH"
