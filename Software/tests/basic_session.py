"""EhBASIC on top of an EmulatorSession."""
import textwrap

from x65c02_session import EmulatorError, EmulatorTimeout

PROMPT = b"\r\nReady\r\n"


class BasicSession:
    def __init__(self, emu):
        self.emu = emu
        self.broken = False

    def _key_until(self, key: bytes, pattern: bytes, tries=3, timeout=5.0):
        for attempt in range(tries):
            self.emu.send(key)
            try:
                return self.emu.wait_for(pattern, timeout)
            except EmulatorTimeout:
                if attempt == tries - 1:
                    raise

    def boot(self) -> None:
        self.emu.wait_for(b"OK> ", 60)
        self._key_until(b"7", b"[C]old/[W]arm ?")
        self._key_until(b"C", b"Bytes free")
        self.emu.wait_for(PROMPT, 60)

    def eval(self, statement: str, timeout: float = 10.0) -> str:
        try:
            self.emu.type_text(statement + "\r")
            out = self.emu.wait_for(PROMPT, timeout)
        except EmulatorError:
            self.broken = True
            raise
        return out[:-len(PROMPT)].decode("latin-1").replace("\r\n", "\n")

    def enter(self, program: str) -> None:
        try:
            for line in textwrap.dedent(program).strip().splitlines():
                self.emu.type_text(line.strip() + "\r")
        except EmulatorError:
            self.broken = True
            raise

    def new(self) -> None:
        self.eval("NEW")

    def run(self, program: str, timeout: float = 30.0) -> str:
        self.new()
        self.enter(program)
        return self.eval("RUN", timeout)
