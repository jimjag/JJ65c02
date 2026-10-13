import os

import pytest

from sim_helpers import STARTED_SIM_PIDS

pytestmark = pytest.mark.sim


def test_emulator_and_sim_connect_and_snapshot(sim_basic):
    sim, basic = sim_basic
    assert basic.eval("PRINT 1/3") == " .333333\n"
    bmp = sim.snapshot()
    assert (bmp.width, bmp.height) == (640, 480)


def test_socket_path_is_short_and_private(sim_basic):
    sim, _ = sim_basic
    assert len(str(sim.socket)) < 100
    assert str(sim.socket) != "/tmp/jj6502.sock"


def test_nothing_survives_teardown():
    assert STARTED_SIM_PIDS, "an earlier test in this file should have started a sim"
    for pid in STARTED_SIM_PIDS:
        with pytest.raises(ProcessLookupError):
            os.kill(pid, 0)
