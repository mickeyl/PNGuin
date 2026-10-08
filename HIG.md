# ScreenGrab – Design Notes

Source of truth in code: `App/ScreenGrab/Theme/Theme.swift`.

## Appearance
Light, Dark and System (the app follows the system; no manual selector). Only semantic system
colours are used: `.primary`/`.secondary` text, `Color.accentColor` selection tint (15 % opacity),
`.green` ready, `.orange` locked, `.secondary` unreachable/unknown, `.red` error text.

## Typography roles (`Font` extensions)
| Role | Font | Use |
| --- | --- | --- |
| `rowTitle` | body, medium | device name |
| `rowDetail` | caption | OS · availability, saved file name, links |
| `statusNote` | callout | empty/locked/unreachable notes, errors |
| `fieldLabel` | callout | settings, footer |

## Metrics (`Metrics`)
Popover width 340, inset 12, row gap 8, section gap 12, row height 44, icon column 28
(symbol right-aligned, text left-aligned), preview height 320 (corner radius 14), thumbnail 44.

## Behaviour
- The popover is the only UI (`LSUIElement`, no Dock icon, no windows).
- Rows are ordered: ready devices first, then most recently used (by last screenshot), then by name.
- Row tap = select device (loads its preview); camera button = save a screenshot.
- Preview is captured into `~/Library/Caches/ScreenGrab/previews`, never into the output folder.
- Preview is shown Lanczos-downsampled to its exact backing pixels (`SharpImage`); click copies it
  ("Copied" badge), drag exports a PNG named like a regular capture.
- All user-visible strings live in `en.lproj`/`de.lproj` and are accessed as `R.L.*` (Shark).
