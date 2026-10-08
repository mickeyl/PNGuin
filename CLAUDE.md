# PNGuin

Menu-bar app + `iphone-screenshot` CLI around `xcrun devicectl` (Xcode 27+). See PLAN.md for the
design, HIG.md for UI tokens, `make help` for commands.

## Layout
- `Sources/PNGuinKit` – UI-free core (device list parsing, readiness probe, capture). Both products use it.
- `Sources/iphone-screenshot` – CLI (swift-argument-parser). stdout = PNG path only; exit codes in `--help`.
- `App/` – XcodeGen project (`project.yml`, never hand-edit the `.xcodeproj`), SwiftUI `MenuBarExtra`.

## Hard-won facts
- `devicectl list devices` includes every paired device; `tunnelState` is only the most recently
  used tunnel. Readiness = `devicectl device info lockState` (success + `passcodeRequired == false`).
- Locked device -> CoreDevice error 10003; the CLI maps it to exit code 4.
- Probes run strictly one at a time (5 s timeout): parallel lockState probes of several paired
  devices wedge CoreDevice from the second round on, so every request (captures too) times out and
  a reachable device flips to "unreachable". The app publishes each result as it arrives, selected
  device first.
- A preview can be dragged out (as a temp file named like a real capture) or clicked to copy.
- SwiftUI's own minification of a ~1200x2600 screenshot to ~150x320 px (1x displays) aliases text into
  illegibility; `SharpImage` shows a Lanczos copy at the exact backing size (`ImageScaler`).
- The app polls (5 s) only while its panel is key
  (`WindowVisibilityObserver`), because `onAppear` is unreliable for window-style MenuBarExtra.
- The app must stay unsandboxed (launches `xcrun`).
- The `devicectl` JSON is not a documented contract: parse defensively and keep fixture tests.
- Simulators: `simctl list -j` (booted, iOS runtime, productFamily iPhone/iPad), `simctl io … screenshot`
  with an explicit `--mask` (`ignored` matches device captures; no flag already gives alpha corners).
  A screenshot of a simulator that shut down hangs ~60 s, hence the 10 s `Simctl.timeout`. simctl
  polling does not disturb CoreDevice (measured).
- Clean status bar: `StatusBarKeeper` holds it on the previewed simulator (not per frame: flicker),
  clears only what it applied (persisted for crash recovery); a `status_bar list` with entries we did
  not set means the user's own overrides, which are left alone. `--batteryState charged` shows a bolt.
- `Package.resolved` holds the app's pins too (xcodebuild writes them there); plain `swift build/test`
  prunes them, so use the Makefile targets (`--force-resolved-versions`).
- The app was renamed from ScreenGrab (fastlane already has a `screengrab`); the bundle identifier stays
  `de.vanille.ScreenGrab` on purpose (UserDefaults: settings, lastUsed). The CLI keeps its descriptive name.
- Comments/commits in English, no co-author trailers.
