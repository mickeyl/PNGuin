# ScreenGrab

Menu-bar app + `iphone-screenshot` CLI around `xcrun devicectl` (Xcode 27+). See PLAN.md for the
design, HIG.md for UI tokens, `make help` for commands.

## Layout
- `Sources/ScreenGrabKit` – UI-free core (device list parsing, readiness probe, capture). Both products use it.
- `Sources/iphone-screenshot` – CLI (swift-argument-parser). stdout = PNG path only; exit codes in `--help`.
- `App/` – XcodeGen project (`project.yml`, never hand-edit the `.xcodeproj`), SwiftUI `MenuBarExtra`.

## Hard-won facts
- `devicectl list devices` includes every paired device; `tunnelState` is only the most recently
  used tunnel. Readiness = `devicectl device info lockState` (success + `passcodeRequired == false`).
- Locked device -> CoreDevice error 10003; the CLI maps it to exit code 4.
- Probes run in parallel with a 5 s timeout; the app polls (5 s) only while its panel is key
  (`WindowVisibilityObserver`), because `onAppear` is unreliable for window-style MenuBarExtra.
- The app must stay unsandboxed (launches `xcrun`).
- The `devicectl` JSON is not a documented contract: parse defensively and keep fixture tests.
- Comments/commits in English, no co-author trailers.
