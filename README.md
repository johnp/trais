# trais

`trais` (track AI spend) is a small macOS 26+ menu-bar app that tracks cumulative LiteLLM spend.

It periodically calls `GET /key/info`, reads `info.spend`, and shows the latest value and a seven-day graph in an expandable menu-bar panel. The API key is stored in the macOS Keychain.

## Build and run

The machine needs Swift 6.2+ with the macOS 26 SDK. Full Xcode is recommended and enables stable Apple Development signing when a certificate is installed.

```sh
./scripts/run-app.sh
```

This builds `dist/trais.app`, generates its icon, signs it with the best available code-signing identity, and opens it. If no valid identity is available, the script falls back to ad-hoc signing. Set `TRAIS_CODESIGN_IDENTITY` to explicitly choose an identity. Use the menu-bar panel's Settings button to enter the LiteLLM API key and test the connection.

## Install

```sh
./scripts/install-app.sh
```

This rebuilds the app, verifies its signature, and installs it at `/Applications/trais.app`. An existing installation is replaced only after the staged app passes signature verification.

## Checks

```sh
swift run trais-core-checks
```

The installed standalone Command Line Tools omit both `XCTest` and Swift Testing, so the repository includes a dependency-free executable check harness. It exercises request construction, response decoding, HTTP failures, and history persistence/retention.

## Behavior

- Refreshes at launch, after wake, manually, and every 5/10/15/30/60 minutes while running.
- Formats values as US dollars with a decimal point by default, with an optional euro/comma display mode.
- Keeps seven days of history, capped at 1,000 samples.
- Keeps showing the last successful value if a request fails.
- Can register itself as a login item when running from the packaged app.

Launch-at-login should be tested from a stable installed location such as `/Applications/trais.app`. macOS may require approval under System Settings → General → Login Items.
