import pytest

from loader_data import ACK, ESC, NAK, xmodem_block
from minios_session import XmodemSession, dump_ram

LOAD = 0x0400


@pytest.fixture
def xm(loader_menu):
    x = XmodemSession(loader_menu)
    try:
        x.enter()
        x.begin()
        x.wait_c()
    except BaseException:
        loader_menu.broken = True
        raise
    yield x
    if not x.left:
        loader_menu.broken = True


def pattern(seed):
    return bytes((seed + i) & 0xFF for i in range(128))


def test_one_good_block_is_stored(xm, loader_menu):
    data = pattern(1)
    xm.send(xmodem_block(1, data))
    assert xm.reply() == ACK
    assert xm.end() == b"\x06\x04\n\rTransfer Successful!\n\r"
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data


def test_two_blocks_are_stored_back_to_back(xm, loader_menu):
    a, b = pattern(0x10), pattern(0x90)
    xm.send(xmodem_block(1, a))
    assert xm.reply() == ACK
    xm.send(xmodem_block(2, b))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 256) == a + b


def test_bad_crc_is_nakked_and_a_resend_succeeds(xm, loader_menu):
    data = pattern(0x20)
    xm.send(xmodem_block(1, data, bad_crc=True))
    assert xm.reply() == NAK
    xm.send(xmodem_block(1, data))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data


def test_a_duplicate_block_is_acked_but_not_stored_again(xm, loader_menu):
    a, b = pattern(0x30), pattern(0xB0)
    xm.send(xmodem_block(1, a))
    assert xm.reply() == ACK
    xm.send(xmodem_block(1, b))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == a
    assert dump_ram(loader_menu, LOAD + 128, 128) != b


def test_wrong_block_number_is_a_fatal_error(xm):
    xm.send(xmodem_block(3, pattern(0x40)))
    assert xm.peer.wait_for(b"Transfer Error!\n\r", 60)
    xm.finish()


def test_bad_complement_is_a_fatal_error(xm):
    xm.send(xmodem_block(1, pattern(0x50), bad_complement=True))
    assert xm.peer.wait_for(b"Transfer Error!\n\r", 60)
    xm.finish()


def test_a_non_soh_first_byte_is_nakked(xm, loader_menu):
    data = pattern(0x60)
    xm.send(b"X")
    assert xm.reply() == NAK
    xm.send(xmodem_block(1, data))
    assert xm.reply() == ACK
    xm.end()
    xm.finish()
    assert dump_ram(loader_menu, LOAD, 128) == data


def test_esc_on_the_serial_line_aborts_without_an_error_message(xm):
    xm.send(bytes([ESC]))
    xm.finish()
    assert b"Transfer Error" not in xm.peer.unread()


def test_a_key_other_than_l_returns_to_the_menu(loader_menu):
    try:
        x = XmodemSession(loader_menu)
        x.enter()
        loader_menu.emu.send(b"x")
        x.finish()
    except BaseException:
        loader_menu.broken = True
        raise


def test_a_failed_transfer_does_not_poison_the_next_one(loader_menu):
    try:
        x = XmodemSession(loader_menu)
        x.enter(); x.begin(); x.wait_c()
        x.send(xmodem_block(3, pattern(0x70)))
        x.peer.wait_for(b"Transfer Error!\n\r", 60)
        x.finish()
        data = pattern(0x71)
        y = XmodemSession(loader_menu)
        y.enter(); y.begin(); y.wait_c()
        y.send(xmodem_block(1, data))
        assert y.reply() == ACK
        y.end()
        y.finish()
    except BaseException:
        loader_menu.broken = True
        raise
    assert dump_ram(loader_menu, LOAD, 128) == data
