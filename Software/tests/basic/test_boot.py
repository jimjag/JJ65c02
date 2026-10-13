import time

from x65c02_session import EmulatorSession


def test_twenty_statements_in_a_row(fresh_basic):
    for _ in range(20):
        assert fresh_basic.eval("PRINT 12345") == " 12345\n"


def test_close_does_not_wait_out_the_escape_grace_period(rom, emulator_bin, tmp_path):
    s = EmulatorSession(rom, tmp_path / "con.txt", emulator=emulator_bin)
    s.wait_for(b"OK> ", 60)
    t0 = time.monotonic()
    s.close()
    assert time.monotonic() - t0 < 0.5
