import pytest

from x65c02_session import EmulatorTimeout


def test_eval_returns_only_program_output(basic):
    assert basic.eval("PRINT 1/3") == " .333333\n"


def test_print_list(basic):
    assert basic.eval('PRINT "A";1;-2;"B"') == "A 1-2B\n"


def test_run_program(basic):
    out = basic.run("""
        10 FOR I=1 TO 3
        20 PRINT I*I
        30 NEXT
    """)
    assert out == " 1\n 4\n 9\n"


def test_new_between_tests_clears_the_program(basic):
    assert basic.eval("LIST") == "\n"


def test_error_text_is_returned(basic):
    assert basic.eval("PRINT 1/0") == "\nDivide by zero Error"


def test_runaway_program_marks_session_broken(fresh_basic):
    with pytest.raises(EmulatorTimeout):
        fresh_basic.run("10 GOTO 10", timeout=2.0)
    assert fresh_basic.broken


def test_runaway_program_on_the_shared_session(basic):
    with pytest.raises(EmulatorTimeout):
        basic.run("10 GOTO 10", timeout=2.0)


def test_shared_session_is_replaced_after_a_runaway(basic):
    # Depends on the test above having left the module's session looping.
    assert basic.eval("PRINT 2") == " 2\n"
