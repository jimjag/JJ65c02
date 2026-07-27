# Test harness

## x65c02-headless.py

Drives the ncurses `x65c02` emulator through a pty for scripted, headless
testing of minios ROMs. Feeds keystrokes from a script file, captures the
TUI output, and writes an ANSI-stripped transcript for grepping.

```
./x65c02-headless.py ROM SCRIPT -o transcript.txt [--speed s|f|n]
                     [--boot SECS] [--deadline SECS] [--char-delay SECS]
```

Script format: one `<delay-seconds> <keys>` step per line; `\r` = Enter,
`\e` = ESC; `#` comments allowed. Each step types its keys then waits.

The emulator binary defaults to `../Emulator/x65c02` relative to this
directory; set `$X65C02` to point at a different build.

Things learned the hard way:

- Use `sim-minios.rom` (the `make sim` target, exactly $B000-$FFFF),
  not `minios.rom` — the full flash image loads at the wrong base and
  the CPU lands in a NOP slide.
- The emulator ignores SIGTERM; the driver always SIGKILLs it on exit.
- minios menu: 7 = EhBASIC (answer its `[C]old/[W]arm ?` prompt with
  `C`), 8 = MilliForth, 9 = Supermon+ (`X` exits to menu).
- Keys can get dropped if typed too fast; `--char-delay 0.2` is
  reliable, the 0.05 default is not always.
- The transcript is redraw soup: every screen repaint duplicates text,
  and long lines can be clipped by the terminal pane. Grep for expected
  substrings and compare counts/forms against a baseline-ROM run of the
  same script rather than expecting a clean sequential log.
