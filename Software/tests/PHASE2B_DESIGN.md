# Phase 2b: miniOS loader tests (XMODEM, Intel-HEX)

Extends `tests/README.md` (miniOS tier). Same rule: expected values pin what
the current ROM does; a failing test means behaviour changed.

## Goal

Regression tests for menu option 1 (XMODEM load) and option 2 (Intel-HEX load)
through the real ACIA receive path. Both read serial input; the emulator has no
ACIA and the sim ROM compiles the ACIA code out, so both need work first.

## Facts from the source (verified by reading, not yet by running)

- Sim ROM: `ACIA_init` is a no-op under `SIM` (`acia.s:39`), the ISR's ACIA
  branch is `.IFNDEF SIM` (`minios.s:481`), so `MINIOS_STATUS` bit 0 is never set
  and the boot banner never says ACIA-enabled.
- ACIA registers: `__IO_START__ + $10..$13` = `$A010-$A013` (`acia.h`).
- Emulator: no ACIA. I/O is `$A800` console out, a keyboard byte injected
  through the VIA path, and the optional Pico socket (`-p`, `picolink.c`: Unix
  socket the emulator connects to, `poll()`-gated).
- XMODEM (`xmodem.s`): sends `C`, reads `SOH` blocks, ACK/NAK. Failure codes
  `$FE` abort (ESC), `$FD` bad block number, `$FC` bad complement, `$FB` out of
  RAM. A previous-block repeat is ACKed and dropped. Status text goes to the
  serial line (`ACIA_writeln`): `Transfer Successful!` / `Transfer Error!`.
- Intel-HEX (`intel-hex.s`): reads with `TTY_read_char_blk`, stores each data
  byte before checking the line checksum, ends at a type-01 record, ESC aborts,
  a line that fills the buffer prints the overflow message. Result text goes to
  the TTY: `Intel Hex Imported OK.` / `... with checksum error.` /
  `... aborted with overflow error.`
- Menu options 1 and 2 print a ready message and wait for `L` (`minios.s:215`,
  `246`); any other key returns to the menu.
- Timing: `GetByte` polls with a 20 ms `LIB_delay1ms` per empty poll, 150 polls;
  the success paths end with `LIB_delay100ms` x30 (XMODEM) and x50 (HEX). Phase
  2a measured about 15K cycles/s, so unmodified these cost about 10 s per empty
  poll and 27-45 min per success.

## Design

1. **Emulator `acia.c`**: 6551 model at `$A010-$A013` (data, status, command,
   control). Control reads back what was written (the ROM's init checks this). Status reports RX-full and TX-empty. A received byte sets
   RX-full and, when RX interrupts are enabled, raises the CPU IRQ; reading data
   clears it; the next byte is delivered only after that. A write to data sends
   the byte out. New flag `-a PATH`: connect to a Unix socket the harness
   listens on, `poll()`-gated like `picolink.c`. Without `-a` nothing changes.
2. **ROM variant**: `-D SIM_ACIA=1` (with `SIM=1`) enables `ACIA_init` and the
   ISR branch, and makes `LIB_delay1ms` cheap. New Makefile target builds
   `sim-acia-minios.rom`. The existing sim ROM, its goldens and the current
   tests are untouched.
3. **Harness**: `EmulatorSession` gains an optional serial socket (listen before
   launch, pass `-a`); an XMODEM-CRC sender helper answers `C`, ACK and NAK;
   `LoadSession` in `tests/minios_session.py` presses `1` or `2`, then `L`.
4. **Fixtures**: a `loader` fixture boots the ACIA variant with the socket, one
   menu per module as in Phase 2a.

## Tests (`tests/minios/test_loaders.py`, ACIA-model tests alongside)

- **ACIA model** via Wozmon examine of `$A011`: RX-full after a byte is sent;
  cleared by reading `$A010`; a TX write reaches the socket.
- **XMODEM**: one good block stored at `$0400` (read back with Wozmon); two
  blocks, addresses continue; bad CRC gives NAK, resend succeeds; duplicate
  block ACKed and not stored twice; wrong block number gives `Transfer Error!`;
  bad complement; non-SOH first byte gets NAK; ESC aborts; a key other than `L`
  returns to the menu. Out of RAM (`$FB`) is excluded: reaching `PROGRAM_END`
  takes about 300 blocks.
- **Intel-HEX**: good record plus EOF gives `Imported OK` and stored bytes;
  multi-line, multi-address input; bad checksum prints the error text (pin
  whether the data was still stored, expected yes); lines without `:` ignored;
  ESC aborts; an over-long line prints the overflow message.

Each test ends at the menu so the Phase 2a fixture pattern applies.

## Task 1 is a measuring gate (as in Phase 2a)

Before writing tests, build the variant and measure with the real ROM: banner
text, status bits, whether `ACIA_init` sets `MINIOS_STATUS` bit 0, the time of
a one-block XMODEM transfer, the time to return to the menu after each loader,
and how a socket sender should pace bytes. If a transfer needs more than a few
minutes, shrink the case list and record why. Expectations above that are not
yet run are reconciled against these measurements.

## Out of scope

Real baud timing, TX interrupts, XMODEM send (`XMODEM_send`), hardware flow
control, sound, `LOAD`/`SAVE`/`TTY` commands.
