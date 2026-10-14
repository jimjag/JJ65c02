import pytest

from loader_data import ESC, IHEX_EOF, ihex_record
from minios_session import IhexSession, dump_ram

OK = b"Intel Hex Imported OK."
BAD = b"Intel Hex Imported with checksum error."
OVERFLOW = b"Intel Hex Import aborted with overflow error."


@pytest.fixture
def ih(loader_menu):
    x = IhexSession(loader_menu)
    try:
        x.enter()
        x.begin()
        x.peer.wait_for(b"Start Intel Hex code Transfer.")
    except BaseException:
        loader_menu.broken = True
        raise
    yield x
    if not x.left:
        loader_menu.broken = True


def test_a_good_record_and_eof_are_imported(ih, loader_menu):
    data = bytes([0xA9, 0x41, 0x8D, 0x00, 0xA8, 0x60])
    ih.send_text(ihex_record(0x0500, data) + "\n" + IHEX_EOF + "\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x0500, 6) == data


def test_several_records_and_a_page_crossing(ih, loader_menu):
    a, b = bytes(range(16)), bytes(range(0x80, 0x90))
    ih.send_text("\n".join([ihex_record(0x05F8, a), ihex_record(0x0610, b),
                            IHEX_EOF]) + "\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x05F8, 16) == a
    assert dump_ram(loader_menu, 0x0610, 16) == b


def test_a_bad_checksum_is_reported_but_the_data_is_still_stored(ih, loader_menu):
    data = bytes([0x11, 0x22, 0x33])
    ih.send_text(ihex_record(0x0540, data, bad_checksum=True) + "\n" + IHEX_EOF + "\n")
    ih.peer.wait_for(BAD)
    ih.finish()
    assert dump_ram(loader_menu, 0x0540, 3) == data


def test_lines_without_a_colon_are_ignored(ih, loader_menu):
    data = bytes([0x5A, 0xA5])
    ih.send_text("; a comment\n" + ihex_record(0x0560, data) + "\n" + IHEX_EOF + "\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x0560, 2) == data


def test_crlf_line_endings(ih, loader_menu):
    data = bytes([0x01, 0x02, 0x03, 0x04])
    ih.send_text(ihex_record(0x0570, data) + "\r\n" + IHEX_EOF + "\r\n")
    ih.peer.wait_for(OK)
    ih.finish()
    assert dump_ram(loader_menu, 0x0570, 4) == data


def test_eof_only_file(ih):
    ih.send_text(IHEX_EOF + "\n")
    ih.peer.wait_for(OK)
    ih.finish()


def test_esc_on_the_serial_line_ends_the_import(ih):
    ih.peer.send(bytes([ESC]))
    ih.peer.wait_for(OK)
    ih.finish()


def test_an_over_long_line_aborts_with_the_overflow_message(ih):
    ih.send_text(":" + "0" * 140)
    ih.peer.wait_for(OVERFLOW)
    ih.finish()


def test_a_key_other_than_l_returns_to_the_menu(loader_menu):
    try:
        x = IhexSession(loader_menu)
        x.enter()
        loader_menu.emu.send(b"x")
        x.finish()
    except BaseException:
        loader_menu.broken = True
        raise
