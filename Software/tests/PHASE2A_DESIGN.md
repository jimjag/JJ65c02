# Phase 2a design: regression tests for the miniOS menu, Wozmon, MilliForth and Supermon+

Extends the Phase 1 suite (`tests/PHASE1_DESIGN.md`, `tests/README.md`). Same
purpose: catch regressions. Expected values pin what the current ROM does; they
are not derived from the programs' documentation. Phase 2b (XMODEM and
Intel-HEX loaders) is out of scope: both talk through `TTY_*` (the ACIA serial
path) and the emulator has no serial device, so 2b first needs an emulator
change and gets its own design.

## Scope

In: the main menu (`minios.s`), Wozmon (`wozmon.s`), MilliForth
(`milliforth.s`), Supermon+ (`supermon.s`). Behavioural depth, not smoke and not
exhaustive: roughly 40-60 tests.

Out: ROM and emulator changes (tests only), the loaders, sound, EhBASIC
(Phase 1), TTY/serial mode.

All four programs use the same console path as EhBASIC: keys in through the
emulated PS/2/VIA port, text out through `$A800`, tee'd to the `-o` console
log. The Phase 1 `EmulatorSession` works unchanged.

## Components

- `tests/minios_session.py`, `MenuSession(emu)`:
  - `boot()`: wait for the `OK> ` menu prompt, keep the text as `boot_output`.
  - `enter(key, banner)`: press a menu key, wait for the program's banner.
  - `back_to_menu(...)`: leave through the program's own exit and wait for
    `OK> `. Exits: Wozmon `Q`, MilliForth `bye`, Supermon `X`.
  - `broken`: set on any `EmulatorError`, as in `BasicSession`.
  - Uses `EmulatorSession.type_text` and `wait_for`. `BasicSession` is not
    changed.
- `tests/minios/conftest.py`: module-scoped fixtures `menu`, `wozmon`, `forth`,
  `supermon`, plus a function-scoped `fresh_menu`. Each module boots once; each
  test enters the program and leaves it, so state never leaks. A broken or dead
  session is replaced before the next test.
- `tests/minios/test_menu.py`, `test_wozmon.py`, `test_forth.py`,
  `test_supermon.py`; goldens in `tests/minios/golden/`.

## State reset between tests

Re-entering from the menu resets each program, so there is no `NEW` equivalent:
`FORTH_main` re-initialises the dictionary, `WOZMON` and `SUPER_main` start
clean, judging from the entry points. Unconfirmed until a test defines a Forth
word, exits, re-enters, and checks the word is gone.

## What is tested

- **Menu:** each option 1-9 and `A` reaches its screen; an invalid key redraws
  the menu (`minios.s` `bra @start`); the menu text is pinned by golden.
  Options 1 and 2 (loaders) are not entered; they belong to 2b.
- **Wozmon:** examine an address, block examine (`.`), store (`:`), run (`R`)
  a stored routine, lower-case input upper-cased, `Q` returns to the menu.
- **MilliForth:** the vocabulary is `tty bye abort .S .R dump words . 2/ exec
  :$ ;$ key emit ! nand + @ 0# s@ ; : exit`. Tests cover arithmetic built from
  `nand`/`+`/`2/`/`0#`, stack display, `!`/`@`, `:`/`;` definitions, `words`,
  `dump`, `emit`, `bye`.
- **Supermon+:** commands `A C D F G H J M R T X . > ;` and the base
  conversions `$ + & %`. Register display, memory dump, fill, compare,
  transfer, hunt, modify memory and registers. Assemble then disassemble a
  sample of opcodes chosen to cover every addressing mode, including the
  `RMBn`/`SMBn`/`BBRn`/`BBSn` forms. `X` returns to the menu.

## Coverage guards

Modelled on `tests/basic/test_keyword_coverage.py`:

- Supermon: parse the `KEYW` string under `ENABLE_ASSEMBLER` and fail if a
  command letter has no test and no `EXCLUDED` entry. `G` and `J` execute code
  and start excluded unless a test with a tiny program is practical.
- MilliForth: parse the `def_word` names and apply the same rule.
- Each guard has a test that its parse found the expected entries, so a parser
  that silently returns nothing cannot pass.

## Rules carried over

Upper-case input only; output read only from the console log; expectations pin
current behaviour; `sim-minios.rom` only; goldens refreshed with
`--update-golden` and reviewed by hand; the driver stays at `LINES=60`.

## Open items

Unverified; each is settled by measurement before the work that depends on it:

1. **Echo.** `type_text` requires each typed character to be echoed exactly.
   Wozmon and Supermon upper-case their input, and Supermon pre-fills the next
   `A <addr>` prompt after each assembly. Check that echo-confirmed typing works
   in all three programs. Fallback: type upper case only, send only the
   instruction after a pre-filled prompt, or wait for a program-specific prompt
   instead of per-key echo.
2. **Speed.** Per-key cost in each program is unmeasured. The 5-8 minute
   estimate for the suite is a guess until measured.
3. **Reset.** That re-entry resets each program (see above).
4. **Exit paths.** That Wozmon `Q`, MilliForth `bye` and Supermon `X` each
   return to a working menu in the SIM build.
