import os
import subprocess
from pathlib import Path

import pytest

from basic_session import BasicSession
from x65c02_session import EmulatorSession

SOFTWARE = Path(__file__).resolve().parent.parent
CA65_HINT = ("If ca65 cannot open 'generic.mac': "
             "export CA65_INC=/Users/jim/src/6502/cc65/asminc")


def pytest_addoption(parser):
    parser.addoption("--update-golden", action="store_true",
                     help="rewrite tests/basic/golden/*.out from the current ROM")


@pytest.fixture
def golden(request):
    update = request.config.getoption("--update-golden")

    def check(path, actual: str):
        if update:
            path.write_text(actual, newline="")
            return
        assert path.exists(), (f"{path.name} has no recorded output; run with "
                               "--update-golden and review the diff")
        assert actual == path.read_text(newline="")

    return check


def _build(cmd, cwd, hint=""):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if r.returncode != 0:
        pytest.fail(f"{' '.join(cmd)} failed in {cwd}:\n{r.stdout}{r.stderr}\n{hint}",
                    pytrace=False)


@pytest.fixture(scope="session")
def rom():
    override = os.environ.get("MINIOS_ROM")
    if override:
        return Path(override)
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


def _booted(rom, emulator_bin, directory):
    emu = EmulatorSession(rom, directory / "console.txt", emulator=emulator_bin)
    try:
        b = BasicSession(emu)
        b.boot()
    except BaseException:
        emu.close()
        raise
    return b


@pytest.fixture(scope="module")
def _basic_holder(rom, emulator_bin, tmp_path_factory):
    holder = {}

    def get():
        b = holder.get("b")
        if b is None or b.broken or not b.emu.alive:
            if b is not None:
                b.emu.close()
            holder["b"] = b = _booted(rom, emulator_bin,
                                      tmp_path_factory.mktemp("basic"))
        return b

    yield get
    if "b" in holder:
        holder["b"].emu.close()


@pytest.fixture
def basic(_basic_holder):
    b = _basic_holder()
    b.new()
    return b


@pytest.fixture
def fresh_basic(rom, emulator_bin, tmp_path):
    b = _booted(rom, emulator_bin, tmp_path)
    yield b
    b.emu.close()
