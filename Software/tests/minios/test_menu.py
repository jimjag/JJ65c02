from pathlib import Path

import pytest

from minios_session import MENU

GOLDEN = Path(__file__).parent / "golden"


def test_menu_text_is_unchanged(menu, golden):
    golden(GOLDEN / "menu.txt", menu.boot_output)


@pytest.mark.parametrize("key", [b"Z", b"a", b"0"])
def test_invalid_key_redraws_the_menu(menu, key):
    out = menu.press(key, MENU).decode("latin-1").replace("\r\n", "\n")
    assert out.startswith("\n1. Load RAM Image")
    assert menu.boot_output.endswith(out)


def test_about_prints_the_project_url_then_the_menu(menu):
    out = menu.press(b"A", MENU).decode("latin-1")
    assert out.startswith("\r\nhttps://github.com/jimjag/JJ6502\r\n1. Load RAM")


# Stop at the first output line: the emulator is too slow for the ROM's cycle-counted delay loops.
def _starts(menu, key, banner):
    out = menu.press(key, banner, timeout=15).decode("latin-1")
    menu.broken = True
    return out


def test_clear_ram_starts(menu):
    assert _starts(menu, b"4", b" Cleaning RAM... ") == "\r\n Cleaning RAM... "


def test_ram_test_starts(menu):
    assert _starts(menu, b"5", b" Testing RAM... ") == "\r\n Testing RAM... "


def test_run_program_starts(menu):
    assert _starts(menu, b"3", b"Running RAM@$0400\r\n") == "\r\n Running RAM@$0400\r\n"
