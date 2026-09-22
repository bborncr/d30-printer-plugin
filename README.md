# D30 Label Printer — Omarchy shell plugin

A bar widget for printing quick text labels on a Phomemo D30 label maker
over Bluetooth. Click the tag icon (or hit a keybinding), type, watch the
live preview, press Enter. Default label size is 40 × 12 mm.

## Requirements

- Omarchy shell (Quickshell based bar)
- The D30 paired once in Bluetooth settings (it shows up as `D30`)
- `python3` (part of the base system)
- `python-pillow` — **not installed by Omarchy by default**:

  ```bash
  omarchy pkg add python-pillow
  ```

No extra Bluetooth libraries are needed: the driver uses the Python stdlib
RFCOMM socket, channel 1. The plugin never uses `sudo`, never installs a
service, and writes nothing outside `$XDG_RUNTIME_DIR` (a preview PNG).

## Install

```bash
omarchy plugin add https://github.com/bborncr/d30-printer-plugin.git --enable
```

`--enable` places the widget in the bar and writes the entry to
`~/.config/omarchy/shell.json`. Drop the flag to add it without enabling,
then run `omarchy plugin enable io.github.bborncr.d30-label` later.

## Uninstall

```bash
omarchy plugin disable io.github.bborncr.d30-label
omarchy plugin remove io.github.bborncr.d30-label
```

`disable` removes the widget from the bar in `~/.config/omarchy/shell.json`;
`remove` deletes `~/.config/omarchy/plugins/io.github.bborncr.d30-label`.
Nothing else is left on the system — the plugin creates no config files,
services or state of its own. `python-pillow` stays installed; remove it
with `sudo pacman -Rs python-pillow` if nothing else needs it.

## Use

- Left click the tag icon in the bar to open the panel.
- Type the label. `\n` in the text starts a new line.
- Pick a size (40, 30, 50 or 22 mm long, all 12 mm tape) and the copies.
- Enter or "Print label" prints. Esc closes.

Bind it to a key in `~/.config/hypr/bindings.lua`, for example:

```lua
o.bind("SUPER SHIFT", "L", "Print a D30 label", "omarchy-shell io.github.bborncr.d30-label toggle")
```

## Settings

Set inline on the widget entry in `~/.config/omarchy/shell.json`, or via
Setup > Plugins:

| key           | default | meaning                                             |
|---------------|---------|-----------------------------------------------------|
| `defaultSize` | `40x12` | Size selected when the panel opens                  |
| `address`     | `""`    | Printer MAC. Empty = first paired device named D30  |
| `flip`        | `false` | Rotate the print 180° if labels come out upside down|
| `font`        | `""`    | Path to a `.ttf`. Empty = Liberation Sans Bold      |

## Command line

The driver works on its own too:

```bash
bin/d30-print print --size 40x12 --copies 2 -- "Hello"
bin/d30-print preview --out /tmp/label.png --scale 3 -- 'Two\nlines'
bin/d30-print image --size 40x12 logo.png
```

## Development

Work on a checkout in place by symlinking it into the plugins directory:

```bash
ln -s /path/to/d30-printer-plugin ~/.config/omarchy/plugins/io.github.bborncr.d30-label
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.bborncr.d30-label
```

The shell watches the plugins directory with `inotifywait -r`, which does not
follow symlinks, so edits to a symlinked checkout need `omarchy restart shell`
rather than a hot reload.

## Protocol notes

203 dpi, 96 dot print head (12 mm). The label is rendered in reading
orientation, rotated 90°, and sent as one `GS v 0` raster after the
initialisation packets captured from the Phomemo Android app.

## License

[MIT](LICENSE)
