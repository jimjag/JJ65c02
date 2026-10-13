import os
import shutil
import signal
import subprocess
import tempfile
import time
from pathlib import Path

import pytest

from basic_session import BasicSession
from bitmap import Bitmap
from sim_helpers import STARTED_SIM_PIDS
from x65c02_session import EmulatorSession

SIM_DIR = Path(__file__).resolve().parents[2] / "pico-code" / "sim"


class Sim:
    def __init__(self, binary, directory):
        self.socket = directory / "s"
        self._bmp = directory / "o.bmp"
        self._proc = subprocess.Popen(
            [str(binary), "serve", str(self._bmp)],
            env=dict(os.environ, SIM_SOCKET=str(self.socket)),
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        STARTED_SIM_PIDS.append(self._proc.pid)
        deadline = time.monotonic() + 10
        while not self.socket.is_socket():
            if self._proc.poll() is not None:
                raise RuntimeError("sim exited before creating its socket")
            if time.monotonic() >= deadline:
                self.close()
                raise RuntimeError("sim socket did not appear within 10s")
            time.sleep(0.05)

    def snapshot(self) -> Bitmap:
        self._bmp.unlink(missing_ok=True)
        self._proc.send_signal(signal.SIGUSR1)
        deadline = time.monotonic() + 5
        while not self._bmp.exists():
            if self._proc.poll() is not None:
                raise RuntimeError("sim exited while dumping")
            if time.monotonic() >= deadline:
                raise RuntimeError("sim did not write a snapshot within 5s")
            time.sleep(0.02)
        return Bitmap(self._bmp.read_bytes())

    def close(self):
        if self._proc.poll() is None:
            self._proc.kill()
        self._proc.wait()


@pytest.fixture(scope="session")
def sim_bin():
    r = subprocess.run(["./build.sh", "dump-build"], cwd=SIM_DIR,
                       env=dict(os.environ, SIM_SOURCE="console"),
                       capture_output=True, text=True)
    if r.returncode != 0:
        pytest.fail(f"sim build failed:\n{r.stdout}{r.stderr}", pytrace=False)
    return SIM_DIR / "_sim_dump"


@pytest.fixture
def sim_basic(sim_bin, rom, emulator_bin, tmp_path):
    # sun_path is 104 bytes on macOS; pytest's tmp_path is longer than that.
    short = Path(tempfile.mkdtemp(prefix="jj", dir="/tmp"))
    sim = emu = None
    try:
        sim = Sim(sim_bin, short)
        emu = EmulatorSession(rom, tmp_path / "console.txt",
                              emulator=emulator_bin, socket_path=sim.socket)
        basic = BasicSession(emu)
        basic.boot()
        yield sim, basic
    finally:
        if emu is not None:
            emu.close()
        if sim is not None:
            sim.close()
        shutil.rmtree(short, ignore_errors=True)
