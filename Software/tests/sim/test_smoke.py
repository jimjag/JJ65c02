"""Shapes are asserted by pixel count and size, not fixed position: console text
fills the screen, so every line feed scrolls the framebuffer, graphics included.
"""
import pytest

from bitmap import PALETTE
from sim_helpers import eventually

pytestmark = pytest.mark.sim


def extent(bmp, colour):
    box = bmp.bbox(PALETTE[colour])
    assert box is not None, f"no pixels of colour {colour} on screen"
    x0, y0, x1, y1 = box
    return x0, x1 - x0 + 1, y1 - y0 + 1


def test_rectf_fills_a_solid_box(sim_basic):
    sim, basic = sim_basic
    assert sim.snapshot().count(PALETTE[10]) == 0
    basic.eval("RECTF 300,200,50,50,10")

    def check():
        now = sim.snapshot()
        assert extent(now, 10) == (300, 50, 50)
        assert now.count(PALETTE[10]) == 50 * 50
    eventually(check)


def test_rect_draws_an_outline_only(sim_basic):
    sim, basic = sim_basic
    basic.eval("RECT 100,300,50,50,9")

    def check():
        now = sim.snapshot()
        assert extent(now, 9) == (100, 50, 50)
        assert now.count(PALETTE[9]) == 4 * 49
    eventually(check)


def test_plot_draws_a_line(sim_basic):
    sim, basic = sim_basic
    basic.eval("PLOT 400,300,440,300,12")

    def check():
        now = sim.snapshot()
        assert extent(now, 12) == (400, 41, 1)
        assert now.count(PALETTE[12]) == 41
    eventually(check)


def test_text_colour_change_applies_to_printed_text(sim_basic):
    sim, basic = sim_basic
    assert sim.snapshot().count(PALETTE[13]) == 0
    basic.eval('PRINT CHR$(27);"[Z2;13Z";"HELLO"')

    def check():
        assert sim.snapshot().count(PALETTE[13]) > 0
    eventually(check)


def test_clear_screen_removes_drawing(sim_basic):
    sim, basic = sim_basic
    basic.eval("RECTF 300,200,50,50,10")

    def drawn():
        assert sim.snapshot().count(PALETTE[10]) == 2500
    eventually(drawn)
    basic.eval('PRINT CHR$(27);"[2J";')

    def cleared():
        assert sim.snapshot().count(PALETTE[10]) == 0
    eventually(cleared)
