"""Each golden/NAME.bas is run and its console output compared with NAME.out.

Record or refresh the outputs with --update-golden, then review the diff.
"""
from pathlib import Path

import pytest

GOLDEN = Path(__file__).parent / "golden"
PROGRAMS = sorted(GOLDEN.glob("*.bas"))


@pytest.mark.parametrize("program", PROGRAMS, ids=[p.stem for p in PROGRAMS])
def test_program_output_is_unchanged(basic, golden, program):
    golden(program.with_suffix(".out"), basic.run(program.read_text(), timeout=120))


def test_boot_and_menu_text_is_unchanged(fresh_basic, golden):
    golden(GOLDEN / "boot.txt", fresh_basic.boot_output)
