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
# Both are compiled with AddressSanitizer + UBSan. Exit non-zero on any failure.
#
#   ./run.sh                 # repros + default-length sim
#   ./run.sh 200000          # repros + 200k-iteration sim
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
CFLAGS="-O2 -g -fsanitize=address,undefined -w"

cat host_env.c _extracted.c repros.c > _repros.c
cat host_env.c _extracted.c sim.c    > _sim.c
$CC $CFLAGS -o _repros _repros.c
$CC $CFLAGS -o _sim    _sim.c

rc=0
echo; echo "=== scenario repros ==="
./_repros || rc=1
echo; echo "=== differential simulation ==="
./_sim "$@" || rc=1
exit $rc
