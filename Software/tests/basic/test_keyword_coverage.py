"""Every EhBASIC keyword must appear in a test or carry a reason it does not."""
import re
from pathlib import Path

HERE = Path(__file__).parent
EHBASIC = HERE.parents[1] / "minios" / "src" / "ehbasic.s"

EXCLUDED = {
    "NEW": "issued by BasicSession.run before every program",
    "RUN": "issued by BasicSession.run for every program",
    "LOAD": "XMODEM transfer",
    "SAVE": "XMODEM transfer",
    "TTY": "switches the console device",
    "EXIT": "leaves BASIC",
    "CALL": "runs machine code",
    "USR": "runs machine code",
    "IRQ": "needs an interrupt source",
    "NMI": "needs an interrupt source",
    "RETIRQ": "needs an interrupt source",
    "RETNMI": "needs an interrupt source",
    "OFF": "only used with ON IRQ/NMI",
    "WAIT": "blocks on a memory location",
    "GET": "interactive input",
    "INPUT": "interactive input",
    "NULL": "changes console state for the rest of the session",
    "WIDTH": "changes console state for the rest of the session",
}


def keywords():
    src = EHBASIC.read_text()
    found = set()
    for label, rest in re.findall(r'^LBB_(\w+):\s*\n\s*\.byte\s+"([^"]*)"',
                                  src, re.M):
        word = (label[0] + rest).rstrip("(")
        if rest[0].isalpha():
            found.add(word)
    return found


def test_keyword_table_was_parsed():
    assert {"PRINT", "CSTR$", "RECTF", "VARPTR"} <= keywords()
    assert len(keywords()) > 90


def test_every_keyword_is_tested_or_excluded():
    text = "\n".join(p.read_text() for p in
                     [*HERE.glob("test_*.py"), *(HERE / "golden").glob("*.bas")]
                     if p.name != Path(__file__).name)
    missing = sorted(
        k for k in keywords() - set(EXCLUDED)
        if not re.search(r"(?<![A-Z])" + re.escape(k) +
                         ("" if k == "FN" else r"(?![A-Z$])"), text))
    assert not missing, f"keywords with no test: {missing}"


def test_exclusions_are_real_keywords():
    assert set(EXCLUDED) <= keywords()
