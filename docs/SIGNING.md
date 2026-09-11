# Developer ID distribution

Release signing requires a **Developer ID Application** certificate with its private key in the local macOS Keychain. An Apple Development certificate cannot replace it.

The normal build remains ad-hoc signed. To sign for distribution:

```sh
export NOTCHOTP_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./scripts/build.sh
```

This enables hardened runtime and requests an Apple secure timestamp. No private key or password belongs in the repository.

For command-line notarization, save credentials interactively in Keychain first:

```sh
xcrun notarytool store-credentials NotchOTP
export NOTCHOTP_NOTARY_PROFILE=NotchOTP
./scripts/notarize.sh
```

Use an app-specific password when prompted, not your normal Apple Account password. The script requires Apple to accept both submissions, staples tickets to the app and DMG, and verifies Gatekeeper before producing distributable files. Logs are retained in the output directory. If a submission times out, check the saved submission ID with `notarytool info` before submitting again.

Alternatively, use Xcode Organizer to upload a Developer ID archive for notarization and export the accepted app, then create a DMG with `scripts/create-dmg.sh`.

A notarized application can still show macOS's normal confirmation that it was downloaded from the internet. Notarization addresses the unidentified-developer and unverified-app blocks.

[Apple: Developer ID](https://developer.apple.com/developer-id/)

## Publishing a release

`scripts/notarize.sh` writes `dist-notarized/` with the notarized ZIP, the notarized DMG, `SHA256SUMS.txt`, and Apple's two submission logs. Those names match what the release workflow would produce, so the notarized files are the ones users download:

```sh
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' scripts/Info.plist)
gh release create "v$version" \
  "dist-notarized/NotchOTP-v$version-macOS-arm64.zip" \
  "dist-notarized/NotchOTP-v$version-macOS-arm64.dmg" \
  "dist-notarized/SHA256SUMS.txt" \
  --title "NotchOTP $version" \
  --notes-file "docs/releases/$version.md" \
  --latest
```

Pushing the tag still runs the release workflow, which builds and tests the tagged commit. It detects the existing release and leaves these downloads untouched, so it never replaces a notarized file with an ad-hoc one.

