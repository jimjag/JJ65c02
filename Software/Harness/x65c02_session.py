"""Drive the x65c02 ncurses emulator through a pty.

Program output is read from the emulator's -o console log, never from the pty.
"""
import os
import pty
import signal
import subprocess
import threading
import time
from pathlib import Path

_DEFAULT_EMU = Path(__file__).resolve().parent.parent / "Emulator" / "x65c02"


def default_emulator() -> str:
    return os.environ.get("X65C02") or str(_DEFAULT_EMU)


class EmulatorError(Exception):
    pass


class EmulatorTimeout(EmulatorError):
    pass


class EmulatorExited(EmulatorError):
    pass


class EchoMismatch(EmulatorError):
    pass


class EmulatorSession:
    def __init__(self, rom, console_path, *, emulator=None, speed="n",
                 socket_path=None, acia_path=None, keep_pty=False):
        self.console_path = Path(console_path)
        self.console_path.unlink(missing_ok=True)
        env = dict(os.environ, LINES="60", COLUMNS="132")
        env.setdefault("TERM", "xterm-256color")
        cmd = [emulator or default_emulator(), f"-{speed}",
               "-o", str(self.console_path)]
        if socket_path:
            cmd += ["-p", str(socket_path)]
        if acia_path:
            cmd += ["-a", str(acia_path)]
        cmd.append(str(rom))
        self._master, slave = pty.openpty()
        self._proc = subprocess.Popen(cmd, stdin=slave, stdout=slave,
                                      stderr=subprocess.DEVNULL, env=env,
                                      close_fds=True)
        os.close(slave)
        self.pid = self._proc.pid
        self.pty_bytes = bytearray() if keep_pty else None
        self._buf = bytearray()
        self._mark = 0
        self._log = None
        self._closed = False
        self._drain = threading.Thread(target=self._drain_pty, daemon=True)
        self._drain.start()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    @property
    def alive(self) -> bool:
        return self._proc.poll() is None

    def _drain_pty(self):
        # Unread pty output blocks the emulator once the kernel buffer fills.
        while True:
            try:
                data = os.read(self._master, 65536)
            except OSError:
                return
            if not data:
                return
            if self.pty_bytes is not None:
                self.pty_bytes.extend(data)

    def _fill(self):
        if self._log is None:
            try:
                self._log = open(self.console_path, "rb")
            except FileNotFoundError:
                return
        self._buf.extend(self._log.read())

    def tail(self, n=400) -> bytes:
        return bytes(self._buf[-n:])

    def send(self, keys: bytes) -> None:
        os.write(self._master, keys)

    def _poll(self, ready, what, timeout):
        deadline = time.monotonic() + timeout
        while True:
            dead = not self.alive
            self._fill()
            if ready():
                return
            if dead:
                raise EmulatorExited(
                    f"emulator exited (status {self._proc.returncode}) "
                    f"waiting for {what}; console tail: {self.tail()!r}")
            if time.monotonic() >= deadline:
                raise EmulatorTimeout(
                    f"no {what} within {timeout}s; "
                    f"console tail: {self.tail()!r}")
            time.sleep(0.005)

    def wait_for(self, pattern: bytes, timeout: float = 10.0) -> bytes:
        self._poll(lambda: self._buf.find(pattern, self._mark) >= 0,
                   repr(pattern), timeout)
        end = self._buf.find(pattern, self._mark) + len(pattern)
        out = bytes(self._buf[self._mark:end])
        self._mark = end
        return out

    def expect_exact(self, expected: bytes, timeout: float) -> None:
        start = self._mark
        try:
            self._poll(lambda: len(self._buf) - start >= len(expected),
                       f"echo {expected!r}", timeout)
        except EmulatorTimeout:
            if len(self._buf) == start:
                raise
        got = bytes(self._buf[start:start + len(expected)])
        if got != expected:
            raise EchoMismatch(f"typed {expected!r}, console shows {got!r}; "
                               f"console tail: {self.tail()!r}")
        self._mark = start + len(expected)

    def type_text(self, text: str, echo_timeout: float = 5.0,
                  retries: int = 0, echo_for=None) -> None:
        for ch in text:
            if echo_for is not None:
                echo = echo_for(ch)
            else:
                echo = b"\r\n" if ch == "\r" else ch.encode("ascii")
            for attempt in range(retries + 1):
                self.send(ch.encode("ascii"))
                try:
                    self.expect_exact(echo, echo_timeout)
                    break
                except EmulatorTimeout:
                    if attempt == retries:
                        raise

    def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        if self.alive:
            # Non-stop mode never reads ESC, so SIGINT asks for the shutdown;
            # the shutdown screen then waits for any key.
            self._proc.send_signal(signal.SIGINT)
            deadline = time.monotonic() + 1.0
            while time.monotonic() < deadline:
                try:
                    os.write(self._master, b"\x1b")
                    self._proc.wait(timeout=0.05)
                    break
                except subprocess.TimeoutExpired:
                    pass
                except OSError:
                    break
        self._proc.kill()
        self._proc.wait()
        # Join first so pty_bytes is complete when the caller reads it.
        self._drain.join(timeout=2.0)
        os.close(self._master)
        if self._log is not None:
            self._log.close()
