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
import pty
import re
import select
import signal
import subprocess
import sys
import time

# Sibling of this directory: Software/Harness -> Software/Emulator/x65c02.
# Override with $X65C02 to test a binary built elsewhere.
EMU = os.environ.get("X65C02") or os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Emulator", "x65c02")

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
    args = ap.parse_args()

    with open(args.script) as f:
        steps = [ln.rstrip("\n") for ln in f
                 if ln.strip() and not ln.lstrip().startswith("#")]

    # The emulator's GUI is a fixed-size layout needing at least 60 rows by
    # 120 columns. Anything shorter does not fail, it just silently clips the
    # bottom of the memory pane out of the transcript (at 50 rows only 23 of
    # its 32 dump rows survive), so keep LINES at or above the minimum.
    os.environ.setdefault("TERM", "xterm-256color")
    os.environ["LINES"] = "60"
    os.environ["COLUMNS"] = "132"

    master, slave = pty.openpty()
    p = subprocess.Popen([EMU, f"-{args.speed}", args.rom],
                         stdin=slave, stdout=slave,
                         stderr=subprocess.DEVNULL, close_fds=True)
    os.close(slave)

    collected = bytearray()
    deadline = time.time() + args.deadline
    alive = True

    def pump(duration: float) -> None:
        nonlocal alive
        end = min(time.time() + duration, deadline)
        while alive and time.time() < end:
            r, _, _ = select.select([master], [], [], 0.1)
            if master in r:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    alive = False
                    return
                if not data:
                    alive = False
                    return
                collected.extend(data)
            if p.poll() is not None:
                alive = False

    def send(text: str) -> None:
        nonlocal alive
        for ch in text:
            if not alive:
                return
            try:
                os.write(master, ch.encode())
            except OSError:
                alive = False
                return
            pump(args.char_delay)

    status = 0
    pump(args.boot)
    for step in steps:
        if not alive or time.time() >= deadline:
            status = 1
            break
        delay, _, text = step.partition(" ")
        send(text.replace("\\r", "\r").replace("\\e", "\x1b"))
        pump(float(delay))
    if not alive:
        status = 1

    # ESC asks the emulator to exit cleanly; it ignores SIGTERM, so
    # follow up with SIGKILL regardless.
    if alive:
        try:
            os.write(master, b"\x1b")
        except OSError:
            pass
        pump(1.0)
    try:
        p.kill()
    except OSError:
        pass
    p.wait()
    os.close(master)

    if args.raw:
        with open(args.raw, "wb") as f:
            f.write(bytes(collected))
    with open(args.out, "w") as f:
        f.write(clean(bytes(collected)))
    print(f"captured {len(collected)} raw bytes -> {args.out}"
          f" (emulator {'ok' if status == 0 else 'DIED EARLY'})")
    return status


if __name__ == "__main__":
    signal.signal(signal.SIGALRM, lambda *_: os._exit(2))
    signal.alarm(300)  # absolute backstop
    sys.exit(main())
