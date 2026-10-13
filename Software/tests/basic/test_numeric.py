import pytest

CASES = [
    ("PRINT 1/3", " .333333\n"),
    ("PRINT 2+3*4", " 14\n"),
    ("PRINT (2+3)*4", " 20\n"),
    ("PRINT 2^10", " 1024\n"),
    ("PRINT -2^2", "-4\n"),
    ("PRINT 7-10", "-3\n"),
    ("PRINT 0", " 0\n"),
    ("PRINT 1E10", " 1E+10\n"),
    ("PRINT 1/1E10", " 1E-10\n"),
    ("PRINT 123456789", " 1.23457E+08\n"),
    ("PRINT INT(3.7);INT(-3.7)", " 3-4\n"),
    ("PRINT ABS(-5);SGN(-5);SGN(0);SGN(5)", " 5-1 0 1\n"),
    ("PRINT SQR(16)", " 4\n"),
    ("PRINT 7 AND 3;7 OR 8;7 EOR 2", " 3 15 5\n"),
    ("PRINT 1<<4;256>>4", " 16 16\n"),
    ("PRINT MAX(3,9,4);MIN(3,9,4)", " 9 3\n"),
    ("PRINT 3=3;3=4;3<4", "-1 0-1\n"),
    ("PRINT $FF;%1010", " 255 10\n"),
    ('PRINT HEX$(255);" ";BIN$(5)', "FF 101\n"),
]


@pytest.mark.parametrize("source,expected", CASES, ids=[c[0] for c in CASES])
def test_numeric(basic, source, expected):
    assert basic.eval(source) == expected
