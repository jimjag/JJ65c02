"""Every Supermon+ command letter must be exercised by a test or carry a reason."""
import ast
import re
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE.parents[1] / "minios" / "src" / "supermon.s"

EXCLUDED = {
    "X": "issued by SupermonSession.leave after every test",
}


def commands():
    m = re.search(r'\.IFDEF ENABLE_ASSEMBLER\s*\nKEYW:\s*\.byte "([^"]+)"',
                  SOURCE.read_text())
    return set(m.group(1)) if m else set()


def scanned_commands():
    found = set()
    tree = ast.parse((HERE / "test_supermon.py").read_text())
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)):
            continue
        if node.func.attr == "line" and node.args:
            first = node.args[0]
        elif node.func.attr == "assemble":
            for kw in node.keywords:
                if kw.arg == "cmd" and isinstance(kw.value, ast.Constant):
                    found.add(kw.value.value)
            found.add("A")
            continue
        else:
            continue
        for const in ast.walk(first):
            if isinstance(const, ast.Constant) and isinstance(const.value, str):
                if const.value.strip():
                    found.add(const.value.strip()[0])
                break
    return found


def test_command_table_was_parsed():
    assert commands() == set("ACDFGHJMRTX.>;")


def test_every_command_is_tested_or_excluded():
    missing = sorted(commands() - set(EXCLUDED) - scanned_commands())
    assert not missing, f"commands with no test: {missing}"


def test_exclusions_are_real_commands():
    assert set(EXCLUDED) <= commands()


def test_the_test_scan_finds_commands():
    assert {"M", "R", ">", ";", "D", "J", "G", "."} <= scanned_commands()
