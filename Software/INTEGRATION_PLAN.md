# Integrating the x65c02 Emulator with the Pico VGA/Sound Sim

Status: **implemented and verified end-to-end** (see "Outcome" at the bottom).
This document is the implementation plan for connecting the `Emulator/` 65C02 CPU
emulator to the `pico-code/sim/` host simulation of the RP2350 VGA/Sound support
chip, so that everything the emulated 6502 "writes to the Pico" is rendered by
the real firmware running on the host.

## 1. Target architecture

Two processes, connected by a byte pipe in each direction — faithful to the
real two-chip hardware (6502 SBC ⟷ RP2350).

```
  ┌─ x65c02 (Emulator/) ────────┐         ┌─ jj65c02-sim (pico-code/sim/) ─┐
  │  ncurses debugger + CPU     │         │  SDL 640×480 window + renderer  │
  │                             │         │                                 │
  │  sta $A800  ──────────────────pipe A──────▶ getByte() ring ─▶ handleByte│
  │  (CON_write_byte)           │         │      ─▶ terminal/graphics/sound │
  │                             │         │                                 │
  │  mem[$A021] + IRQ  ◀──────────pipe B──────── SDL keypress ─▶ feed byte  │
  │  (VIA_ihandler)             │         │                                 │
  └─────────────────────────────┘         └─────────────────────────────────┘
```

Both processes keep their existing UI. They run asynchronously, coupled only by
the two byte streams — which is how the real hardware behaves.

## 2. Why this is clean

The whole system already funnels through the exact seams we need:

- **6502 → Pico is a one-byte-wide serial channel.** Every character, ANSI/VT100
  escape, graphics primitive (`ESC[Z18;...Z`), and sound command
  (`ESC[Z1;<code>Z`) is serialized as a byte written to `PICO_ADDR = $A800`
  (`minios/src/console.s`, `CON_write_byte: sta PICO_ADDR`).
- **The emulator already traps `$A800`.** `Emulator/src/io.h:8` defines
  `IO_PUTCHAR 0xA800`, and `handle_io()` (`io.c:42`) already intercepts writes to
  it (today it prints to its ncurses terminal).
- **The sim already stubs the receive seam.** `pico-code/sim/sim_platform.c:92`
  has `getByte()` hard-stubbed to return false, commented "No 6502 byte stream in
  the simulation." Right beside it is a working ring-buffer template — the PS/2
  keyboard feed (`sim_feed_key()` + `ps2GetChar()`, `sim_platform.c:222-249`).
- **miniOS ships a sim build target.** `make sim` (`minios/src/Makefile`) uses
  `jj65c02-sim.cfg` + `-D SIM=1`, which strips the ACIA and VIA-IFR interrupt
  checks so the ISR jumps straight to `VIA_ihandler` (reads `$A021`) — exactly
  the minimal VIA behavior the emulator can satisfy.

No changes to the CPU core, the VGA renderer, the escape parser, or the sound
synth — only glue at the two proven seams.

## 3. Wire protocol

Deliberately trivial to start: **two raw byte streams, no framing.**

- **Pipe A (6502 → Pico):** every byte the 6502 writes to `$A800`, verbatim. It
  already carries the full serialized language; the sim's `handleByte()` is the
  parser.
- **Pipe B (Pico → 6502):** every PS/2 key byte from the sim, verbatim (7-bit
  ASCII; arrows already mapped to `0x11`–`0x14`). The real firmware prefixes a
  `0x02` (STX) byte for the keyboard channel (`send2RAM`), and `VIA_ihandler`
  checks for it — we match that so the existing ROM works unchanged.

Transport: a **Unix domain socket**. The sim listens; the emulator connects (with
retry). The emulator falls back to its own ncurses terminal output when no sim is
connected.

## 4. Work items (phased)

### Phase 0 — Build the sim ROM (no code changes)
- `cd minios/src && make sim` → `sim` binary image (20 KB, `$B000–$FFFF`).
- Load in emulator: `./x65c02 -b b000 sim` (reset vector at `$FFFC`).
- Checkpoint: emulator boots miniOS to the menu; `$A800` writes land in ncurses.

### Phase 1 — Emulator: forward `$A800` out, inject keys in
- New `Emulator/src/picolink.{c,h}`: `picolink_init(path)` (connect+retry, else
  standalone), `picolink_send_byte(u8)`, `picolink_poll_byte(u8*)` (non-blocking),
  `picolink_close()`.
- `io.c:42`: in the `IO_PUTCHAR` branch, add `picolink_send_byte(m->mem[addr])`.
- `io.c:20-39`: after the `getch()` block, if `picolink_poll_byte(&c)` then
  `m->mem[IO_GETCHAR] = c; m->interrupt_waiting = 0x01;` (mirrors existing key
  injection).
- `io.c:14-18`: `init_io`/`finish_io` call `picolink_init/close`.
- `main.c:29`: add `-p PATH` option (getopt `"hb:sfp:"`).
- `Emulator/build` globs `src/*.c`, so no build-script edit needed.

### Phase 2 — Sim: real `getByte()` fed from a socket
- `sim_platform.c:91-95`: replace stub with a mutex ring cloned from the PS/2
  ring; add `sim_feed_6502_byte(u8)`; `getByte()` pops from it. Also fixes the
  latent infinite spin in `loadSprite`/`loadTile`.
- Add `conInTask()` (`if (getByte(&a)) handleByte(a);`) — the sim doesn't compile
  `vga_core.c` where the real one lives.
- New `sim-code/sim_link.c` (or fold into `sim_sdl.c`): listener/reader thread
  (create socket, accept emulator, read bytes → `sim_feed_6502_byte`), and writer
  path (SDL keyboard handler also writes STX-prefixed byte down pipe B).

### Phase 3 — Sim byte-consuming entry point
- The bundled `pico_core_demo.c` never calls `conInTask()` and would fight for the
  screen. **On real hardware the RP2350 runs `pico_6502.c`, not the demo** — so
  the faithful move is to compile the *real* `pico_6502.c` under `-DHOST_SIM`
  (same `main`→`demo_main` + include-swap treatment already applied to the demo),
  rather than a hand-written copy (a copy drifts — e.g. `pico_6502.c` calls
  `setTextSize` during init, which a copy omitting it would render nothing).
- Its `while(true){conInTask();}` loop drains the 6502 byte stream; its
  `core1_main` runs `soundTask()` + `ps2Task()`. On the host, `ps2Task()` is
  shimmed (`sim_link.c`) to drain the SDL PS/2 ring and ship bytes to the
  emulator.
- `build.sh` gets a `SIM_SOURCE=console|demo` switch (default `demo`); console
  mode compiles `pico_6502.c` instead of `pico_core_demo.c`.

### Phase 4 — Build & run glue
- `build.sh:36-47`: swap `$DEMO` for `pico_6502.c` in console mode; add
  `sim_link.c` to the link line.
- Launch: start `jj65c02-sim` (creates socket, opens window), then
  `./x65c02 -b b000 -p /tmp/jj65c02.sock sim`.

## 5. Validation

- Phase 1: point emulator at a byte-logging socket; boot miniOS; confirm the logo
  / `"JJ65c02 miniOS v2.0.0"` / menu text arrive as a byte stream.
- Phase 2/3: run both; the miniOS boot screen and menu render in the SDL window.
- Sound: trigger `ESC[Z1;<code>Z` or `\a`; confirm audio (SDL device or
  `sim_audio_probe.c`).
- Keyboard round-trip: type in the SDL window → menu selection changes in the
  6502 → output renders back (exercises both pipes).
- Regression: non-sim ROM `make`, the CMake firmware build, and `build.sh` (demo
  mode) all remain working. All new emulator code is behind the socket presence.

## 6. Risks / notes

- **VIA fidelity:** `-D SIM=1` ROM skips the IFR check and jumps to
  `VIA_ihandler`, so writing `$A021` + raising IRQ is sufficient. Match the STX
  (`0x02`) keyboard-channel prefix.
- **IRQ latching:** the emulator's `interrupt_waiting` is a one-shot flag consumed
  per loop; if keys outpace servicing, add a small input queue before asserting
  IRQ.
- **Startup order / reconnect:** handle either process starting first (listen +
  connect-retry). Emulator without a sim falls back to ncurses output.

## 7. Outcome (implemented)

Delivered and verified. Files touched:

- Emulator: new `Emulator/src/picolink.{c,h}` (unix-socket client: connect+retry,
  send byte, non-blocking poll, fallback); `io.c` forwards `$A800` writes and
  injects returned key bytes into VIA Port A + IRQ (gated on no pending IRQ);
  `io.h`/`main.c` add the `-p PATH` option.
- Sim: `sim_platform.c` `getByte()` is now a real mutex ring fed by
  `sim_feed_6502_byte()`, plus `conInTask()`; new `sim_link.c` (socket listener/
  reader thread + `sim_link_send_key` + host `ps2Task` shim); `pico_shim.h`
  prototypes; `build.sh` `SIM_SOURCE` switch; `pico_6502.c` given `HOST_SIM`
  guards (non-sim path byte-for-byte unchanged, so the firmware CMake build is
  unaffected).

Verified headlessly (BMP snapshots + histograms):
- **Display path:** the full miniOS boot screen (logo, `Pico2 Console` banner the
  firmware draws itself, banner, menu) renders through the real renderer, driven
  entirely by the emulated 6502 over the socket.
- **Keyboard path:** a byte sent over the socket to the emulator is injected into
  the emulated VIA, serviced by miniOS's `VIA_ihandler`, selects the menu item,
  and the resulting output streams back and renders — full round-trip.
- **Regressions:** the `demo` sim variant and the firmware CMake source structure
  are unchanged; the emulator runs standalone (ncurses) when no `-p` is given.
</content>
</invoke>
