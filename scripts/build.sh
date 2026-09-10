#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_path="${NOTCHOTP_BUILD_PATH:-$PWD/.build}"
output_path="${1:-$PWD/dist}"
mkdir -p "$output_path"
output_path=$(cd "$output_path" && pwd)
swift build -c release --scratch-path "$build_path" --disable-sandbox
binary_path=$(swift build -c release --scratch-path "$build_path" --disable-sandbox --show-bin-path)
stage=$(mktemp -d "${TMPDIR:-/tmp}/notchotp-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT
app_path="$stage/NotchOTP.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$binary_path/NotchOTP" "$app_path/Contents/MacOS/NotchOTP"
cp scripts/Info.plist "$app_path/Contents/Info.plist"
printf 'APPL????' > "$app_path/Contents/PkgInfo"
cp scripts/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
# Sign outside cloud folders: File Provider can attach FinderInfo during signing.
ditto --norsrc "$app_path" "$output_path/NotchOTP.app"
ditto -c -k --norsrc --keepParent "$app_path" "$output_path/NotchOTP.zip"
printf 'Built: %s\n' "$output_path/NotchOTP.app"
