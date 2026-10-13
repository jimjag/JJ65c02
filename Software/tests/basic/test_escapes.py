import pytest

ESC = "\x1b"

CASES = [
    ("PLOT 1,2,3,4,5", "[Z22;1;2;3;4;5Z"),
    ("RECT 10,20,30,40,5", "[Z23;10;20;30;40;5Z"),
    ("RECTF 10,20,30,40,5", "[Z24;10;20;30;40;5Z"),
    ("CIRCLE 100,90,25,7", "[Z25;100;90;25;7Z"),
    ("CIRCLEF 100,90,25,7", "[Z26;100;90;25;7Z"),
    ("RECT 0,0,639,479,15", "[Z23;0;0;639;479;15Z"),
    ("X=5:RECT X,X*2,X+1,40,X", "[Z23;5;10;6;40;5Z"),
]


@pytest.mark.parametrize("source,body", CASES, ids=[c[0] for c in CASES])
def test_graphics_statement_emits_exact_escape(basic, source, body):
    assert basic.eval(source) == ESC + body


@pytest.mark.parametrize("source", ["RECT 1,2,3", "CIRCLE 1,2", "PLOT 1,2,3"])
def test_too_few_arguments_is_a_syntax_error(basic, source):
    assert basic.eval(source) == "\nSyntax Error"
