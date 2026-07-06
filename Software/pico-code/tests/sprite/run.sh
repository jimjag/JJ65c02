#!/bin/sh
# Host-side test harness for the sprite subsystem in ../../pico_core/vga_graphics.c.
#
# vga_graphics.c is #included into vga_core.c and depends on the Pico SDK / VGA
# hardware, so it can't be built on a host as-is. This script extracts just the
# sprite functions (everything between the `sprites[]` and `tiles[]` markers),
# wraps them with a small host environment (host_env.c), and builds two hosted
# programs:
#
#   _repros  - hand-verifiable single-scenario tests (repros.c)
#   _sim     - long randomised differential simulation (sim.c)
#
# Default build: AddressSanitizer + UBSan, headless. Exit non-zero on failure.
#
#   ./run.sh                 # repros + default-length sim (headless, ASan)
#   ./run.sh 200000          # repros + 200k-iteration sim
#   ./run.sh display         # SDL build: watch the tests run in a window
#   ./run.sh display 5000    # ...with a 5000-iteration sim (default 2000)
#
# Display mode reuses the SDL emulator's palette (../../sim/vga_palette.h) and
# renders the 128x48 test framebuffer live as sprites are drawn/moved/hidden. It
# builds WITHOUT ASan and links SDL3; the headless default stays the correctness
# authority. Close the window (or press Esc) to skip ahead.
set -e
cd "$(dirname "$0")"

SRC=../../pico_core/vga_graphics.c
A=$(grep -n '^sprite_t \*sprites\[MAXSPRITES\];' "$SRC" | head -1 | cut -d: -f1)
B=$(grep -n '^tile_t \*tiles\[MAXTILES\];'       "$SRC" | head -1 | cut -d: -f1)
if [ -z "$A" ] || [ -z "$B" ]; then
    echo "ERROR: could not find the sprite-section markers in $SRC" >&2
    exit 1
fi
sed -n "${A},$((B-1))p" "$SRC" > _extracted.c
echo "extracted sprite subsystem: lines ${A}..$((B-1)) of $SRC"

CC="${CC:-cc}"
cat host_env.c _extracted.c repros.c > _repros.c
cat host_env.c _extracted.c sim.c    > _sim.c

# ---- optional SDL display mode: watch the tests run (no ASan) ----
if [ "$1" = "display" ] || [ "$1" = "--display" ]; then
    SDL_PREFIX="${SDL_PREFIX:-/opt/local}"
    DFLAGS="-O2 -g -w -DTEST_DISPLAY -I${SDL_PREFIX}/include"
    DLIBS="-L${SDL_PREFIX}/lib -lSDL3"
    echo "building SDL display build (SDL3 at ${SDL_PREFIX})"
    $CC $DFLAGS _repros.c test_display.c $DLIBS -o _repros_disp
    $CC $DFLAGS _sim.c    test_display.c $DLIBS -o _sim_disp
    rc=0
    echo; echo "=== scenario repros (display) ==="
    ./_repros_disp || rc=1
    echo; echo "=== differential simulation (display) ==="
    ./_sim_disp "${2:-2000}" || rc=1    # fewer iterations so it stays watchable
    exit $rc
fi

# ---- default: headless, ASan/UBSan (the correctness authority) ----
CFLAGS="-O2 -g -fsanitize=address,undefined -w"
$CC $CFLAGS -o _repros _repros.c
$CC $CFLAGS -o _sim    _sim.c

rc=0
echo; echo "=== scenario repros ==="
./_repros || rc=1
echo; echo "=== differential simulation ==="
./_sim "$@" || rc=1
exit $rc
