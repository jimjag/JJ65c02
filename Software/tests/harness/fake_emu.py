#!/usr/bin/env python3
"""Stand-in for x65c02: echoes typed bytes to the -o console log."""
import getopt
import os
import sys
import time
import tty

opts = dict(getopt.getopt(sys.argv[1:], "snfo:p:b:")[0])
mode = os.environ.get("FAKE_EMU_MODE", "")
tty.setraw(0)
log = open(opts["-o"], "wb", buffering=0)
log.write(b"BOOT\r\n")
drop = 1 if mode == "drop-first" else 0
while True:
    b = os.read(0, 1)
    if not b or b == b"\x1b":
        break
    if mode == "die" and b == b"!":
        sys.exit(3)
    if mode == "mute":
        continue
    if drop:
        drop -= 1
        continue
    if mode == "late":
        time.sleep(1.2)
    echo = b"\r\n" if b == b"\r" else b
    log.write(echo * 2 if mode == "dup" else echo)
