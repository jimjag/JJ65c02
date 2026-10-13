import pytest

IMMEDIATE = [
    ("PRINT 1/0", "\nDivide by zero Error"),
    ("FOO BAR", "\nSyntax Error"),
    ("GOTO 999", "\nUndefined statement Error"),
    ('PRINT "A"+1', "\nType mismatch Error"),
    ("RETURN", "\nRETURN without GOSUB Error"),
    ("NEXT", "\nNEXT without FOR Error"),
    ("READ A", "\nOut of DATA Error"),
    ("PRINT SQR(-1)", "\nFunction call Error"),
    ("PRINT 1E38*1E38", "\nOverflow Error"),
]


@pytest.mark.parametrize("source,expected", IMMEDIATE,
                         ids=[c[0] for c in IMMEDIATE])
def test_immediate_error(basic, source, expected):
    assert basic.eval(source) == expected


def test_error_in_program_names_the_line(basic):
    assert basic.run("""
        10 PRINT "A"
        20 PRINT 1/0
    """) == "A\n\nDivide by zero Error in line 20"


def test_subscript_out_of_range(basic):
    assert basic.run("""
        10 DIM A(3)
        20 A(4)=1
    """) == "\nArray bounds Error in line 20"


def test_interpreter_recovers_after_an_error(basic):
    basic.eval("PRINT 1/0")
    assert basic.eval("PRINT 2+2") == " 4\n"
