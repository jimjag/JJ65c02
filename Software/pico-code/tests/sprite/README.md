# Sprite subsystem host tests

Host-side tests for the sprite engine in `../../pico_core/vga_graphics.c`
(`loadSprite` / `drawSprite` / `eraseSprite` / `moveSprite` / `hideSprite` /
`freeSprite` / `refreshSprites` and the internal draw-order / overlap logic).

They run on the build machine — no Pico hardware or SDK needed — so the sprite
logic can be exercised far more exhaustively than on-device.

## Running

```sh
./run.sh            # scenario repros + a 60k-iteration simulation
./run.sh 200000     # ...with a longer simulation
CC=gcc ./run.sh     # pick a compiler (default: cc)
```

### Watching the tests (SDL display)

```sh
./run.sh display        # same tests, shown live in an SDL window
./run.sh display 5000   # ...with a 5000-iteration sim (default 2000)
```

Display mode renders the 128×48 test framebuffer live as sprites are drawn,
moved, hidden and freed — the edge-clip test sweeps a sprite across the screen,
and the differential sim shows the sprites shuffling. It reuses the SDL
emulator's palette (`../../sim/vga_palette.h`) via `test_display.c`, builds
**without** ASan, and links SDL2 (MacPorts `/opt/local`; override `SDL_PREFIX`).
Close the window or press **Esc** to skip ahead. The headless default remains
the correctness authority; the display hooks (`TD_*` in `host_env.c`) compile to
nothing there.

Exit status is non-zero if anything fails. Everything builds with
AddressSanitizer + UBSan.

## How it works

`vga_graphics.c` is `#include`d into `vga_core.c` and pulls in the Pico SDK /
VGA hardware, so it can't be compiled standalone. `run.sh` therefore:

1. Extracts just the sprite functions — everything between the
   `sprite_t *sprites[MAXSPRITES];` and `tile_t *tiles[MAXTILES];` markers —
   into `_extracted.c`.
2. Concatenates `host_env.c` + `_extracted.c` + the test file into one host
   translation unit and builds it.

`host_env.c` supplies the minimal environment the extracted code expects: a
stand-in framebuffer, the `sprite_t` struct, the geometry/colour macros, and
stubs for `convertRGB332` / `getByte`. **The screen size is deliberately small
(128×48)** so a handful of sprites densely overlap. **`sprite_t` here must stay
in sync with `vga_core.h`.**

## The two programs

### `repros.c` — scenario tests
Each targets one behaviour and checks the framebuffer against an independent
per-pixel painter's-algorithm reference:

- edge clipping + erase round-trip (off-left / on-screen / off-right, 16- & 32-wide)
- the documented odd-X dropped-rightmost-column limitation
- **Bug A** — a partially-off-screen sprite keeps its true position through `refreshSprites` (no teleport to the edge)
- **Bug B** — bringing a sprite back from off-screen lands it *under* a higher overlapping sprite
- **Bug C** — `hideSprite` on a lower sprite leaves no hole in the higher one
- `freeSprite` leaves no hole in a higher sprite
- `moveSprite` keeps z-order when a lower sprite slides under a higher one

### `sim.c` — differential simulation
The core correctness check. It drives a long randomised sequence of the safe API
(`move`/`hide`/`free`/`reload`/`refresh`) over 10 overlapping sprites at every
on-screen / partially-clipped / off-screen position and X parity. After **every**
operation it compares the incrementally-maintained framebuffer to a from-scratch
repaint done by the real renderer itself (`clean_repaint`) — a model-free oracle.
An independent z-order model decides which sprites are visible and in what order.
Any divergence prints the first failing operation, the draw order, and the
mismatching pixel row, then the run fails.

The PRNG is fixed-seed, so failures are reproducible.

## When the sprite code changes

If a change alters the sprite section's start/end markers, or adds/removes
`sprite_t` fields, update the markers in `run.sh` / the struct in `host_env.c`
accordingly. Re-run `./run.sh` after any change to the sprite engine.
