# AI Status for macOS

AI Status is a native macOS menu bar app that summarizes the public operational
status of major AI services. The interface is primarily Japanese.

## Features

- Color-coded status in the menu bar
- Optional operational count such as `6/6`
- OpenAI, Claude, Gemini, Cursor, Perplexity, and GitHub Copilot
- Per-service monitoring toggles
- Optional launch at login
- Automatic refresh every 1, 5, 15, or 30 minutes
- Direct links to each provider's official status page
- No accounts, analytics, ads, or telemetry

## Requirements

- macOS 14 or later
- Xcode 16 or later with the Swift toolchain

## Build and run

```sh
./script/build_and_run.sh
```

Run tests with:

```sh
swift test
```

## Build an installer package

For local package validation:

```sh
ALLOW_UNSIGNED=1 VERSION=1.0.0 BUILD_NUMBER=1 ./script/build_release_pkg.sh
```

The resulting unsigned installer is not suitable for public distribution.
Public releases require an Apple Developer Program membership, a Developer ID
Application certificate, a Developer ID Installer certificate, and a saved
`notarytool` keychain profile:

```sh
VERSION=1.0.0 \
BUILD_NUMBER=1 \
APP_SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
INSTALLER_SIGN_IDENTITY="Developer ID Installer: Example (TEAMID)" \
NOTARY_PROFILE="aistatus-notary" \
./script/build_release_pkg.sh
```

Credentials and certificates must never be stored in the repository.

## Privacy and security

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md). The app contacts
only the public HTTPS status endpoints listed in the source. It stores display
preferences locally and does not send them to the developer.

## Disclaimer

This is an independent, unofficial project. Always consult each provider's
official status page before making operational decisions. See
[TRADEMARKS.md](TRADEMARKS.md).

## License

MIT. See [LICENSE](LICENSE).
