import time

from x65c02_session import EmulatorSession


def test_boots_to_basic_ready(rom, emulator_bin, tmp_path, capsys):
    t0 = time.monotonic()
    with EmulatorSession(rom, tmp_path / "con.txt", emulator=emulator_bin) as s:
        s.wait_for(b"OK> ", 60)
        t_menu = time.monotonic() - t0
        s.send(b"7")
        s.wait_for(b"[C]old/[W]arm ?", 30)
        s.send(b"C")
        s.wait_for(b"\r\nReady\r\n", 60)
        t_ready = time.monotonic() - t0
        t1 = time.monotonic()
        for _ in range(20):
            s.type_text("PRINT 12345\r", echo_timeout=2.0, retries=0)
            assert s.wait_for(b"\r\nReady\r\n", 10) == b" 12345\r\n\r\nReady\r\n"
        t_typing = time.monotonic() - t1
    with capsys.disabled():
        print(f"\nmenu {t_menu:.1f}s  ready {t_ready:.1f}s  "
              f"20 statements {t_typing:.1f}s")


def test_close_does_not_wait_out_the_escape_grace_period(rom, emulator_bin, tmp_path):
    s = EmulatorSession(rom, tmp_path / "con.txt", emulator=emulator_bin)
    s.wait_for(b"OK> ", 60)
    t0 = time.monotonic()
    s.close()
    assert time.monotonic() - t0 < 0.5
