import socket
import subprocess
import tempfile
import threading
import time

import pytest

from serial_peer import SerialPeer
from x65c02_session import EmulatorSession, EmulatorTimeout


def _wait_until(pred, timeout=5.0):
    deadline = time.monotonic() + timeout
    while not pred():
        if time.monotonic() >= deadline:
            raise AssertionError("condition not reached")
        time.sleep(0.005)


@pytest.fixture
def peer():
    p = SerialPeer()
    yield p
    p.close()


def _connect(path):
    c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    c.connect(str(path))
    return c


def test_bytes_flow_both_ways(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    peer.send(b"abc")
    assert c.recv(3) == b"abc"
    c.sendall(b"xyzC")
    assert peer.wait_for(b"z") == b"xyz"
    assert peer.read(1) == b"C"


def test_unread_does_not_consume(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    c.sendall(b"hello")
    _wait_until(lambda: peer.unread() == b"hello")
    assert peer.unread() == b"hello"
    assert peer.read(5) == b"hello"


def test_wait_for_times_out_with_the_unread_tail(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    c.sendall(b"abc")
    with pytest.raises(EmulatorTimeout, match="abc"):
        peer.wait_for(b"zzz", timeout=0.2)


def test_clear_discards_unread_bytes(peer):
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    c.sendall(b"stale")
    _wait_until(lambda: peer.unread() == b"stale")
    peer.clear()
    assert peer.unread() == b""
    c.sendall(b"new")
    assert peer.wait_for(b"new") == b"new"


def test_path_stays_short_enough_for_af_unix(peer):
    assert len(str(peer.path)) < 100


def test_failed_setup_removes_its_temp_directory(monkeypatch, tmp_path):
    base = tmp_path / ("d" * 100)
    base.mkdir()
    monkeypatch.setattr(tempfile, "tempdir", str(base))
    with pytest.raises(ValueError):
        SerialPeer()
    assert list(base.iterdir()) == []


def test_acia_path_becomes_dash_a(monkeypatch, tmp_path):
    seen = {}

    class Boom(Exception):
        pass

    def fake_popen(cmd, **kw):
        seen["cmd"] = cmd
        raise Boom

    monkeypatch.setattr(subprocess, "Popen", fake_popen)
    with pytest.raises(Boom):
        EmulatorSession("rom", tmp_path / "c.txt", emulator="emu",
                        acia_path="/x/s")
    assert seen["cmd"][seen["cmd"].index("-a") + 1] == "/x/s"


def test_xmodem_reply_gives_up_when_only_c_requests_arrive(peer):
    from minios_session import XmodemSession

    class Stub:
        emu = None

    stub = Stub()
    stub.peer = peer
    t = threading.Thread(target=lambda: peer.accept(5))
    t.start()
    c = _connect(peer.path)
    t.join()
    stop = threading.Event()

    def trickle():
        while not stop.is_set():
            try:
                c.sendall(b"C")
            except OSError:
                return
            time.sleep(0.05)

    threading.Thread(target=trickle, daemon=True).start()
    result = []

    def run():
        try:
            XmodemSession(stub).reply(timeout=1.0)
        except BaseException as e:
            result.append(e)

    r = threading.Thread(target=run, daemon=True)
    start = time.monotonic()
    r.start()
    r.join(5)
    stop.set()
    c.close()
    assert not r.is_alive(), "reply() never gave up"
    assert time.monotonic() - start < 2.5
    assert isinstance(result[0], EmulatorTimeout)
