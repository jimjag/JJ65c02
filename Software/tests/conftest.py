import os
import subprocess
from pathlib import Path

import pytest

SOFTWARE = Path(__file__).resolve().parent.parent
CA65_HINT = ("If ca65 cannot open 'generic.mac': "
             "export CA65_INC=/Users/jim/src/6502/cc65/asminc")


def _build(cmd, cwd, hint=""):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        pytest.fail(f"{' '.join(cmd)} failed in {cwd}:\n{r.stdout}{r.stderr}\n{hint}",
                    pytrace=False)


@pytest.fixture(scope="session")
def rom():
    src = SOFTWARE / "minios" / "src"
    _build(["make", "sim"], src, CA65_HINT)
    path = src / "sim-minios.rom"
    assert path.stat().st_size == 0x5000, "sim ROM must be exactly $B000-$FFFF"
    return path


@pytest.fixture(scope="session")
def emulator_bin():
    override = os.environ.get("X65C02")
    if override:
        return override
    emu = SOFTWARE / "Emulator"
    _build(["./build"], emu)
    return str(emu / "x65c02")
