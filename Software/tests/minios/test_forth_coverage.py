"""Every MilliForth word must appear in a test or carry a reason it does not."""
import ast
import re
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE.parents[1] / "minios" / "src" / "milliforth.s"

EXCLUDED = {
    "bye": "issued by ForthSession.leave after every test",
    "key": "interactive input",
    "dump": "writes raw binary up to `here`; runs through 64 KB when nothing is defined",
    "exec": "jumps to a machine-code address",
    ":$": "internal: inline machine code",
    ";$": "internal: inline machine code",
    "exit": "internal: unnest; crashes at top level",
}


def words():
    return set(re.findall(r'^\s*def_word\s+"([^"]+)"', SOURCE.read_text(), re.M))


def scanned_tokens():
    tokens = set()
    tree = ast.parse((HERE / "test_forth.py").read_text())
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                and node.func.attr == "eval"):
            for arg in node.args[:1]:
                for const in ast.walk(arg):
                    if isinstance(const, ast.Constant) and isinstance(const.value, str):
                        tokens.update(const.value.split())
    return tokens


def test_word_table_was_parsed():
    assert {"nand", "s@", ".S", "bye"} <= words()
    assert len(words()) == 23


def test_every_word_is_tested_or_excluded():
    missing = sorted(words() - set(EXCLUDED) - scanned_tokens())
    assert not missing, f"words with no test: {missing}"


def test_exclusions_are_real_words():
    assert set(EXCLUDED) <= words()


def test_the_test_scan_finds_tokens():
    assert {"s@", "nand", ".S", ":", ";"} <= scanned_tokens()
