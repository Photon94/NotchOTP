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
