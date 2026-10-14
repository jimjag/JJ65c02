import socket
import subprocess
import threading

import pytest

from serial_peer import SerialPeer
from x65c02_session import EmulatorSession, EmulatorTimeout


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
    assert peer.wait_for(b"hello") == b"hello"
    c.sendall(b"more")
    peer.read(4)
    assert peer.unread() == b""


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
    c.sendall(b"old")
    peer.wait_for(b"old")
    c.sendall(b"stale")
    peer.read(5)
    c.sendall(b"junk")
    peer.read(4)
    peer.clear()
    c.sendall(b"new")
    assert peer.wait_for(b"new") == b"new"


def test_path_stays_short_enough_for_af_unix(peer):
    assert len(str(peer.path)) < 100


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
