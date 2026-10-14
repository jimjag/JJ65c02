import time

import pytest

from minios_session import WozmonSession

IDLE = "\r\nA011: 10\r\n"
RX_FULL = "\r\nA011: 18\r\n"


@pytest.fixture
def woz(serial_menu):
    w = WozmonSession(serial_menu)
    w.enter()
    w.line("A012: 02")
    return w


def eventually(fn, timeout=10.0):
    deadline = time.monotonic() + timeout
    while not fn():
        assert time.monotonic() < deadline, "condition never became true"
        time.sleep(0.05)


def test_idle_status_is_tx_empty(woz):
    assert woz.line("A011") == IDLE


def test_received_byte_sets_rx_full(woz):
    woz.menu.peer.send(b"Z")
    eventually(lambda: woz.line("A011") == RX_FULL)


def test_data_read_returns_the_byte_and_clears_rx_full(woz):
    woz.menu.peer.send(b"Z")
    eventually(lambda: woz.line("A011") == RX_FULL)
    assert woz.line("A010") == "\r\nA010: 5A\r\n"
    assert woz.line("A011") == IDLE


def test_second_byte_waits_until_the_first_is_read(woz):
    woz.menu.peer.send(b"AB")
    eventually(lambda: woz.line("A011") == RX_FULL)
    assert woz.line("A010") == "\r\nA010: 41\r\n"
    eventually(lambda: woz.line("A011") == RX_FULL)
    assert woz.line("A010") == "\r\nA010: 42\r\n"


def test_a_data_write_reaches_the_peer(woz):
    woz.menu.peer.clear()
    woz.line("A010: 41")
    assert woz.menu.peer.wait_for(b"A") == b"A"


def test_peer_disconnect_leaves_the_emulator_running(woz):
    woz.menu.peer.disconnect()
    assert woz.line("A011") == IDLE
    woz.line("A010: 42")
    assert woz.line("A011") == IDLE
