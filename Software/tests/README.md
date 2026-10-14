# EhBASIC and miniOS regression tests

A pytest suite that drives EhBASIC and the other miniOS programs through the `x65c02` emulator and,
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
| Full suite | 199 tests in 795 s (13 min); run it in the background |
| `tests/harness` + `tests/minios` | 94 tests in 224 s |
| Sim tier | about 34 s |

Because each statement is slow, `basic` is module-scoped: one booted session per
test module, with `NEW` issued before each test.

## Tiers

| Path | What it asserts |
| --- | --- |
| `tests/harness/` | `EmulatorSession` against `fake_emu.py`, a stand-in emulator (`FAKE_EMU_MODE`: `drop-first`, `die`, `mute`, `dup`, `late`). No ROM needed. |
| `tests/basic/` | Text the ROM prints, read from the emulator's `-o` console log. Numeric, strings, control, data, errors, escapes, goldens, boot text. |
| `tests/minios/` | Console text of the miniOS menu, Wozmon, MilliForth and Supermon+, through `tests/minios_session.py`. See "miniOS tier". |
| `tests/sim/` | Pixels in a BMP snapshot from the headless sim, marked `sim`. |

`test_keyword_coverage.py` fails when an EhBASIC keyword has no test and no
entry in its `EXCLUDED` table (with a reason). A new keyword in `ehbasic.s`
therefore needs a test.

## miniOS tier

`tests/minios/` has one module per program (`test_menu.py`, `test_wozmon.py`,
`test_forth.py`, `test_supermon.py`), two coverage guards and `test_sessions.py`
for the session classes. `conftest.py` boots one menu per module; the `wozmon`,
`forth` and `supermon` fixtures enter their program from it and `leave()` after
each test. `menu` gives the menu session itself.

```
uv run --no-env-file pytest -q tests/harness tests/minios
uv run --no-env-file pytest -q tests/minios/test_wozmon.py
```

- **Echo differs per program.** Wozmon echoes Enter as `\r\n` and upper-cases
  what it echoes; MilliForth and Supermon+ echo Enter as a bare `\r`; menu keys
  are not echoed. Each session class carries the matching `echo_for`, passed to
  `type_text`.
- **Idle markers.** Wozmon and Supermon+ are synced by sending a backspace and
  waiting for its echo (`\x08\r\n` and `\x08`). ESC cannot be used: the
  emulator swallows it as a GUI key. MilliForth stores a backspace in its input
  buffer, so `ForthSession.eval` counts `\r\nok> ` prompts instead, one per
  executed word (`prompts_for`; an unknown word aborts after one prompt, so pass
  `prompts=`).
- **Dispatch only.** The emulator runs about 15K cycles/s. Menu options 3 (run
  program), 4 (clear RAM) and 5 (RAM test) would take about 9 min, 100 s and over
  an hour, so they are tested for dispatch only. Sound, the SEI/CLI race and the
  boot RAM test are not testable on the sim build.
- **State.** MilliForth: never store to `$0022` (`s@`, the `stat` cell); `$0044`
  (`s@ s@ +`) is the scratch cell. Supermon+ registers persist across re-entry,
  so set them with `;` before asserting a register line.
- **Guards.** `test_forth_coverage.py` parses `def_word` entries in
  `milliforth.s`; `test_supermon_coverage.py` parses the command table in
  `supermon.s`. Each fails for a word or command that no test exercises and that
  has no reason in its `EXCLUDED` table.

To add a word or command, add a test that calls `forth.eval("...")` or
`supermon.line("...")` with a literal first argument (the guards scan those call
shapes), then run the guard.

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
