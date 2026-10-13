# RAM Images

This directory contains pre-built RAM images for the JJ6502 system. Using `miniOS`, these can be loaded directly into RAM and run.

Currently included is:

- `taliforth-jj6502.bin`: Complete build of [Taliforth2](https://github.com/SamCoVT/TaliForth2) for the JJ6502. Also included is the  `TaliForth2-jj6502-platform.asm` file used to build it. To rebuild yourself, create the `jj6502` subdirectory under the `platforms` directory and copy the `TaliForth2-jj6502-platform.asm` file into it, renaming it to `platform.asm`.
