"""miniOS menu and the monitors reachable from it, on top of an EmulatorSession."""
from loader_data import EOT
from x65c02_session import EmulatorError, EmulatorTimeout

MENU = b"OK> "
BS = b"\x08"


def _text(data: bytes) -> str:
    return data.decode("latin-1")


def _default_echo(ch: str) -> bytes:
    return b"\r\n" if ch == "\r" else ch.encode("ascii")


def _cr_only_echo(ch: str) -> bytes:
    return ch.encode("ascii")


def _upper_echo(ch: str) -> bytes:
    return b"\r\n" if ch == "\r" else ch.upper().encode("ascii")


def prompts_for(line: str) -> int:
    """MilliForth prints a prompt after every executed word, not every line."""
    count, compiling, skip = 0, False, False
    for tok in line.split():
        if skip:
            skip = False
        elif tok == ":":
            count += 1
            compiling, skip = True, True
        elif tok == ";":
            count += 1
            compiling = False
        elif not compiling:
            count += 1
    return count


class MenuSession:
    def __init__(self, emu):
        self.emu = emu
        self.broken = False
        self.boot_output = ""
        self.peer = None

    def close(self) -> None:
        self.emu.close()
        if self.peer is not None:
            self.peer.close()

    def boot(self) -> None:
        self.boot_output = _text(self.emu.wait_for(MENU, 60)).replace("\r\n", "\n")

    def press(self, key: bytes, pattern: bytes, timeout=10.0, tries=3) -> bytes:
        """Menu keys are not echoed, so a lost key shows only as a missing reply."""
        for attempt in range(tries):
            self.emu.send(key)
            try:
                return self.emu.wait_for(pattern, timeout)
            except EmulatorTimeout:
                if attempt == tries - 1:
                    self.broken = True
                    raise
            except EmulatorError:
                self.broken = True
                raise


class _Program:
    key = b""
    banner_pattern = b""
    echo_for = staticmethod(_default_echo)

    def __init__(self, menu):
        self.menu = menu
        self.emu = menu.emu
        self.banner = ""
        self.left = False

    def _guard(self, fn, *args, **kw):
        try:
            return fn(*args, **kw)
        except EmulatorError:
            self.menu.broken = True
            raise

    def _type(self, text, **kw):
        self._guard(self.emu.type_text, text, echo_for=self.echo_for, **kw)

    def _wait(self, pattern, timeout=10.0):
        return self._guard(self.emu.wait_for, pattern, timeout)

    def _finish_enter(self, out: bytes) -> str:
        self.banner = _text(out)
        return self.banner

    def enter(self) -> str:
        return self._finish_enter(
            self.menu.press(self.key, self.banner_pattern))

    def _leave_with(self, text: str) -> str:
        self._type(text)
        out = _text(self._wait(MENU, 15.0))
        self.left = True
        return out


class WozmonSession(_Program):
    key = b"6"
    banner_pattern = b"EWOZMON 1.0.\r\n]"
    echo_for = staticmethod(_upper_echo)
    SYNC = BS + b"\r\n"

    def line(self, text, timeout=10.0, **type_kw) -> str:
        self._type(text + "\r", **type_kw)
        self.emu.send(BS)
        out = self._wait(self.SYNC, timeout)
        return _text(out[:-len(self.SYNC)])

    def leave(self) -> str:
        return self._leave_with("Q")


class ForthSession(_Program):
    key = b"8"
    banner_pattern = b"MilliForth for JJ6502\r\nok> "
    echo_for = staticmethod(_cr_only_echo)
    PROMPT = b"\r\nok> "

    def eval(self, line, prompts=None, timeout=10.0) -> str:
        n = prompts_for(line) if prompts is None else prompts
        self._type(line + "\r")
        pieces = [self._wait(self.PROMPT, timeout)[:-len(self.PROMPT)]
                  for _ in range(n)]
        return _text(b"".join(pieces))

    def leave(self) -> str:
        return self._leave_with("bye\r")


class SupermonSession(_Program):
    key = b"9"
    banner_pattern = b"V1.2+"
    echo_for = staticmethod(_cr_only_echo)

    def _sync(self, timeout=10.0) -> str:
        self.emu.send(BS)
        out = self._wait(BS, timeout)
        return _text(out[:-1])

    def enter(self) -> str:
        head = self.menu.press(self.key, self.banner_pattern)
        return self._finish_enter(head + self._sync().encode("latin-1"))

    def line(self, text, timeout=10.0) -> str:
        self._type(text + "\r")
        return self._sync(timeout)

    def assemble(self, start, steps, cmd="A") -> str:
        """Each step is (instruction, address of the next pre-filled prompt)."""
        self._type(f"{cmd} {start} {steps[0][0]}\r")
        out = []
        for i, (_, nxt) in enumerate(steps):
            out.append(_text(self._wait(f"A {nxt} ".encode())))
            if i + 1 < len(steps):
                self._type(steps[i + 1][0] + "\r")
        self._type("\r")
        out.append(self._sync())
        return "".join(out)

    def leave(self) -> str:
        return self._leave_with("X\r")


def dump_ram(menu, start, length) -> bytes:
    woz = WozmonSession(menu)
    woz.enter()
    out = woz.line(f"{start:04X}.{start + length - 1:04X}")
    woz.leave()
    data = bytearray()
    for ln in out.split("\r\n"):
        if ":" in ln:
            data += bytes.fromhex("".join(ln.split(":", 1)[1].split()))
    return bytes(data)


class _Loader(_Program):
    banner_pattern = b"to start: "

    def __init__(self, menu):
        super().__init__(menu)
        self.peer = menu.peer

    def enter(self) -> str:
        out = super().enter()
        self.peer.clear()
        return out

    def begin(self) -> None:
        self.emu.send(b"L")

    def finish(self, timeout=60.0) -> str:
        out = _text(self._wait(MENU, timeout))
        self.left = True
        return out


class XmodemSession(_Loader):
    key = b"1"

    def wait_c(self, timeout=60.0) -> bytes:
        return self.peer.wait_for(b"C", timeout)

    def send(self, raw: bytes) -> None:
        self.peer.send(raw)

    def reply(self, timeout=60.0) -> int:
        """Next ACK/NAK; the periodic 'C' start requests are skipped."""
        while True:
            b = self.peer.read(1, timeout)[0]
            if b != ord("C"):
                return b

    def end(self, timeout=60.0) -> bytes:
        self.send(bytes([EOT]))
        return self.peer.wait_for(b"Successful!\n\r", timeout)
