#!/bin/sh
# Build the JJ65c02 VGA simulation (SDL2 viewer running the real
# pico_core_demo.c against a host framebuffer). macOS / Apple silicon baseline.
#
# SDL2 is provided by MacPorts under /opt/local. Override SDL_PREFIX / CC to
# taste. The firmware build (CMake) is unaffected — this never defines HOST_SIM
# there.
#
#   ./build.sh          # build ./jj65c02-sim (SDL viewer, graphics demo)
#   ./build.sh run      # build, then launch it
#   ./build.sh dump [s] # build+run the headless BMP snapshot harness (no SDL);
#                       # renders the demo for [s] seconds (default 2) to out.bmp
#
# Content source (which .c provides demo_main + core1_main):
#   SIM_SOURCE=demo     # (default) pico_core_demo.c — the graphics animation
#   SIM_SOURCE=console  # sim_console.c — render the byte stream from the x65c02
#                       # emulator (start jj65c02-sim, then: x65c02 -p <socket>)
# e.g.  SIM_SOURCE=console ./build.sh run
set -e
cd "$(dirname "$0")"

CC="${CC:-cc}"
SDL_PREFIX="${SDL_PREFIX:-/opt/local}"
SIM_SOURCE="${SIM_SOURCE:-demo}"
OUT=jj65c02-sim

# -Wall -Wextra for our sim code, minus categories inherent to reusing the
# firmware source as-is (not sim bugs; "fixing" them means changing firmware
# APIs and would churn the firmware build):
#   pointer-sign      - drawString()/etc. take `unsigned char *`, called with string literals
#   constant-conversion - colour macros (0xff, 0xc0...) assigned into `char` params
#   static-in-inline  - vga_graphics.c's inline drawString() calls static tft_write()
#   unused-function   - dead firmware helpers (e.g. note_off) under -Wall
CFLAGS="-DHOST_SIM -O2 -g -Wall -Wextra \
  -Wno-unused-parameter -Wno-pointer-sign -Wno-constant-conversion \
  -Wno-static-in-inline -Wno-unused-function"
INCS="-I${SDL_PREFIX}/include"
LIBS="-L${SDL_PREFIX}/lib -lSDL2 -lpthread"

# sim_platform.c #includes vga_fonts.c + vga_graphics.c (+ escape_seq.c), so the
# renderer is not listed as a separate translation unit here. pico_synth_ex.c
# (the sound synth) is compiled for real now that audio is emulated.
case "$SIM_SOURCE" in
    demo)    SOURCE="../pico_core/pico_core_demo.c" ;;
    console) SOURCE="../pico_core/pico_6502.c" ;;   # the real RP2350 firmware
    *) echo "unknown SIM_SOURCE '$SIM_SOURCE' (use demo|console)" >&2; exit 1 ;;
esac
SYNTH="../pico_core/pico_synth_ex.c"
LINK="sim_link.c"   # unix-socket bridge to the x65c02 emulator (inert until used)

echo "source: $SIM_SOURCE ($SOURCE)"

# Headless snapshot harness — no SDL, no display needed.
if [ "$1" = "dump" ]; then
    echo "cc  _sim_dump  (headless)"
    $CC $CFLAGS sim_dump.c sim_platform.c "$SOURCE" "$SYNTH" "$LINK" -lpthread -o _sim_dump
    exec ./_sim_dump "${2:-2}" out.bmp
fi

echo "cc  $OUT  (SDL2 at ${SDL_PREFIX})"
$CC $CFLAGS $INCS sim_sdl.c sim_platform.c "$SOURCE" "$SYNTH" "$LINK" $LIBS -o "$OUT"
echo "built ./$OUT"

if [ "$1" = "run" ]; then
    exec "./$OUT"
fi
