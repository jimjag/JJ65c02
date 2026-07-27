# Test harness

## x65c02-headless.py

Drives the ncurses `x65c02` emulator through a pty for scripted, headless
testing of minios ROMs. Feeds keystrokes from a script file, captures the
TUI output, and writes an ANSI-stripped transcript for grepping.

```
./x65c02-headless.py ROM SCRIPT -o transcript.txt [--raw raw.bin]
                     [--speed s|f|n] [--boot SECS] [--deadline SECS]
                     [--char-delay SECS]
```

Run it from the repository root so the relative ROM paths below work.

| Option | Meaning |
| --- | --- |
| `--speed s\|f\|n` | sprint / fast / non-stop. `n` never polls the keyboard, so a script that types anything must use `s` or `f`. |
| `--boot SECS` | wait after launch before typing the first step |
| `--deadline SECS` | hard wall-clock limit; the emulator is killed after this |
| `--char-delay SECS` | pause between keystrokes |
| `--raw FILE` | also save the unmodified pty bytes |
| `-o FILE` | ANSI-stripped transcript (default `transcript.txt`) |

Exit status is 0 if the script ran to completion, 1 if the emulator died
early or the deadline was hit. The closing line also prints `emulator ok`
or `emulator DIED EARLY`.

Script format: one `<delay-seconds> <keys>` step per line; `\r` = Enter,
`\e` = ESC; `#` comments and blank lines ignored. Each step types its keys
then waits. A boot-only script is a delay with empty keys:

```
# boot.txt - just let it run for 3 seconds
3.0
```

The emulator binary defaults to `../Emulator/x65c02` relative to this
directory; set `$X65C02` to point at a different build. That override is
what makes the baseline comparison below possible.

## Terminal size

The emulator GUI is a fixed-size layout and needs **at least 60 rows by 120
columns**. The harness sets `LINES=60`/`COLUMNS=132` for exactly this reason.

Below the minimum the emulator now refuses to start:

```
x65c02: terminal is 50x132, but the GUI needs at least 60x120 (rows x cols).
```

That guard exists because the failure it replaced was silent. `newwin()`
does **not** bounds-check a pane against the screen — a window placed past
the last row is created successfully and then clipped at refresh time. At
`LINES=50` the memory pane still drew, but only 23 of its 32 dump rows ever
reached the transcript, with no error anywhere. Do not lower `LINES` back
below 60 to "make it fit".

## Reading the transcript

**This is the part that will mislead you.** ncurses repaints
differentially: after the first frame it re-emits only the characters that
actually changed, as cursor-motion escapes plus a few digits. The harness
strips those escapes, so an in-place field that updates constantly shows up
in the transcript exactly once, followed by a soup of loose hex digits.

Measured on a 4-second sprint run producing a 14.7 MB transcript:

| Pattern | Occurrences | Why |
| --- | --- | --- |
| `cycle:` | 2 | painted once, then only changed digits |
| `PC: ` | 2 | same |
| ` Memory `, ` Terminal `, ` CPU Monitor `, ` Bus Trace ` | 2 each | static box titles |
| `Bus addr:` distinct values | 847 | pane scrolls, so every line is new output |

The only `cycle:` value present in that entire 14.7 MB transcript is
`cycle: 00000002`. **This is not evidence that the CPU is stuck** — it is
the first frame, preserved forever because later frames only rewrite the
digits that changed. A previous debugging session lost hours to exactly this
reading. The same applies to `PC:`, the registers, and the clock mode.

Rules that follow from this:

- **Never** grep the transcript for a changing value (cycle, PC, registers,
  flags). It cannot work, and a stale first-frame value looks like a freeze.
- **Do** grep panes that scroll (Bus Trace) or text that is written once and
  stays (memory dump rows, terminal output).
- To check whether the CPU is running, count *distinct* bus addresses.

## Checks that work

Each of these is verified against the current build. `$T` is the transcript.

```bash
# CPU is executing: distinct bus addresses, in the hundreds for a few seconds
grep -oE 'Bus addr:[0-9a-f]{4}' $T | sort -u | wc -l

# Memory pane is fully visible: must be 32, one row per 16 bytes of $0000-$01FF
grep -oE '0[01][0-9a-f]0  ([0-9a-f]{2} )' $T | cut -c1-4 | sort -u | wc -l

# All four panes were laid out
for t in Terminal "CPU Monitor" "Bus Trace" Memory; do
  printf '%-12s %s\n' "$t" "$(grep -c "$t" $T)"
done

# minios reached its menu (needs a longer boot; see below)
grep -c "Load" $T
```

Note the memory dump rows use **two** spaces between the address and the
first byte (`0000  00 00 ...`); a single-space regex silently matches
nothing.

A run long enough to reach the minios menu:

```bash
printf '20.0 \n' > /tmp/boot.txt
./Software/Harness/x65c02-headless.py Software/minios/src/sim-minios.rom \
    /tmp/boot.txt -o /tmp/long.txt --speed f --boot 10 --deadline 60
grep -c "Load" /tmp/long.txt     # non-zero once the menu is drawn
```

## Confirming a fix, or catching a regression

Transcripts are large and full of redraw noise, so absolute inspection is
unreliable. Compare a candidate build against a baseline build of the same
ROM and script, and diff the *counts* above rather than the transcripts.

Build the baseline from any git ref into a scratch directory and point
`$X65C02` at it:

```bash
BASE=/tmp/x65c02-base
rm -rf $BASE && cp -R Software/Emulator $BASE
git show HEAD:Software/Emulator/src/gui.c > $BASE/src/gui.c   # repeat per file
(cd $BASE && ./build)

printf '3.0 \n' > /tmp/boot.txt
ROM=Software/minios/src/sim-minios.rom
ARGS="--speed s --boot 4 --deadline 20 --char-delay 0.2"

X65C02=$BASE/x65c02 ./Software/Harness/x65c02-headless.py $ROM /tmp/boot.txt \
    -o /tmp/base.txt $ARGS
./Software/Harness/x65c02-headless.py $ROM /tmp/boot.txt \
    -o /tmp/cand.txt $ARGS
```

Then compare. A worked example — this is how the `LINES` fix was confirmed:

```bash
for f in /tmp/base.txt /tmp/cand.txt; do
  echo -n "$f memory rows: "
  grep -oE '0[01][0-9a-f]0  ([0-9a-f]{2} )' $f | cut -c1-4 | sort -u | wc -l
done
# pre-fix at LINES=50 -> 23
# post-fix at LINES=60 -> 32
```

Because the emulator has no clock and the CPU free-runs, distinct-value
counts vary slightly between runs. Treat a difference of a few percent in
`Bus addr:` counts as noise; treat a structural change (a pane title
dropping to 0, memory rows falling below 32, `emulator DIED EARLY`) as a
real regression.

## Gotchas

- Use `sim-minios.rom` (the `make sim` target, exactly $B000-$FFFF), not
  `minios.rom` — the full flash image loads at the wrong base and the CPU
  lands in a NOP slide.
- The emulator ignores SIGTERM; the driver always SIGKILLs it on exit.
- minios menu: 7 = EhBASIC (answer its `[C]old/[W]arm ?` prompt with `C`),
  8 = MilliForth, 9 = Supermon+ (`X` exits to menu).
- Keys can get dropped if typed too fast; `--char-delay 0.2` is reliable,
  the 0.05 default is not always.
- Transcripts are big — roughly 40 MB of raw pty bytes and 15 MB stripped
  for a 4-second sprint run, dominated by the Bus Trace pane. Budget disk
  space, and prefer `grep -c` over reading them.
- `Software/Emulator/build` compiles every `.c` under `src/` via
  `find src -name "*.c"`. A stray source file left in that directory will
  be picked up and can collide on `main`/`trace_emu`. Keep scratch copies
  outside `src/`.
