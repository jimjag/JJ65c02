import pytest

CASES = [
    ('PRINT "HELLO"', "HELLO\n"),
    ('PRINT "AB"+"CD"', "ABCD\n"),
    ('PRINT LEN("HELLO")', " 5\n"),
    ('PRINT LEFT$("HELLO",2);"|";RIGHT$("HELLO",2);"|";MID$("HELLO",2,3)',
     "HE|LO|ELL\n"),
    ('PRINT MID$("HELLO",4)', "LO\n"),
    ('PRINT ASC("A");CHR$(66)', " 65B\n"),
    ('PRINT STR$(12.5)+"X"', " 12.5X\n"),
    ('PRINT STR$(-3)+"X"', "-3X\n"),
    ('PRINT CSTR$(1234)+"X"', "1234X\n"),
    ('PRINT CSTR$(-5)+"X"', "-5X\n"),
    ('PRINT VAL("12.5")+1', " 13.5\n"),
    ('PRINT VAL("ABC")', " 0\n"),
    ('PRINT UCASE$("abC");LCASE$("ABc")', "ABCabc\n"),
    ('PRINT "A"<"B";"B"<"A";"A"="A"', "-1 0-1\n"),
    ('A$="X":B$=A$+A$:PRINT B$;LEN(B$)', "XX 2\n"),
]


@pytest.mark.parametrize("source,expected", CASES, ids=[c[0] for c in CASES])
def test_strings(basic, source, expected):
    assert basic.eval(source) == expected
