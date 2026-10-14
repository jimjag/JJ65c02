from minios_session import MENU


def test_banner(wozmon):
    assert wozmon.banner == "\r\nWelcome to EWOZMON 1.0.\r\n]"


def test_examine_shows_one_byte(wozmon):
    wozmon.line("0510: 5A")
    assert wozmon.line("0510") == "\r\n0510: 5A\r\n"


def test_store_reports_the_old_byte(wozmon):
    assert wozmon.line("0520: 11") == "\r\n0520: 00\r\n"
    assert wozmon.line("0520: 22") == "\r\n0520: 11\r\n"


def test_store_several_bytes_then_block_examine(wozmon):
    wozmon.line("0530: A9 41 8D 00 A8 60")
    assert wozmon.line("0530.0535") == "\r\n0530: A9 41 8D 00 A8 60\r\n"


def test_block_examine_starts_a_new_line_every_16_bytes(wozmon):
    wozmon.line("0540: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13")
    assert wozmon.line("0540.0553") == (
        "\r\n0540: 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F"
        "\r\n0550: 10 11 12 13\r\n")


def test_input_is_upper_cased(wozmon):
    wozmon.line("0560: ab")
    assert wozmon.line("0560") == "\r\n0560: AB\r\n"


def test_run_executes_stored_code_and_rts_returns_to_the_menu(wozmon):
    wozmon.line("0570: A9 41 8D 00 A8 60")
    wozmon._type("0570R\r")
    out = wozmon._wait(MENU, 15).decode("latin-1")
    wozmon.left = True
    assert out.startswith("\r\n0570: A9A\r\n1. Load RAM")


def test_q_quits_to_the_menu(wozmon):
    out = wozmon.leave()
    assert out.startswith("\r\n1. Load RAM")
    assert out.endswith("A. About\r\nOK> ")
