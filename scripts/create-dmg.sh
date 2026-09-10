#!/bin/bash
set -euo pipefail
app_path="${1:?Usage: create-dmg.sh APP_PATH OUTPUT_DMG}"
output_path="${2:?Usage: create-dmg.sh APP_PATH OUTPUT_DMG}"
test -d "$app_path/Contents"
codesign --verify --deep --strict "$app_path"
stage=$(mktemp -d "${TMPDIR:-/tmp}/notchotp-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto --norsrc "$app_path" "$stage/NotchOTP.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname NotchOTP -srcfolder "$stage" -format UDZO -ov "$output_path"
hdiutil verify "$output_path"
