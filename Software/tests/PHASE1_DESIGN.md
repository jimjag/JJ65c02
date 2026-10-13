# Test suite, Phase 1: EhBASIC

Design for the first phase of an automated test suite covering minios and
pico-code. Phase 1 covers EhBASIC only.

## Goal

`uv run pytest`, run from `Software/`, boots the real `sim-minios.rom` in the
real `x65c02` emulator and verifies EhBASIC behaviour. A small second tier
pairs the emulator with the headless Pico sim and checks rendered pixels.

Success means: the suite builds what it needs, runs unattended, fails with a
readable reason, and leaves no processes or sockets behind.

## Scope

In:

- A `uv` project with pytest, rooted at `Software/`.
- An importable emulator driver with wait-for-output semantics.
- EhBASIC tests asserting on the console byte stream (console tier).
- About five smoke tests asserting on the sim framebuffer (sim tier).

Out, deferred to later phases:

- CI integration.
- Golden-image management; full framebuffer coverage.
- Sound verification beyond the escape bytes EhBASIC emits.
- `LOAD`/`SAVE` (XMODEM) and `TTY`.
- Wozmon, MilliForth and Supermon+ tests.
- Moving the sprite tests (`pico-code/tests/sprite`) under pytest.

## Layout

```
Software/
  pyproject.toml          uv project; pytest as a dev dependency; markers
  Harness/
    x65c02_session.py     EmulatorSession: pty + console-log tail
    x65c02-headless.py    existing CLI, reduced to a wrapper over the module
  tests/
    conftest.py           build and session fixtures
    basic/                console tier
    sim/                  sim smoke tier
```

## Components

### EmulatorSession (`Harness/x65c02_session.py`)

Owns one emulator process.

- Starts `x65c02` in a pty with `LINES=60`, `COLUMNS=132`, a speed flag, and
  `-o <console file>`; optionally `-p <socket>`.
- Drains the pty continuously so ncurses output never blocks the emulator.
  The pty bytes are discarded unless a transcript is requested.
- Reads program output only from the console file, which the emulator flushes
  per byte (`Emulator/src/io.c`).
- `send(keys)` writes raw keys. `type_text(text)` confirms each character's
  echo in the console log before sending the next, and resends a character
  that was not echoed. Confirmation is per character because the emulator
  holds one pending key: a probe at a fixed 0.2 s per key still lost leading
  characters of three lines out of thirteen.
- `wait_for(pattern, timeout)` blocks until the pattern appears in output
  produced after the current mark, and returns the matched output.
- `close()` sends ESC, then SIGKILLs (the emulator ignores SIGTERM).

Failure modes are distinct exceptions: timeout (carrying the tail of the
console log) and emulator exit.

`x65c02-headless.py` keeps its command line and script format and is
reimplemented on this class, so there is one pty driver in the tree.

### BasicSession (in `tests/`)

Built on `EmulatorSession`. Boots to the minios menu, selects `7`, answers
`[C]old/[W]arm ?` with `C`, waits for `Ready`.

- `eval(statement)` runs one immediate-mode statement and returns its output.
- `run(program)` enters a numbered program, runs it, returns its output up to
  the next `Ready`.
- `new()` issues `NEW` so one boot can serve many tests.

Echoed input is stripped from returned output so tests compare only what the
program printed.

### Fixtures (`tests/conftest.py`)

- `rom` (session scope): runs `make sim` in `minios/src`; returns the path to
  `sim-minios.rom`. A missing toolchain fails with the `CA65_INC` hint.
- `emulator_bin` (session scope): runs `Emulator/build`. `$X65C02` overrides
  it, as in the existing harness.
- `basic` (module scope): a booted `BasicSession`, reset with `NEW` between
  tests.
- `fresh_basic` (function scope): a newly booted session, for tests that
  depend on cold-start state.
- `sim` (function scope): see below.

Builds always run; they are incremental, and a stale ROM is a worse failure
than a slow start.

### Sim smoke tier

- The headless sim is `pico-code/sim/_sim_dump` built with
  `SIM_SOURCE=console`, so it runs the real console firmware (`pico_6502.c`).
- Each test gets its own socket in pytest's temp directory via `SIM_SOCKET`,
  and the emulator connects with `-p`. Nothing uses `/tmp/jj65c02.sock`.
- `sim_dump.c` today sleeps for a fixed time and dumps once. It gains
  dump-on-demand: on `SIGUSR1` it writes the BMP and keeps running. The file is
  sim-only, so the firmware build is unaffected.
- Tests read the BMP and assert on pixels at known coordinates. No golden
  images.
- Tests carry `@pytest.mark.sim`; `pytest -m "not sim"` needs no sim build.

## Test coverage

Console tier, one module per area:

| Module | Covers |
| --- | --- |
| `test_numeric` | arithmetic, precedence, number formatting, numeric functions |
| `test_strings` | `STR$`, `VAL`, `LEFT$`/`RIGHT$`/`MID$`, `CHR$`/`ASC`, `LEN`, `CSTR$`, concatenation |
| `test_control` | `FOR`/`NEXT`, `GOTO`, `GOSUB`/`RETURN`, `IF`, `ON` |
| `test_data` | `DIM`, arrays, `DATA`/`READ`/`RESTORE` |
| `test_errors` | error messages and that the interpreter recovers to `Ready` |
| `test_regressions` | `STR$()` aliasing after the Decss move; backspace erasing the deleted character |
| `test_escapes` | `PLOT`, `RECT`, `RECTF`, `CIRCLE`, `CIRCLEF` as exact `ESC[Z..Z` byte sequences |

Not testable here: the `SEI`/`CLI` stack-flush fix is an interrupt race with no
deterministic trigger, and the MSTKP initialisation order has no effect on the
SIM build (the RAM test is compiled out). EhBASIC has no sound statement; sound
reaches the Pico only as a printed escape, so it is out of this tier.

Sim tier: text at an expected cursor cell, `PLOT`, `RECT`, a colour change,
screen clear.

## Error handling

- Every wait has a timeout. A timeout reports the pattern awaited and the tail
  of the console log.
- Emulator death is reported as such, not as a timeout.
- Fixture teardown kills the emulator and sim and removes the socket, on
  failure as well as success.

## Open items

Unverified at design time. Each is settled by measurement at the start of
implementation, before the work that depends on it:

1. `_sim_dump` builds with `SIM_SOURCE=console` and accepts an emulator
   connection.
2. Echo-confirmed typing is drop-free in non-stop mode. Fallback: a
   per-character delay.
3. Boot-to-`Ready` time. If it is small, the module-scoped `basic` fixture can
   become function-scoped and `NEW`-based reset can go.
