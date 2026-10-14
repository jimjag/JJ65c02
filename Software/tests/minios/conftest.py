import pytest

from minios_session import (ForthSession, MenuSession, SupermonSession,
                            WozmonSession)
from serial_peer import SerialPeer
from x65c02_session import EmulatorError, EmulatorSession


def _booted(rom, emulator_bin, directory):
    emu = EmulatorSession(rom, directory / "console.txt", emulator=emulator_bin)
    try:
        m = MenuSession(emu)
        m.boot()
    except BaseException:
        emu.close()
        raise
    return m


@pytest.fixture(scope="module")
def _menu_holder(rom, emulator_bin, tmp_path_factory):
    holder = {}

    def get():
        m = holder.get("m")
        if m is None or m.broken or not m.emu.alive:
            if m is not None:
                m.emu.close()
            holder["m"] = m = _booted(rom, emulator_bin,
                                      tmp_path_factory.mktemp("menu"))
        return m

    yield get
    if "m" in holder:
        holder["m"].emu.close()


@pytest.fixture
def menu(_menu_holder):
    return _menu_holder()


def _program(cls):
    @pytest.fixture
    def fixture(menu):
        p = cls(menu)
        p.enter()
        yield p
        if not p.left and not menu.broken and menu.emu.alive:
            try:
                p.leave()
            except EmulatorError:
                pass
    return fixture


wozmon = _program(WozmonSession)
forth = _program(ForthSession)
supermon = _program(SupermonSession)


def _booted_serial(rom, emulator_bin, directory):
    peer = SerialPeer()
    emu = EmulatorSession(rom, directory / "console.txt", emulator=emulator_bin,
                          acia_path=peer.path)
    try:
        peer.accept(10.0)
        m = MenuSession(emu)
        m.peer = peer
        m.boot()
    except BaseException:
        emu.close()
        peer.close()
        raise
    return m


@pytest.fixture
def serial_menu(rom, emulator_bin, tmp_path):
    m = _booted_serial(rom, emulator_bin, tmp_path)
    yield m
    m.close()
