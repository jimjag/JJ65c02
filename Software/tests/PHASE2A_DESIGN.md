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
  `supermon`. No function-scoped `fresh_menu`: nothing needs it. Each module boots once; each
  test enters the program and leaves it, so state never leaks. A broken or dead
  session is replaced before the next test.
- `tests/minios/test_menu.py`, `test_wozmon.py`, `test_forth.py`,
  `test_supermon.py`; goldens in `tests/minios/golden/`.

## State reset between tests

Re-entering from the menu resets MilliForth: `FORTH_main` re-initialises the
dictionary, so there is no `NEW` equivalent (measured, Measured results item
3). Wozmon is not measured for re-entry beyond RAM contents surviving.
Supermon+ does **not** reset its saved registers: after `; 0500 00 11 22 33 FF`,
`X` and re-entry, both the banner register line and `R` still show
`; 0500 00 11 22 33 FF ` (measured, transcripts below). Supermon tests must not
assume a zero register line on entry.

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

## Measured results

Probe run against `sim-minios.rom` through `Harness/x65c02_session.py`
(throwaway script, not committed). Every "Facts established before planning"
entry in the implementation plan was checked; the transcripts are in the table below.

1. **Echo.** Menu keys are not echoed. Typed CR echoes as `\r\n` in Wozmon, as
   `\r` only in MilliForth and Supermon+. Wozmon upper-cases before echoing, so
   typing `a` echoes `A`: the default `type_text` echo (`ch` / `\r\n`) works
   for upper-case Wozmon input only. MilliForth and Supermon+ need a
   CR-to-`\r` echo; any lower-case Wozmon input needs an upper-casing echo. So
   `type_text` needs one pluggable echo option (Task 2). Per-key echo
   confirmation worked in all three programs with no dropped or mismatched
   keys. Supermon's pre-filled `A <addr> ` prompt needs no special handling:
   wait for it with `wait_for` and type only the instruction.
2. **Speed.** Typing costs about 30-50 ms per character. Boot to `OK> ` is 1.8 s, entering Wozmon 0.2 s,
   `Q` back to the menu 0.9 s. With roughly 50 tests at about 20 typed
   characters each plus enter/exit, the suite adds about 2-3 minutes, well
   under the earlier 5-8 minute guess.
3. **Reset.** After `bye` and re-entry, `foo` (defined with `: foo s@ ;`)
   produces one bare prompt and `.S` prints `S0498 00 ` (empty): the word is
   gone and the stack is empty.
4. **Exit paths.** `Q` (Wozmon), `bye` (MilliForth) and `X` (Supermon+) each
   reach `OK> ` with the menu redrawn. Wozmon `R` of a routine ending in `RTS`
   also lands in the menu.
5. **Idle markers (gate passed).** Wozmon BS gives `\x08\r\n` and Supermon BS
   gives `\x08` alone. Each marker appeared exactly once per probe and never
   earlier: the console log holds 4, 3 and 17 BS bytes for the Wozmon, second
   Wozmon and Supermon sessions, equal to the number of probes sent.
6. **Forth scratch cell `$0044`.** Forth's zero page runs `$21` (`UseTTY`)
   to `$41` (`tail`); the data stack lives in page 4 (`.S` prints `S0498`), not
   zero page. Nothing Forth uses is at `$44-$45`, and `sim-minios.lbl` has no
   symbol there. Measured: `s@ s@ + s@ s@ + ! s@ s@ + @ .` stores and reads back
   `0044`. Task 6 keeps `$0044`. Do not use `$0022`: `s@` pushes that address,
   which is `stat` (`UseTTY`+1), the interpreter state cell.
7. **ESC.** `\x1b` cannot be sent as a key (the emulator's `handle_io()` swallows
   it), so no test sends it.

### Disagreements with the plan, and decisions

- **Prompt count for `s@ s@ + s@ s@ + !`.** The probe script gave 6; the line
  has 7 words and the ROM printed 7 prompts. Source reading (one prompt per
  executed word) is correct; the probe argument was wrong. Use 7. The
  stated rule in the plan is unchanged.
- **Wozmon run in the probe.** The probe stored `ab` at `0500` before running
  `0500R`, so it ran `AB 41 8D ...` (not the intended routine). This was a probe artifact, not a ROM fact. A clean
  run (store `A9 41 8D 00 A8 60`, then `0500R`) printed `0500: A9A` and then the
  menu, matching the plan. `0500R` echoes the examined address and byte before
  jumping, which the plan's note on `R` did not mention. New fact, not a
  mismatch.
- **Supermon `T` and `C`.** Both print a leading `\r\n` (`CRLF` at `COMPAR1`)
  before the loop, so the output is `\r\n\r\n`; `F` prints only the one
  `\r\n`. Compare of equal ranges prints no addresses. New fact, not a
  mismatch.
- No other plan expectation differed from the transcripts. No ROM defects
  found.

## Measured transcripts

Output is what followed the echo of the typed line, through the idle marker
where one was used. Time is the typed line only.

| Program | Input | Output (repr) | Time |
| --- | --- | --- | --- |
| Menu | `Z` | menu text ending `A. About\r\nOK> ` | |
| Menu | `a` | same menu | |
| Menu | `A` | `\r\nhttps://github.com/jimjag/JJ6502\r\n1. Load RAM Image ...` | |
| Wozmon | `6` | `\r\nWelcome to EWOZMON 1.0.\r\n]` | |
| Wozmon | `0500: A9 41 8D 00 A8 60` | `\r\n0500: 00\r\n\x08\r\n` | 0.6-0.7 s |
| Wozmon | `0500` | `\r\n0500: A9\r\n\x08\r\n` | 0.1 s |
| Wozmon | `0500.0505` | `\r\n0500: A9 41 8D 00 A8 60\r\n\x08\r\n` | 0.2-0.3 s |
| Wozmon | `0500: ab` | echoes `A`, `B`; CR `\r\n` | |
| Wozmon | `0500R` (clean routine) | `\r\n0500: A9A\r\n1. Load RAM ...OK> ` | 0.2 s |
| Wozmon | `Q` | `Q\r\n1. Load RAM ... OK> ` | |
| Wozmon | `0500: 60`, `0500R` | `\r\n0500: 60\r\n1. Load RAM ... OK> ` | |
| MilliForth | `8` | `\r\nMilliForth for JJ6502\r\nok> ` | |
| MilliForth | `s@ .` | `\r\nok> `, ` 0022\r\nok> ` | 0.1 s |
| MilliForth | `.S` | `S0496 01  0022\r\nok> ` | 0.1 s |
| MilliForth | `s@ s@ .S` | 2 x `\r\nok> `, `S0492 03  0022 0022 0022\r\nok> ` | 0.2 s |
| MilliForth | `: foo s@ ;` | 2 x `\r\nok> ` | 0.2-0.3 s |
| MilliForth | `foo .` | `\r\nok> `, ` 0022\r\nok> ` | 0.1 s |
| MilliForth | `s@ nonesuch` | 2 x `\r\nok> ` | 0.3 s |
| MilliForth | `.S` (after unknown word) | `S0498 00 \r\nok> ` | 0.1 s |
| MilliForth | `tty` | `\r\nok> ` | 0.1 s |
| MilliForth | `.R` | `R04E0 00 \r\nok> ` | 0.1 s |
| MilliForth | `s@ emit` | `\r\nok> `, `"\r\nok> ` | 0.2 s |
| MilliForth | `s@ @ .` | 2 x `\r\nok> `, ` 0100\r\nok> ` | 0.2 s |
| MilliForth | `s@ s@ + s@ s@ + !` | 7 x `\r\nok> ` | 0.4 s |
| MilliForth | `s@ s@ + @ .` | 4 x `\r\nok> `, ` 0044\r\nok> ` | 0.3 s |
| MilliForth | `bye` | `... About\r\nOK> ` | |
| MilliForth | re-enter `8`, `foo` | banner, then one `\r\nok> ` | |
| MilliForth | `.S` after re-entry | `S0498 00 \r\nok> ` | |
| Supermon+ | `9` + BS | `\r\n\r\nSUPERMON+ @ $E786 \r\n\r\n   PC  SR AC XR YR SP   V1.2+\r\n; 0000 00 00 00 00 00 \r\n\x08` | |
| Supermon+ | `R` | `\r\n   PC  SR AC XR YR SP   V1.2+\r\n; 0000 00 00 00 00 00 \r\n\x08` | 0.0 s |
| Supermon+ | `; 0500 00 11 22 33 FF` | `\r\n\x08` | 0.5-0.9 s |
| Supermon+ | `R` | `...; 0500 00 11 22 33 FF \r\n\x08` | 0.0-0.1 s |
| Supermon+ | `>0500 A9 41 8D 00 A8 60` | `\r\n>0500 A9 41 8D 00 A8 60 00 00 00 00 00 00 00 00 00 00:.A...`..........\r\n\x08` | 0.5-1.0 s |
| Supermon+ | `M0500 050F` | same `>0500 ...` line | 0.3-0.4 s |
| Supermon+ | `D0500 0505` | `\r\n. 0500  A9 41    LDA  #$41\r\n. 0502  8D 00 A8 STA  $A800\r\n. 0505  60       RTS  \r\n\x08` | 0.2-0.4 s |
| Supermon+ | `F0600 060F AA` | `\r\n\x08` | 0.3-0.5 s |
| Supermon+ | `M0600 060F` | `\r\n>0600 AA ... AA:................\r\n\x08` | 0.2-0.4 s |
| Supermon+ | `T0600 060F 0700` | `\r\n\r\n\x08` | 0.4-0.6 s |
| Supermon+ | `C0600 060F 0700` | `\r\n\r\n\x08` | 0.3-0.7 s |
| Supermon+ | `H0500 050F 41` | `\r\n0501 \r\n\x08` | 0.3-0.5 s |
| Supermon+ | `$41` | `\r\n $0041 \r\n +65\r\n &101\r\n %1000001\r\n\x08` | 0.1-0.2 s |
| Supermon+ | `%0` | `\r\n $0000 \r\n +0\r\n &0\r\n %0\r\n\x08` | 0.1 s |
| Supermon+ | `Z` | `?\r\n\r\n\x08` | 0.1 s |
| Supermon+ | `A 0500 LDA #$41` | `\r\n0500  A9 41    LDA  #$41\r\nA 0502 ` | |
| Supermon+ | `RMB5 $12` | `\r\n0502  57 12    RMB5 $12\r\nA 0504 ` | |
| Supermon+ | bare CR | `\r\n\x08` | |
| Supermon+ | `A 0500 XYZ` | `?\r\n\r\n\x08` | |
| Supermon+ | `X` | `... About\r\nOK> ` | |
| Supermon+ | `; 0500 00 11 22 33 FF`, `R`, `X`, re-enter `9` | banner register line `; 0500 00 11 22 33 FF \r\n` (not reset) | |
| Supermon+ | `R` after re-entry | `\r\n   PC  SR AC XR YR SP   V1.2+\r\n; 0500 00 11 22 33 FF \r\n\x08` | |
