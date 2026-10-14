import re

import pytest

REGS = r"; [0-9A-F]{4}( [0-9A-F]{2}){5} "
HEADER = "   PC  SR AC XR YR SP   V1.2+"


def lines(out):
    return [ln.rstrip() for ln in out.split("\r\n") if ln.strip()]


def listing(out):
    return [ln for ln in lines(out) if not ln.startswith("A ")]


def set_regs(sm, pc, sr="00", ac="00", xr="00", yr="00", sp="FF"):
    sm.line(f"; {pc} {sr} {ac} {xr} {yr} {sp}")


def test_banner(supermon):
    assert re.fullmatch(
        r"\r\n\r\nSUPERMON\+ @ \$[0-9A-F]{4} \r\n\r\n" + re.escape(HEADER)
        + r"\r\n" + REGS + r"\r\n", supermon.banner)


def test_register_display(supermon):
    set_regs(supermon, "0500", "00", "11", "22", "33", "FF")
    assert lines(supermon.line("R")) == [HEADER, "; 0500 00 11 22 33 FF"]


def test_alter_memory_redisplays_the_line(supermon):
    out = supermon.line(">0580 41 42 43 44 45 46 47 48")
    assert lines(out) == [">0580 41 42 43 44 45 46 47 48 00 00 00 00 00 00 00 00:ABCDEFGH........"]


def test_memory_dump_one_line(supermon):
    supermon.line(">0590 41 42")
    assert lines(supermon.line("M0590 059F")) == [
        ">0590 41 42 00 00 00 00 00 00 00 00 00 00 00 00 00 00:AB.............."]


def test_memory_dump_two_lines(supermon):
    out = lines(supermon.line("M05A0 05AF"))
    assert len(out) == 1
    out = lines(supermon.line("M05A0 05B0"))
    assert [ln[:5] for ln in out] == [">05A0", ">05B0"]


def test_fill(supermon):
    assert lines(supermon.line("F0600 060F AA")) == []
    assert lines(supermon.line("M0600 060F")) == [
        ">0600 " + " ".join(["AA"] * 16) + ":" + "." * 16]


def test_transfer_then_compare_equal(supermon):
    supermon.line("F0610 061F 5A")
    supermon.line("T0610 061F 0620")
    assert lines(supermon.line("M0620 062F")) == [
        ">0620 " + " ".join(["5A"] * 16) + ":" + "Z" * 16]
    assert lines(supermon.line("C0610 061F 0620")) == []


def test_compare_reports_each_mismatch(supermon):
    supermon.line("F0630 063F 11")
    supermon.line("F0640 064F 11")
    supermon.line(">0642 22")
    assert lines(supermon.line("C0630 063F 0640")) == ["0632"]


def test_hunt_finds_a_byte_string(supermon):
    supermon.line(">0650 43 44 45")
    assert lines(supermon.line("H0650 065F 44 45")) == ["0651"]


def test_disassemble_a_short_routine(supermon):
    supermon.line(">0660 A9 41 8D 00 A8 60")
    assert lines(supermon.line("D0660 0665")) == [
        ". 0660  A9 41    LDA  #$41",
        ". 0662  8D 00 A8 STA  $A800",
        ". 0665  60       RTS"]


# (source, bytes) covering each 65C02 addressing mode and the bit forms
CASES = [
    ("NOP", "EA"),
    ("LDA #$41", "A9 41"),
    ("LDA $12", "A5 12"),
    ("LDA $12,X", "B5 12"),
    ("LDA $1234", "AD 34 12"),
    ("LDA $1234,X", "BD 34 12"),
    ("LDA $1234,Y", "B9 34 12"),
    ("LDA ($12,X)", "A1 12"),
    ("LDA ($12),Y", "B1 12"),
    ("LDA ($12)", "B2 12"),
    ("JMP ($1234)", "6C 34 12"),
    ("JMP ($1234,X)", "7C 34 12"),
    ("STZ $12", "64 12"),
    ("RMB5 $12", "57 12"),
    ("SMB2 $12", "A7 12"),
    ("BBR3 $12,$0510", "3F 12 EB"),
]


def mnemonic_field(src):
    mnem, _, operand = src.partition(" ")
    return mnem + " " * (5 - len(mnem)) + operand


def test_assemble_then_disassemble_round_trip(supermon):
    addr, steps, expect = 0x0500, [], []
    for src, raw in CASES:
        n = len(raw.split())
        expect.append((addr, raw, src))
        steps.append((src, f"{addr + n:04X}"))
        addr += n
    rows = listing(supermon.assemble("0500", steps))
    assert len(rows) == len(CASES)
    for got, (a, raw, src) in zip(rows, expect):
        assert got == f"{a:04X}  {raw.ljust(9)}{mnemonic_field(src)}".rstrip()
    last = f"{expect[-1][0]:04X}"
    back = lines(supermon.line(f"D0500 {last}"))
    assert back == [f". {a:04X}  {raw.ljust(9)}{mnemonic_field(src)}".rstrip()
                    for a, raw, src in expect]


def test_dot_is_an_alias_for_assemble(supermon):
    out = listing(supermon.assemble("0540", [("INX", "0541")], cmd="."))
    assert out == ["0540  E8       INX"]


def test_bad_mnemonic_is_an_error_and_leaves_assemble_mode(supermon):
    assert lines(supermon.line("A0500 XYZ")) == ["?"]
    assert lines(supermon.line("R"))[0] == HEADER


def test_unknown_command(supermon):
    assert lines(supermon.line("Z")) == ["?"]


@pytest.mark.parametrize("cmd", ["$41", "+65", "&101", "%1000001"])
def test_base_conversion(supermon, cmd):
    assert supermon.line(cmd) == "\r\n $0041 \r\n +65\r\n &101\r\n %1000001\r\n"


def test_base_conversion_of_zero(supermon):
    assert supermon.line("$0") == "\r\n $0000 \r\n +0\r\n &0\r\n %0\r\n"


def test_jsr_runs_a_routine_and_shows_its_registers(supermon):
    supermon.line(">0670 A9 41 8D 00 A8 60")
    set_regs(supermon, "0000")
    out = supermon.line("J0670")
    assert out.startswith("A\r\n" + HEADER)
    assert re.search(r"; 0670 [0-9A-F]{2} 41 ", out)


def test_go_runs_code_that_returns_to_supermon(supermon):
    entry = re.search(r"SUPERMON\+ @ \$([0-9A-F]{4}) ", supermon.banner).group(1)
    lo, hi = entry[2:], entry[:2]
    supermon.line(f">0680 A9 41 8D 00 A8 4C {lo} {hi}")
    set_regs(supermon, "0680")
    out = supermon.line("G0680")
    assert out.startswith("A\r\n\r\nSUPERMON+ @ $")


def test_x_returns_to_the_menu(supermon):
    out = supermon.leave()
    assert out.startswith("\r\n1. Load RAM")
    assert out.endswith("A. About\r\nOK> ")
