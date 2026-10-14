"""The serial line for the emulator's ACIA (x65c02 -a PATH).

The harness listens and the emulator connects, as with the Pico sim link. A
reader thread drains the socket so a chatty ROM never blocks on a full buffer.
"""
import shutil
import socket
import tempfile
import threading
import time
from pathlib import Path

from x65c02_session import EmulatorTimeout


class SerialPeer:
    def __init__(self, path=None):
        self._dir = None
        if path is None:
            # AF_UNIX paths are limited to about 104 bytes; pytest's tmp_path can exceed that.
            self._dir = Path(tempfile.mkdtemp(prefix="acia-"))
            path = self._dir / "s"
        self.path = Path(path)
        if len(str(self.path)) >= 100:
            raise ValueError(f"socket path too long for AF_UNIX: {self.path}")
        self.path.unlink(missing_ok=True)
        self._srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._srv.bind(str(self.path))
        self._srv.listen(1)
        self._conn = None
        self._buf = bytearray()
        self._mark = 0
        self._lock = threading.Lock()

    def accept(self, timeout=10.0):
        self._srv.settimeout(timeout)
        self._conn, _ = self._srv.accept()
        self._conn.settimeout(None)
        threading.Thread(target=self._drain, daemon=True).start()

    def _drain(self):
        while True:
            try:
                data = self._conn.recv(65536)
            except OSError:
                return
            if not data:
                return
            with self._lock:
                self._buf.extend(data)

    def send(self, data: bytes) -> None:
        self._conn.sendall(data)

    def _take(self, ready, timeout, what):
        deadline = time.monotonic() + timeout
        while True:
            with self._lock:
                end = ready(self._buf, self._mark)
                if end is not None:
                    out = bytes(self._buf[self._mark:end])
                    self._mark = end
                    return out
                tail = bytes(self._buf[self._mark:][-200:])
            if time.monotonic() >= deadline:
                raise EmulatorTimeout(
                    f"no {what} on the serial line within {timeout}s; "
                    f"unread: {tail!r}")
            time.sleep(0.005)

    def wait_for(self, pattern: bytes, timeout: float = 10.0) -> bytes:
        def ready(buf, mark):
            i = buf.find(pattern, mark)
            return None if i < 0 else i + len(pattern)
        return self._take(ready, timeout, repr(pattern))

    def read(self, n: int, timeout: float = 10.0) -> bytes:
        def ready(buf, mark):
            return mark + n if len(buf) - mark >= n else None
        return self._take(ready, timeout, f"{n} byte(s)")

    def unread(self) -> bytes:
        with self._lock:
            return bytes(self._buf[self._mark:])

    def clear(self) -> None:
        with self._lock:
            self._mark = len(self._buf)

    def disconnect(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    def close(self) -> None:
        self.disconnect()
        self._srv.close()
        self.path.unlink(missing_ok=True)
        if self._dir is not None:
            shutil.rmtree(self._dir, ignore_errors=True)
