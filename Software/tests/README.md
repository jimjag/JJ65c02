# EhBASIC regression tests

A pytest suite that drives EhBASIC in miniOS through the `x65c02` emulator and,
for graphics, the headless Pico sim. Its job is to catch regressions: expected
values pin what the current ROM does, they are not derived from the EhBASIC
source. A failing test means behaviour changed; decide whether that is a bug
before touching the expectation.

## Running

Run from `Software/`. The shell here exports `UV_ENV_FILE=./.env`, so a bare
`uv run` fails; pass `--no-env-file`.

```
uv run --no-env-file pytest -q                      # everything
uv run --no-env-file pytest -q -m "not sim"         # skip the 8 tests that need the sim build
uv run --no-env-file pytest -q tests/harness        # driver unit tests only
uv run --no-env-file pytest -q tests/basic/test_control.py
uv run --no-env-file pytest -q -k swap
```

If `ca65` fails with `Cannot open include file 'generic.mac'`:
`export CA65_INC=/Users/jim/src/6502/cc65/asminc`.

The `rom` fixture runs `make sim` in `minios/src` and `emulator_bin` runs
`Emulator/build`, once per session. Needs cc65, a C compiler and ncurses. The
sim tier builds `pico-code/sim` through `build.sh dump-build`; it needs no SDL.

| Variable | Effect |
| --- | --- |
| `MINIOS_ROM=path` | test this `sim-minios.rom` instead of building one (e.g. a pre-fix ROM) |
| `X65C02=path` | test with a different emulator binary (baseline comparison) |

## Timings

Measured on this machine.

| | |
| --- | --- |
| Boot to `Ready` | about 3.4 s |
| One BASIC statement | about 1.75 s (redraw-bound in the emulator) |
| Full suite | about 9-12 min; run it in the background |
| Sim tier | about 34 s |

Because each statement is slow, `basic` is module-scoped: one booted session per
test module, with `NEW` issued before each test.

## Tiers

| Path | What it asserts |
| --- | --- |
| `tests/harness/` | `EmulatorSession` against `fake_emu.py`, a stand-in emulator (`FAKE_EMU_MODE`: `drop-first`, `die`, `mute`, `dup`, `late`). No ROM needed. |
| `tests/basic/` | Text the ROM prints, read from the emulator's `-o` console log. Numeric, strings, control, data, errors, escapes, goldens, boot text. |
| `tests/sim/` | Pixels in a BMP snapshot from the headless sim, marked `sim`. |

`test_keyword_coverage.py` fails when an EhBASIC keyword has no test and no
entry in its `EXCLUDED` table (with a reason). A new keyword in `ehbasic.s`
therefore needs a test.

## Adding a case

Language tests are tables of `(statement, expected output)` fed to `basic.eval`:

```python
("PRINT 7-10", "-3\n"),
```

Add a row to `CASES` in the matching `tests/basic/test_*.py`. Multi-line
programs go through `basic.run(program)`.

Golden programs: drop `NAME.bas` in `tests/basic/golden/`, run

```
uv run --no-env-file pytest -q tests/basic/test_golden.py --update-golden
```

and review the `NAME.out` diff by hand. Do not use `--update-golden` to make a
failure go away.

Sim tests take the `sim_basic` fixture, run a graphics statement, then call
`eventually()` around a check on `sim.snapshot()`.

## Rules

- **Upper-case BASIC.** Tests type upper-case only, apart from text inside
  string literals.
- **Expectations pin current behaviour.** Values such as `1.23457E+08` come from
  running the ROM.
- **Sim tests check shape, not position.** Console text fills the 640x480
  screen, so each line feed scrolls the framebuffer, graphics included. Assert
  pixel count, bounding-box size and x origin, never a fixed y.
- **Read program output from the console log, never the pty transcript.** See
  `../Harness/README.md`.
- Test `sim-minios.rom`, never `minios.rom`.
