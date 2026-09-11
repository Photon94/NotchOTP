#!/bin/bash
# Requires a Developer ID Application identity and a notarytool Keychain profile.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${NOTCHOTP_SIGN_IDENTITY:?Set NOTCHOTP_SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTCHOTP_NOTARY_PROFILE:?Set NOTCHOTP_NOTARY_PROFILE to your notarytool Keychain profile name}"
output_path="${1:-$PWD/dist-notarized}"
mkdir -p "$output_path"
output_path=$(cd "$output_path" && pwd)
stage=$(mktemp -d "${TMPDIR:-/tmp}/notchotp-notarize.XXXXXX")
trap 'rm -rf "$stage"' EXIT
# Keep signing and stapling away from cloud-managed folders.
./scripts/build.sh "$stage"
codesign -dv "$stage/NotchOTP.app" 2>&1 | grep -q 'Authority=Developer ID Application:'
# Submit once; if Apple takes longer, retain its submission record for follow-up.
xcrun notarytool submit "$stage/NotchOTP.zip" --keychain-profile "$NOTCHOTP_NOTARY_PROFILE" --wait --timeout 30m --output-format json > "$output_path/app-notarization.json"
/usr/bin/plutil -extract status raw "$output_path/app-notarization.json" | grep -qx Accepted
xcrun stapler staple "$stage/NotchOTP.app"
xcrun stapler validate "$stage/NotchOTP.app"
spctl --assess --type execute --verbose=2 "$stage/NotchOTP.app"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' scripts/Info.plist)
name="NotchOTP-v${version}-macOS-$(uname -m)-notarized"
./scripts/create-dmg.sh "$stage/NotchOTP.app" "$stage/$name.dmg"
codesign --force --sign "$NOTCHOTP_SIGN_IDENTITY" --timestamp "$stage/$name.dmg"
xcrun notarytool submit "$stage/$name.dmg" --keychain-profile "$NOTCHOTP_NOTARY_PROFILE" --wait --timeout 30m --output-format json > "$output_path/dmg-notarization.json"
/usr/bin/plutil -extract status raw "$output_path/dmg-notarization.json" | grep -qx Accepted
xcrun stapler staple "$stage/$name.dmg"
xcrun stapler validate "$stage/$name.dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$stage/$name.dmg"
ditto --norsrc "$stage/$name.dmg" "$output_path/$name.dmg"
ditto -c -k --norsrc --keepParent "$stage/NotchOTP.app" "$output_path/$name.zip"
(cd "$output_path" && shasum -a 256 "$name.dmg" "$name.zip" > SHA256SUMS-NOTARIZED.txt)
printf 'Verified notarized installer: %s/%s.dmg\n' "$output_path" "$name"
