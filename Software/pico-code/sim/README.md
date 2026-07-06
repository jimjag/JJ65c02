# JJ65c02 VGA simulation (macOS / Apple silicon)

Runs the **real firmware demo** (`../pico_core/pico_core_demo.c`) on the
development machine, drawing into a host copy of the Pico's 640×480 4bpp
framebuffer and presenting it in an SDL2 window. Nothing is emulated at the
instruction level — the *actual* VGA rendering code that runs on the Pico
(`vga_graphics.c` + `escape_seq.c`) is compiled and run here unchanged.

This is the visual companion to `../tests/sprite/`, which exercises the same
renderer headlessly and compares pixel arrays.

## Requirements

- macOS on Apple silicon (baseline target).
- SDL2 via MacPorts: `sudo port install libsdl2` (installs under `/opt/local`).
  Override the location with `SDL_PREFIX=/some/prefix ./build.sh` if needed.

## Build & run

```sh
./build.sh run          # build ./jj65c02-sim and launch the window
./build.sh              # build only
./build.sh dump 2       # headless: render the demo 2s to out.bmp (no display)
```

In the window: type on the keyboard to feed the demo's PS/2 input (it reaches
input-wait stages — press **Backspace** to leave the first "PS2 test", **Q** to
advance the later ones). **Esc** is delivered to the demo as a console key (it
does not quit). To quit, close the window or press **Cmd+Q**.

## How it works — the compile-time flag

`vga_graphics.c` is pure framebuffer drawing; `vga_core.c` is all the RP2040/
RP2350 hardware (PIO scanout, DMA, VBlank IRQ, double-buffering, timers). The
simulation keeps the former and replaces the latter with a host layer, selected
by **`-DHOST_SIM`**:

| Build | Flag | VGA/platform layer | Output |
|-------|------|--------------------|--------|
| Firmware (CMake) | *(unset)* | `vga_core.c` (real hardware) | `.uf2` |
| Simulation (`build.sh`) | `HOST_SIM` | `sim/sim_platform.c` + SDL | window |

The same `pico_core_demo.c` feeds both. Its only concessions to the host are a
handful of `#ifdef HOST_SIM` guards (SDK includes, the glibc-only heap stats,
and `main` → `demo_main`). With `HOST_SIM` unset the file is byte-identical to
before, so the firmware build is unaffected.

### Files

- **`sim_platform.c`** — host framebuffer + the text/terminal globals that
  `vga_core.c` normally owns, `dma_memset/memcpy`→`memset/memmove`,
  `getByte`/DB/cursor stubs, a host `initVGA`, then `#include`s the real
  `vga_graphics.c`. Also implements the SDK shims: host timing, a pthread
  repeating timer (drives the countdown), a host inter-core FIFO ring, running
  `core1_main` on a thread, and the PS/2 input ring the viewer feeds.
- **`sim_sdl.c`** — owns the process main thread (required for the macOS event
  loop): creates the window, runs `demo_main` on a worker thread, and each frame
  expands the 4bpp framebuffer through the 16-colour palette into an ARGB
  texture. Opens an SDL audio device whose callback pulls samples from the synth,
  and decodes keyboard events into the PS/2 ring.
- **`pico_shim.h`** — the Pico SDK surface the demo/header need on the host
  (`uint`, flash macros, `sleep_ms`, `repeating_timer`, multicore/PS2/sound
  prototypes).
- **`sim_dump.c`** — headless BMP snapshot harness for CI / SSH (no display).
- **`sim_audio_probe.c`** — headless audio harness: runs the synth's startup
  chord, reports peak/RMS, and writes `chord.wav` (no audio device needed).

The palette RGB values are exactly the "Regular RGB" comments beside each case
in `vga_core.c`'s `convertRGB332()`.

## Sound

The Pico's sound synth (`pico_synth_ex.c` — 4-voice, 44.1 kHz fixed-point) is
emulated too. Its DSP is portable; only the PWM output, the 44.1 kHz interrupt,
and the inter-core FIFO are hardware, so under `HOST_SIM`:

- an SDL audio device (mono S16 @ 44.1 kHz) replaces the PWM output — its
  callback runs the same `process_voice()` DSP the PWM interrupt did,
- `core1_main` runs on a thread and drains a host FIFO ring the demo pushes
  note/preset commands to.

You get the startup chord and the note/preset events the demo fires during the
sprite animation. Verify headlessly with `./build.sh` then
`cc -DHOST_SIM sim_audio_probe.c ../pico_core/pico_synth_ex.c -lm -o _probe && ./_probe`.

## Scope / limitations (baseline)

- No double-buffering (the demo doesn't use it); the viewer scans the single
  draw buffer, so fast full-screen changes can tear slightly.
- macOS/Apple-silicon only by design — SDL2 makes it portable, but only this
  target is set up/tested.
