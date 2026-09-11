# Changelog

## 0.2.1 — 2026-09-11

### Changed
- Releases are signed with a Developer ID Application certificate and notarized by Apple; the app and the disk image carry stapled tickets, so Gatekeeper no longer blocks the first launch.
- The release workflow leaves an already-published release untouched, so a locally notarized build is not replaced by an ad-hoc one.

No changes to application behaviour.

## 0.2.0 — 2026-09-10

### Added
- Downward opening animation and reverse closing animation, respecting Reduce Motion.
- Panel width matched to the physical notch in both compact and search modes.
- Immediate concealment on sleep/session lock and cancellation of stale animation callbacks.

### Included from the first local version
- Native menu bar app with a global shortcut and keyboard search, switching, and copy.
- Circular TOTP countdown; SHA-1, SHA-256, and SHA-512 support.
- Keychain account storage and manual, URI, and QR-image setup.
- Public-fixture demo mode and a test suite including RFC 6238 vectors.
