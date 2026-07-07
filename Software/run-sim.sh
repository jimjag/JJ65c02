SIM_SOURCE=console ./pico-code/sim/build.sh run &
./Emulator/x65c02 -n -b b000 -p /tmp/jj65c02.sock ./minios/src/sim-minios.rom
