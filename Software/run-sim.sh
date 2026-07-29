#!/bin/sh
# Launch the VGA/Sound sim and point the x65c02 emulator at it over the
# unix socket. The emulator needs a 60x120 terminal (see gui.c).
set -e
cd "$(dirname "$0")"

SOCK=/tmp/jj65c02.sock
LINES=60
COLUMNS=120
export LINES
export COLUMNS

# Build before launching, so compile time is not part of the wait below.
SIM_SOURCE=console ./pico-code/sim/build.sh

./pico-code/sim/jj65c02-sim &
SIM_PID=$!
trap 'kill "$SIM_PID" 2>/dev/null' EXIT

# The sim bind()s the socket during startup; picolink_init() only retries the
# connect for 2s, which a slow start can outrun. Wait for the socket instead.
i=0
while [ ! -S "$SOCK" ]; do
    kill -0 "$SIM_PID" 2>/dev/null ||
        { echo "run-sim.sh: sim exited before creating $SOCK" >&2; exit 1; }
    i=$((i + 1))
    if [ "$i" -gt 100 ]; then
        echo "run-sim.sh: $SOCK did not appear after 10s" >&2
        exit 1
    fi
    sleep 0.1
done

./Emulator/x65c02 -n -b b000 -p "$SOCK" ./minios/src/sim-minios.rom
