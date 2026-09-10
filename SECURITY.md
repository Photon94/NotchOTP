# Security

NotchOTP handles two-factor authentication secrets. Version 0.2 is an early local application and has not received an independent security audit.

## Reporting

Do not include real secrets, provisioning QR codes, recovery codes, or working login codes in public issues, logs, or screenshots. Use public RFC test fixtures in reproducible examples.

If GitHub's **Report a vulnerability** option is available on the repository's Security page, use it for sensitive findings. Otherwise, open a minimal issue requesting a private contact channel without publishing exploit details or credentials.

## Current scope

- Metadata and secrets persist in the macOS Keychain as a generic-password record.
- The app uses CryptoKit HMAC, with TOTP checked against RFC 6238 vectors.
- Secrets remain in memory while the process runs; there is no per-code biometric gate or in-app vault lock.
- The app has no network client, sync service, analytics, or secret export.
- Clipboard markers are advisory; third-party software may still retain copied codes.
- The local build is ad-hoc signed, not Developer ID signed or notarized.

Keep a separate recovery method. Do not remove a working authenticator until the new setup has been verified.
