import pytest

from minios_session import prompts_for


@pytest.mark.parametrize("line,expected", [
    ("s@ .", 2),
    (".S", 1),
    ("s@ s@ + .", 4),
    (": foo s@ ;", 2),
    (": foo s@ s@ + ;", 2),
    ("foo", 1),
    (": a s@ ; : b a ; b .", 6),
    ("", 0),
])
def test_prompts_for(line, expected):
    assert prompts_for(line) == expected
