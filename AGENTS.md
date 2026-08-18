# Agent guide for trais

## Product scope

`trais` is a macOS 26+ menu-bar-only app for tracking cumulative LiteLLM spend. It is deliberately small:

- No Dock app, desktop widget, WidgetKit extension, shell execution, or curl parser.
- One configured LiteLLM endpoint and API key.
- `GET /key/info` with `Accept: application/json` and `x-litellm-api-key`.
- Decode `info.spend` as either a JSON number or numeric string.
- Poll while the app runs; refresh at launch, after wake, manually, and every 5/10/15/30/60 minutes.
- Store seven days of cumulative samples, capped at 1,000.

Keep changes focused on this scope unless the user explicitly expands it, then update this list.

## Repository structure

This is a Swift Package, not an Xcode project:

- `Package.swift` — macOS 26 package definition using Swift 6 language mode and strict concurrency checks.
- `Sources/TraisCore/` — Foundation-only request, response, sample, and history logic.
- `Sources/TraisApp/` — SwiftUI/AppKit menu-bar application.
- `Sources/TraisApp/Components/` — AppKit bridges and small reusable UI pieces.
- `Checks/TraisCoreChecks/` — dependency-free executable regression checks.
- `scripts/build-app.sh` — creates `dist/trais.app`, generates its icon, and signs it from the SwiftPM release executable.
- `scripts/generate-icon.swift` — reproducibly renders the app icon at all required `.iconset` sizes.
- `scripts/run-app.sh` — builds and opens the app.
- `scripts/install-app.sh` — builds, stages, verifies, and installs the app at `/Applications/trais.app`.

Do not add dependencies unless they materially simplify a requested feature. The current implementation uses only Apple frameworks.

## Architecture and lifecycle

- `TraisApp.swift` owns a long-lived `AppModel` and exposes a `.window`-style `MenuBarExtra` plus a `Settings` scene.
- Keep polling and wake observation in `AppModel`, not in a view task. Menu-bar panel views are transient and are recreated as the panel opens and closes.
- `AppModel.refresh()` serializes refreshes with `isRefreshing`; preserve this when adding new refresh triggers.
- The packaged app sets `LSUIElement = true`, so it has no Dock icon or normal app menu. Preserve the visible Quit action in the menu-bar panel.
- Opening Settings uses `NSApplication.activate(ignoringOtherApps:)` followed by SwiftUI's `openSettings` action.
- Launch-at-login uses `SMAppService.mainApp`. Test it from a stable packaged location such as `/Applications/trais.app`, not a transient build directory.

## Networking and secrets

- `LiteLLMClient` must enforce HTTPS immediately before constructing the authenticated request. Do not rely only on settings validation.
- Never print, log, persist, or include the API key in errors.
- The API key is stored as a Keychain generic-password item by `KeychainStore`.
- `AppModel` reads the key once at launch and caches it in memory. Normal polling must use that cache and never query Keychain repeatedly; Keychain writes/deletes occur only through Settings.
- Keychain access is configured for `kSecAttrAccessibleAfterFirstUnlock`; do not add user-presence requirements because unattended polling must work after login.
- `build-app.sh` automatically prefers an Apple Development identity, then Developer ID or another valid identity, and falls back to ad-hoc signing only when none is available. `TRAIS_CODESIGN_IDENTITY` can explicitly select an identity. Preserve this fallback behavior.
- Ad-hoc rebuilding changes the app identity and can cause Keychain permission prompts. Do not weaken Keychain ACLs or move the token to plaintext to avoid this; stable signing is the correct fix.
- `APIKeySecureField` intentionally wraps `NSSecureTextField` and sets `contentType = .oneTimeCode` plus `isAutomaticTextCompletionEnabled = false`. This public workaround suppresses the Passwords AutoFill dropdown on macOS 26. Do not replace it with SwiftUI `SecureField`, `nil`, `.password`, or `.newPassword` without manually verifying that AutoFill remains suppressed.

## History and spend calculations

- `SpendHistoryStore` is an actor and writes a versioned JSON document atomically under Application Support.
- It sorts samples, applies seven-day retention and the 1,000-sample cap on both load and append.
- Unreadable or unsupported history is moved to `history.corrupt.json` so collection can recover rather than failing forever.
- Spend values use `Decimal` for storage and calculations; convert to `Double` only at chart/formatting boundaries.
- The seven-day summary is the latest cumulative value minus the first retained sample.
- Today's summary uses the latest sample at or before local midnight as its baseline, falling back to the first sample today when no prior sample exists.
- Keep failed requests out of the sample history so errors cannot distort the chart.

## UI conventions and chart behavior

- Keep the menu-bar panel compact and native-looking.
- The large cumulative total is left-aligned. Seven-day and today deltas are compact and right-aligned.
- `CurrencyFormatting.swift` controls the persisted display currency. USD always uses `$` with an `en_US` decimal point; EUR uses `€` with a `de_DE` decimal comma. Do not replace this with locale-dependent currency formatting.
- Currency selection changes formatting only; it does not convert the LiteLLM value.
- Main totals retain two decimal places. Y-axis labels suppress trailing zero decimals and can show extra precision for narrow ranges.
- The chart has an adaptive time/day x-axis and a zoomable y-axis.
- `ChartZoomOverlay` bridges AppKit scroll-wheel events into SwiftUI. The default y range is zoomed around observed spend so penny changes remain visible; scrolling can zoom toward or away from zero.
- Show `AxisBreakMark` whenever the visible y-domain excludes zero. This is important context because a truncated axis exaggerates small changes.

## Build and validation

Use the most specific validation first:

```sh
swift build
swift run trais-core-checks
./scripts/build-app.sh
```

The check harness covers request construction, number/string decoding, HTTP errors, HTTPS enforcement, history sorting/persistence, retention, pruning, and corrupt-history recovery. It exists because the original Command Line Tools environment lacked both XCTest and Swift Testing; keep it working even when full Xcode is installed.

After UI or lifecycle changes:

1. Run `swift build` and `swift run trais-core-checks`.
2. Rebuild `dist/trais.app` with `./scripts/build-app.sh`.
3. Verify project diagnostics.
4. Launch the packaged app for a smoke test when practical.
5. State clearly when a behavior, such as Passwords AutoFill or login-item approval, requires manual UI verification.
6. Update this AGENTS.md document and the README.md if necessary.

Do not claim that the real LiteLLM endpoint was tested unless a user-provided key was actually used. Never request or expose that key in logs or test fixtures.

## Packaging caveats

- `swift build` produces a Mach-O executable, not a macOS app bundle. Use `scripts/build-app.sh` for the runnable app.
- The script creates `Info.plist`, sets the macOS 26 deployment target and `LSUIElement`, generates `trais.icns`, and uses the best available signing identity with an ad-hoc fallback.
- `dist/`, `.build/`, and the generated iconset are generated and ignored; do not edit generated artifacts directly. Change `scripts/generate-icon.swift` instead.
- The current development bundle is host-architecture. Universal binaries, hardened runtime, Developer ID distribution signing, notarization, and stapling are separate distribution work.
- Before changing signing behavior, inspect available identities with `security find-identity -v -p codesigning` and verify the final bundle with `codesign -dv --verbose=4 dist/trais.app`.
