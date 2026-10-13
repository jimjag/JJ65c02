import pytest

from x65c02_session import EmulatorTimeout


def test_menu_boots(menu):
    assert menu.boot_output.endswith("OK> ")
    assert "1. Load RAM Image (via XMODEM) to @0400" in menu.boot_output


def test_wozmon_enters_and_leaves(wozmon):
    assert wozmon.banner == "\r\nWelcome to EWOZMON 1.0.\r\n]"


def test_a_hung_program_marks_the_session_broken(menu, wozmon):
    assert not menu.broken
    with pytest.raises(EmulatorTimeout):
        wozmon.line("0500", timeout=0.01)
    assert menu.broken


def test_next_test_gets_a_replaced_session(menu, wozmon):
    assert menu.emu.alive and not menu.broken
    assert wozmon.line("0500") == "\r\n0500: 00\r\n"
