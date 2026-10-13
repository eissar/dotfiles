# Pi configuration notes

## Hardware cursor: compatibility with Herdr copy mode

`pi/.pi/agent/settings.json` sets `"showHardwareCursor": true` so Herdr can
initialize its copy-mode cursor at Pi's input cursor instead of at the
bottom-left of the pane. This applies to the binding configured to enter
Herdr copy mode (including a custom leader + `]` binding; current upstream
Herdr defaults to prefix + `[` ).

Pi emits normal terminal cursor-movement sequences while rendering, but its
TUI defaults to hiding the terminal's hardware cursor and drawing a software
cursor. Its internal `CURSOR_MARKER` (`\x1b_pi:c\x07`) tells Pi's renderer where
the focused component's cursor belongs; the renderer extracts and strips
that marker, rather than sending it to Herdr as a cursor-reporting protocol.

Herdr already tracks cursor position by feeding the child application's PTY
output into its embedded Ghostty terminal emulator. It does not need to send
a DSR query (`ESC[6n`) or receive a separate editor-cursor notification.
However, Herdr's `enter_copy_mode()` only uses the rendered frame's cursor if
it is **visible** and inside the focused pane's inner rectangle. When Pi
hides the hardware cursor, Herdr rejects that position and falls back to
column zero of the viewport's last row.

Enabling the hardware cursor makes Pi's input cursor available as a visible
terminal cursor, allowing Herdr to use it for copy-mode initialization. The
position is converted from frame coordinates into pane text coordinates by
subtracting the pane's inner origin and adding its viewport/scrollback row
offset. This changes cursor presentation, not Pi's text-selection protocol.
It only helps when Pi actually has a visible cursor in the focused pane;
Herdr can still fall back when no such cursor exists. Re-entering copy mode
for a pane that already has a copy-mode session preserves the existing
copy-mode cursor rather than initializing it again.

Implementation checked against Herdr commit `212b710`:
- `src/client/shell/copy_mode.rs`: `enter_copy_mode()` and visibility check.
- `src/pane/terminal.rs`: PTY parsing and Ghostty cursor state.
- Installed `@earendil-works/pi-tui/dist/tui.js`: hardware-cursor default and
  internal cursor-marker extraction.

The explanation lives here rather than as comments in `settings.json`, so
the settings file remains valid JSON. On this machine,
`~/.pi/agent/settings.json` resolves to the dotfiles copy, so this setting
also updates the live configuration. Restart Pi if the running session does
not pick up the change.
