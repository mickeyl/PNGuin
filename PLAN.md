# PNGuin – Implementation Plan

Simulator support (0.9.0) is planned in [SIMULATORS.md](SIMULATORS.md).

Menu-bar app + CLI to list attached iPhones/iPads and capture their screens.
A skill/AI agent calls the same CLI ("take a screenshot of the iPhone and look at it").

## Why this exists

The previous `iphone-screenshot` bash script depended on a root `pymobiledevice3 tunneld`
LaunchDaemon. It wedged silently (answering `{}` forever after "device has not been unlocked
recently") and could only be fixed with sudo. Xcode 27 ships `xcrun devicectl device capture
screenshot`, which needs no tunnel daemon, no sudo and no Python.

## Verified facts (Xcode 27, macOS 27)

- `xcrun devicectl device capture screenshot --device <name|udid> --destination <file.png>`
  works in ~0.7 s on an unlocked, connected iOS 27 device. Output is a PNG at native resolution.
- Locked device -> CoreDeviceError 10003 ("device was still locked"). Missing DDI -> error 12040.
  Both are recoverable user states, not bugs.
- `xcrun devicectl list devices --json-output <file>` takes ~0.3 s and gives, per device:
  `deviceProperties.name/osVersionNumber`, `hardwareProperties.udid/deviceType/reality`,
  `connectionProperties.*`. All paired devices are listed as available whether or not they are
  nearby; `tunnelState` only reflects the most recently used tunnel and is NOT a readiness signal.
- `xcrun devicectl device info lockState --device X --json-output f` (~0.6 s, run sequentially for
  all devices, 5 s timeout) is the readiness probe: success + `passcodeRequired:false` = ready,
  `passcodeRequired:true` or error 10003 = locked, anything else = unreachable.
- There is no event/subscription interface in `devicectl`; liveness requires polling.

## Architecture

SwiftPM package `PNGuin` (macOS 15+), plus an XcodeGen-generated app project.

```
PNGuin/
  Package.swift
  Sources/
    PNGuinKit/          library, no UI
      Device.swift                value type: name, udid, kind, osVersion, connectionState
      DeviceList.swift            parse `devicectl list devices` JSON -> [Device] (pure, tested)
      PreviewCache.swift          cache dir + per-device preview file management
    Devicectl.swift             async Process runner (stdout/stderr capture, timeout, cancellation)
      DeviceCenter.swift          list devices; refresh
      Screenshotter.swift         capture(device:to:) -> URL, maps CoreDevice errors -> CaptureError
      CaptureError.swift          .locked, .notConnected, .notFound, .devicectlMissing, .failed(String)
      OutputLocation.swift        default dir, timestamped filename, uniqueness
    iphone-screenshot/      CLI executable (swift-argument-parser)
      main / Capture.swift / List.swift
  App/                      macOS menu-bar app target (XcodeGen, LSUIElement)
    PNGuinApp.swift         MenuBarExtra(.window)
    DeviceMenuView.swift        list + footer
    DeviceRow.swift             name, OS, state badge, capture button
    LastCaptureView.swift       thumbnail + Reveal / Copy / Open
    SettingsView.swift          output dir, copy to clipboard, launch at login
    AppModel.swift              @Observable; polling only while menu is open
    Theme.swift                 semantic colours / typography / metrics
    Resources/{en,de}.lproj/Localizable.strings, Shark.swift (R.L.*)
  Tests/PNGuinKitTests/     DeviceList parsing fixtures, error mapping, filename logic
  project.yml  Makefile  HIG.md  README.md  LICENSE (MIT)  CLAUDE.md
```

The Kit shells out to `devicectl` (public, supported tool) instead of linking private
CoreDevice frameworks. Rationale: stable contract, no entitlement/ABI risk. Cost: ~0.3 s per
list call and no push events.

### Polling

- Menu closed: no polling at all (no battery/CPU cost). Menu opens: refresh immediately, then
  every 3 s while open. Captures run on a background task; one capture per device at a time.
- Optional later: subscribe to IOKit/usbmux attach events purely as a "refresh now" hint.

## CLI contract (clig.dev)

Backwards compatible with the old script so existing callers keep working.

```
iphone-screenshot [capture] [--device NAME|UDID] [--output-dir DIR] [--name FILE.png]
iphone-screenshot list [--json]
```

- `capture` is the default subcommand. stdout: the PNG path only (one line). stderr: errors/hints.
- `list`: probes all devices sequentially; TSV by default (name, udid, ready|locked|unreachable, os), `--json` for structured output, `--no-probe` for an instant unprobed list.
- Device resolution: explicit `--device` (name or UDID, case-insensitive) -> env
  `IPHONE_SCREENSHOT_DEVICE_NAME` -> the only *ready* device (probed) -> error listing candidates.
  (The hard-coded default `M16` goes away; ambiguity is reported instead of guessed.)
- Exit codes: 0 ok, 1 capture failed, 2 usage, 3 device not found / ambiguous, 4 device locked
  (so an agent can tell "ask the user to unlock" from a real failure), 127 devicectl missing.
- Aliases `--udid` / `--device-name` stay for old callers; `--list` stays as alias for `list`.
- `-q`, `--no-color`, `--version`, `--help` with examples.

## Menu-bar app UX

- Status item: SF Symbol `iphone.gen3.badge.play` / fallback `iphone`. Window-style popover.
- Rows: device name, OS, availability badge (Ready / Locked / Unreachable, from the lockState probe); icon right-aligned,
  text left-aligned. Row tap selects the device (loads its preview); the camera button captures; spinner while capturing; button disabled when not ready.
- Locked device: row explains "Unlock the iPhone", with auto-retry on next poll.
- Preview: opening the menu captures one preview (best-status device: last used, else first
  ready) into `~/Library/Caches/PNGuin/previews/<udid>.png` and shows it as soon as it
  arrives (~0.7 s measured, stable over repeated captures); the last cached preview is shown
  meanwhile. Previews never touch the output folder; only the Screenshot action saves a file.
  Selecting another row loads its preview. Optional auto-refresh (~1 fps while the menu is
  open, off by default: it keeps the iPhone busy). Locked devices show "Unlock the iPhone".
  True live video is not possible via `devicectl` (screen-record only writes files).
- After capture: thumbnail row at top with Reveal in Finder, Copy, Open in Preview; capture also
  copied to clipboard if enabled. Optional notification (off by default).
- Footer: Settings, Quit. Settings: output folder (default `~/Desktop`, same as CLI), copy to
  clipboard, launch at login (`SMAppService.mainApp`).
- Localisation en + de via Shark (`R.L.<View>_<ELEMENT>`), typographic quotes/ellipses.
- Light/Dark/System via semantic colours; HIG.md documents tokens.
- Logging via `Cornucopia.Core.Logger`.
- App and CLI share PNGuinKit and the same output-dir default; the app does not shell out
  to the CLI (one code path, typed errors).

## Skill integration

- `~/.codex/skills/iphone-screenshot/SKILL.md` keeps calling `iphone-screenshot`; documents
  `list`, exit code 4 (locked -> ask user to unlock) and 3 (ambiguous -> ask which device).
- CLI installed to `~/.local/bin/iphone-screenshot` via `make install-cli`; the bash script is
  retired (legacy copy stays until the Swift CLI is verified).
- No MCP: CLI + skill is sufficient.

## Dependencies

- swift-argument-parser (CLI only), CornucopiaCore (logging; `branch: "master"`), Shark (build
  phase, app target only). No other third-party code in the Kit.

## Distribution

- v1: build from source (`make install` copies app to /Applications, CLI to ~/.local/bin).
- Later: signed + notarised zip and a Homebrew cask/formula in `homebrew-formulae`.
- App Sandbox must stay OFF (it launches `xcrun`/`devicectl`); hardened runtime ON.
  Document this prominently since it rules out the Mac App Store.

## Makefile targets

`help` (default), `generate`, `build` (package + app), `cli`, `test`, `run`, `install`,
`install-cli`, `list-devices`, `clean`.

## Milestones

1. Package skeleton, Kit with JSON parsing + error mapping + unit tests (fixtures taken from
   real `devicectl` output, device names/UDIDs anonymised).
2. CLI on top of the Kit; verify against real devices (unlocked M16/M17, locked LM15pro).
3. App target: model, menu, capture, last-capture row, settings, localisation, HIG.md.
4. Skill/AGENTS.md update, README, MIT license, publish `mickeyl/PNGuin` (public, `master`).

## Validation

- Unit tests (`swift test`) for parsing, name/UDID matching, error classification, filenames.
- Real-device: capture on a ready device, locked device (exit 4), unknown device (exit 3),
  `list --json` schema.
- App: build, launch, open menu, capture; visual check Light/Dark and German string lengths.
  (No synthesised clicks per house rules; the user does the interactive pass.)

## Risks / open points

- `devicectl` output schema is not a documented contract -> parse defensively, fixture tests,
  clear `devicectlMissing`/`schemaChanged` errors.
- iOS 26 devices: capture works only while unlocked with a mounted DDI (seen as error 12040
  on a locked device). Needs a retest once unlocked.
- Wi-Fi-only devices appear as `connected` via localNetwork; capture latency may be higher.
- Multi-display devices (iPhone Duo) expose `--display-unique-id`; v1 captures the default
  display, a display picker is a possible follow-up.
