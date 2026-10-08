# Simulators – Implementation Plan

Capture running iOS/iPadOS simulators with the same menu-bar app and CLI, next to physical devices.
Target version: **0.9.0**.

Status: implemented in 0.9.0. Deviations from the plan below: the simulator poll lives in `AppModel`
(too small for its own monitor type) and runs while the menu is open regardless of the tab (cheap,
keeps the count current); the TSV of `list` keeps its four columns (the JSON gains `source`); usage
errors exit with 64 (ArgumentParser), as they always did – the help text said 2. Measured: status-bar
overrides show up in the very next screenshot, no delay needed.

## Decisions (agreed)

- The popover gets an always-visible segmented control: **Devices | Simulators**.
- Simulator extras ship in this version: **clean status bar** and **rounded-corner mask**.
- Only iPhone and iPad simulators (no watchOS, tvOS, visionOS).
- The CLI stays feature-synchronous with the app.

## Verified facts (Xcode 27, simctl)

- `xcrun simctl list -j` (~0.3 s) returns `devices`, `devicetypes`, `runtimes`, `pairs` in one call.
  - `devices`: keyed by runtime identifier (`com.apple.CoreSimulator.SimRuntime.iOS-27-0`), entries have
    `name`, `udid`, `state` (`Booted`, `Shutdown`, …), `isAvailable`, `deviceTypeIdentifier`, `lastUsedAt`.
  - `devicetypes[].productFamily` is `iPhone` / `iPad` (keyed by `identifier`), the reliable kind source.
  - `runtimes[]` maps `identifier` → `platform` (`iOS`) and `version` (`27.0`).
- `xcrun simctl io <udid> screenshot [--mask=ignored|alpha|black] <file>` takes ~0.7 s and writes a
  native-resolution PNG (1206x2622 for an iPhone 18 Pro, same as a physical iPhone 16 Pro).
  `--mask=alpha` yields transparent rounded corners (`hasAlpha: yes`).
- `xcrun simctl status_bar <udid> override --time … --batteryLevel … …`, `… clear`, `… list`.
  `list` prints a header only when no override is active.
- simctl talks to CoreSimulator, not CoreDevice; the CoreDevice wedge (see CLAUDE.md) should not apply.
  To verify: simctl calls while devicectl probes run.

## Core (PNGuinKit)

- `Device` gains `source: Source` (`.physical`, `.simulator`); Codable output gains a `source` field
  (additive, so existing JSON consumers keep working). Booted simulators are always `.ready`.
- `Xcrun` runner: generalise `Devicectl.run` to `Xcrun.run(tool:arguments:)`; `Devicectl`/`Simctl` stay
  thin wrappers so call sites read the same.
- `SimulatorList.parse(Data) throws -> [Device]`: booted + available + platform iOS + productFamily
  iPhone/iPad; `osVersion` from the runtime. Defensive parsing, fixture tests (trimmed real JSON).
- `SimulatorCenter.simulators() async throws -> [Device]` (sorted by name, like `DeviceCenter`).
- `CaptureOptions` (`cleanStatusBar: Bool`, `maskCorners: Bool`), ignored for physical devices.
- `Screenshotter.capture(_ device: Device, to:, options:)` dispatches: devicectl for physical, simctl
  for simulators. The UDID-only entry point stays for the CLI's existing path.
- `StatusBar` (simulator only):
  - Clean values: `--time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active
    --cellularBars 4 --operatorName '' --batteryState charged --batteryLevel 100`.
  - **Never clobber the user's own overrides:** if `list` shows an override we did not set, leave the
    status bar alone and capture as is.
  - Overrides need a moment to render; measure the needed delay (expected a few hundred ms) and wait
    once after applying, not before every frame.
- New error: `CaptureError.notBooted` (simulator shut down between list and capture), CLI exit code 3
  (same family as "not found").

## App

- `AppSettings`: `source` (last segment), `cleanStatusBar`, `maskCorners` (both default off; they
  change what a capture looks like, so they are opt-in).
- Split `AppModel` (already 220 lines) before adding to it:
  - `DeviceMonitor` – physical list + sequential probing (today's logic, unchanged).
  - `SimulatorMonitor` – polls `simctl list` every 2 s; no probing needed.
  - `AppModel` – orchestrates: active source, per-source selection (and "manual" flag), preview, capture.
- Only the active segment is polled; switching segments starts/stops the matching monitor.
- **WYSIWYG for copy/drag:** click-to-copy and drag hand out the *preview* image, so for simulators the
  preview itself is captured with the same options (mask + clean status bar).
  - Clean status bar is applied once when a simulator becomes the previewed one and cleared when it
    stops being previewed (segment switch, selection change, popover closed, app quit) – not per frame,
    which would make the Simulator window flicker between real and fake status bars.
  - Crash safety: the UDIDs we overrode are recorded in UserDefaults and cleared on next launch.
- Segmented control: `Picker(.segmented)` with counts, e.g. `Devices (5)` / `Simulators (3)`.
- Empty Simulators segment: note plus an "Open Simulator" button (`open -a Simulator`).
- Simulator rows: same `DeviceRow`, icon `iphone`/`ipad`, detail `iOS 27.0 · Simulator`.
- Settings: a "Simulators" group with the two toggles.
- MRU ordering and `lastUsed` work unchanged (simulator UDIDs are distinct from device UDIDs).
- New strings (en + de): segment titles with counts, simulator empty state and button, the two
  settings toggles, the "Simulator" detail label.

## CLI

- `iphone-screenshot --simulator [--device NAME|UDID] [--clean-status-bar] [--mask-corners]`
  - Without `--device`: the only booted iPhone/iPad simulator; several → ambiguous (exit 3).
  - `--clean-status-bar` applies the override, captures and clears it again (respecting existing
    user overrides, as in the app). `--mask-corners` maps to `--mask=alpha`.
  - The two flags without `--simulator` are a usage error (exit 2) rather than silently ignored.
- `iphone-screenshot list --simulators` (booted simulators; same TSV/JSON format, `source` column/field).
- Without `--simulator` everything behaves exactly as in 0.1.x, so existing scripts don't change.
- Help text and exit-code discussion updated; the Homebrew formula follows the 0.9.0 tag.

## Tests

- `SimulatorList` fixtures: booted iPhone + iPad kept; shutdown, unavailable, watch/tv/vision dropped;
  unknown schema rejected.
- `StatusBar` parsing of `list` output (no override vs. foreign override).
- `DeviceSelector` within the simulator pool (single booted, ambiguous, by name/UDID).
- Manual: concurrent simctl + devicectl, status-bar delay, mask output, segment switching, crash recovery.

## Docs

README (simulator section, CLI examples), HIG.md (segmented control, settings group), CLAUDE.md
(simctl facts, status-bar ownership rule), PLAN.md cross-reference.

## Out of scope / later

- Light + dark capture in one go (`simctl ui <udid> appearance`).
- watchOS/tvOS/visionOS simulators.
- Separate: stop `Package.resolved` from flip-flopping between the SwiftPM and Xcode resolutions.
