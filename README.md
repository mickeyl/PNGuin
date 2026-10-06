<p align="center">
  <img src="assets/logo.png" alt="ScreenGrab logo" width="160">
</p>

<h1 align="center">ScreenGrab</h1>

A macOS menu-bar app and a CLI (`iphone-screenshot`) that list your paired iPhones and iPads and
capture their screens, built on `xcrun devicectl` (Xcode 27 or later). No tunnel daemon, no sudo.

- **Menu bar**: see all paired devices with their state (ready, locked, not reachable), get a
  preview of the selected device when you open the menu, take a screenshot with one click.
- **CLI**: scriptable, prints the PNG path, meaningful exit codes. Built so that an AI agent can
  take a screenshot of your iPhone and look at it.

## Build and install

```sh
make help          # all targets
make install-cli   # iphone-screenshot -> ~/.local/bin
make install       # ScreenGrab.app -> /Applications (needs xcodegen, shark; team in App/Config/Local.xcconfig)
```

## CLI

```sh
iphone-screenshot                       # the only ready device, saved to ~/Desktop
iphone-screenshot list [--json]         # name, udid, ready|locked|unreachable, os
iphone-screenshot --device "My iPhone" --output-dir /tmp --name home.png
```

Exit codes: 0 ok, 1 capture failed, 2 usage, 3 device not found or several ready, 4 device locked,
127 devicectl missing.

## Notes

- The app cannot be sandboxed (it runs `xcrun devicectl`), so it is not Mac App Store material.
- Devices must be paired and trusted, with Developer Mode enabled. A locked device cannot be captured.

See [PLAN.md](PLAN.md) for the design.

## License

MIT
