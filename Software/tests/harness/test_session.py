import os
from pathlib import Path

import pytest

from x65c02_session import EmulatorExited, EmulatorSession, EmulatorTimeout

FAKE = str(Path(__file__).with_name("fake_emu.py"))


@pytest.fixture
def session(tmp_path):
    s = EmulatorSession("unused.rom", tmp_path / "con.txt", emulator=FAKE)
    yield s
    s.close()


def test_wait_for_returns_output_through_match(session):
    assert session.wait_for(b"BOOT\r\n", 5) == b"BOOT\r\n"


def test_wait_for_only_sees_output_after_the_mark(session):
    session.wait_for(b"BOOT\r\n", 5)
    session.send(b"AB")
    assert session.wait_for(b"B", 5) == b"AB"
    with pytest.raises(EmulatorTimeout):
        session.wait_for(b"BOOT", 0.3)


def test_timeout_carries_pattern_and_console_tail(session):
    session.wait_for(b"BOOT\r\n", 5)
    session.send(b"XYZ")
    with pytest.raises(EmulatorTimeout) as e:
        session.wait_for(b"NEVER", 0.5)
    assert "NEVER" in str(e.value) and "XYZ" in str(e.value)


def test_exit_is_reported_as_exit_not_timeout(tmp_path, monkeypatch):
    monkeypatch.setenv("FAKE_EMU_MODE", "die")
    with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
        s.wait_for(b"BOOT\r\n", 5)
        s.send(b"!")
        with pytest.raises(EmulatorExited):
            s.wait_for(b"NEVER", 5)
        assert not s.alive


def test_close_kills_the_process_and_is_idempotent(tmp_path):
    s = EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE)
    s.wait_for(b"BOOT\r\n", 5)
    pid = s.pid
    s.close()
    s.close()
    with pytest.raises(ProcessLookupError):
        os.kill(pid, 0)


def test_context_manager_kills_on_exception(tmp_path):
    with pytest.raises(RuntimeError):
        with EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE) as s:
            pid = s.pid
            raise RuntimeError("boom")
    with pytest.raises(ProcessLookupError):
        os.kill(pid, 0)


def test_pty_output_is_kept_only_on_request(tmp_path):
    with EmulatorSession("unused.rom", tmp_path / "a.txt", emulator=FAKE) as s:
        assert s.pty_bytes is None
    with EmulatorSession("unused.rom", tmp_path / "b.txt", emulator=FAKE,
                         keep_pty=True) as s:
        assert s.pty_bytes is not None
