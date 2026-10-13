import os
from pathlib import Path

import pytest

from x65c02_session import (EchoMismatch, EmulatorExited, EmulatorSession,
                            EmulatorTimeout)

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


def _mode_session(tmp_path, monkeypatch, mode):
    monkeypatch.setenv("FAKE_EMU_MODE", mode)
    s = EmulatorSession("unused.rom", tmp_path / "c.txt", emulator=FAKE)
    s.wait_for(b"BOOT\r\n", 5)
    return s


def test_type_text_confirms_every_character(session):
    session.wait_for(b"BOOT\r\n", 5)
    session.type_text("PRINT 1\r")
    assert session.tail().endswith(b"PRINT 1\r\n")
    with pytest.raises(EmulatorTimeout):
        session.wait_for(b"1", 0.2)          # mark is past the whole echo


def test_dropped_key_is_resent_when_retries_are_requested(tmp_path, monkeypatch):
    s = _mode_session(tmp_path, monkeypatch, "drop-first")
    try:
        s.type_text("PLOT", echo_timeout=0.3, retries=1)
        assert s.tail().endswith(b"BOOT\r\nPLOT")
    finally:
        s.close()


def test_key_never_echoed_fails_naming_the_character(tmp_path, monkeypatch):
    s = _mode_session(tmp_path, monkeypatch, "mute")
    try:
        with pytest.raises(EmulatorTimeout) as e:
            s.type_text("Q", echo_timeout=0.2)
        assert "b'Q'" in str(e.value)
    finally:
        s.close()


def test_wrong_echo_is_a_mismatch_not_a_pass(tmp_path, monkeypatch):
    s = _mode_session(tmp_path, monkeypatch, "dup")
    try:
        with pytest.raises(EchoMismatch):
            s.type_text("AB", echo_timeout=0.3)
    finally:
        s.close()


def test_late_echo_is_waited_for_not_retyped(tmp_path, monkeypatch):
    # EhBASIC takes about a second to echo the first key after a program line.
    s = _mode_session(tmp_path, monkeypatch, "late")
    try:
        s.type_text("RU")
        assert s.tail().endswith(b"BOOT\r\nRU")
    finally:
        s.close()


def test_cli_survives_the_emulator_dying_during_a_send(tmp_path, monkeypatch):
    import subprocess
    import sys
    from pathlib import Path
    root = Path(__file__).resolve().parents[2]
    script = tmp_path / "s.txt"
    script.write_text("0.0 !" + "x" * 20000 + "\n")
    monkeypatch.setenv("FAKE_EMU_MODE", "die")
    monkeypatch.setenv("X65C02", str(Path(__file__).with_name("fake_emu.py")))
    for _ in range(3):
        r = subprocess.run(
            [sys.executable, str(root / "Harness" / "x65c02-headless.py"),
             "rom", str(script), "-o", str(tmp_path / "t.txt"),
             "--char-delay", "0", "--boot", "0.2"],
            capture_output=True, text=True, timeout=60)
        assert "Traceback" not in r.stderr, r.stderr
        assert r.returncode == 1
