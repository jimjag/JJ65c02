#!/usr/bin/env python3
"""Headless driver for the x65c02 ncurses emulator.

Runs the emulator in a pty, feeds it a scripted keystroke session, and
writes a cleaned (ANSI-stripped) transcript that can be grepped for
expected output. Kills the emulator hard on exit (it ignores SIGTERM).

Usage:
    x65c02-headless.py ROM SCRIPT [-o TRANSCRIPT] [--raw RAWFILE]
                       [--speed {s,f,n}] [--boot SECONDS] [--deadline SECONDS]

SCRIPT file format, one step per line (# comments and blanks ignored):
    <delay-seconds> <keys>
where <keys> may contain the escapes \\r (Enter) and \\e (ESC).
Each step types its keys, then waits <delay-seconds> for output.
Example session that boots minios, starts EhBASIC (menu item 7) and
prints a number:
    2.0 7
    2.0 PRINT 1/3\\r

Exit status: 0 on success, 1 if the emulator died before the script
finished or the hard deadline was hit.
"""
import argparse
import os
import re
import signal
import sys
import tempfile
import time

from x65c02_session import EmulatorSession, default_emulator

ANSI_RE = re.compile(
    rb"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07|\x1b[()][0-9A-Za-z]|\x1b[=>]"
)


def clean(raw: bytes) -> str:
    txt = ANSI_RE.sub(b"", raw)
    txt = txt.replace(b"\r", b"\n")
    txt = re.sub(rb"[^\x09\x0a\x20-\x7e]", b"", txt)
    txt = re.sub(rb"\n{3,}", b"\n\n", txt)
    return txt.decode("ascii", "replace")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("rom")
    ap.add_argument("script")
    ap.add_argument("-o", "--out", default="transcript.txt")
    ap.add_argument("--raw", default=None, help="also save raw pty bytes here")
    ap.add_argument("--speed", default="s", choices=["s", "f", "n"],
                    help="emulator speed flag: sprint/fast/non-stop")
    ap.add_argument("--boot", type=float, default=3.0,
                    help="seconds to wait after launch before typing")
    ap.add_argument("--deadline", type=float, default=90.0,
                    help="hard wall-clock limit; emulator is killed after this")
    ap.add_argument("--char-delay", type=float, default=0.05,
                    help="pause between keystrokes; raise if keys get dropped")
    ap.add_argument("--console", default=None,
                    help="write everything the ROM prints to the console here "
                         "(emulator -o); the readable channel for program output")
    args = ap.parse_args()

    with open(args.script) as f:
        steps = [ln.rstrip("\n") for ln in f
                 if ln.strip() and not ln.lstrip().startswith("#")]

    console = args.console
    scratch = None
    if console is None:
        scratch = tempfile.NamedTemporaryFile(suffix=".console", delete=False)
        scratch.close()
        console = scratch.name

    session = EmulatorSession(args.rom, console, emulator=default_emulator(),
                              speed=args.speed, keep_pty=True)
    deadline = time.time() + args.deadline

    def pause(duration: float) -> None:
        end = min(time.time() + duration, deadline)
        while session.alive and time.time() < end:
            time.sleep(0.02)

    status = 0
    pause(args.boot)
    for step in steps:
        if not session.alive or time.time() >= deadline:
            status = 1
            break
        delay, _, text = step.partition(" ")
        for ch in text.replace("\\r", "\r").replace("\\e", "\x1b"):
            if not session.alive:
                break
            try:
                session.send(ch.encode())
            except OSError:
                break
            pause(args.char_delay)
        pause(float(delay))
    if not session.alive:
        status = 1

    session.close()
    collected = bytes(session.pty_bytes)
    if scratch is not None:
        os.unlink(console)

    if args.raw:
        with open(args.raw, "wb") as f:
            f.write(collected)
    with open(args.out, "w") as f:
        f.write(clean(collected))
    print(f"captured {len(collected)} raw bytes -> {args.out}"
          f" (emulator {'ok' if status == 0 else 'DIED EARLY'})")
    return status


if __name__ == "__main__":
    signal.signal(signal.SIGALRM, lambda *_: os._exit(2))
    signal.alarm(300)  # absolute backstop
    sys.exit(main())
