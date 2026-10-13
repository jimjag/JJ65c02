def test_for_step_and_reverse(basic):
    assert basic.run("""
        10 FOR I=10 TO 1 STEP -3
        20 PRINT I;
        30 NEXT
    """) == " 10 7 4 1"


def test_nested_for(basic):
    assert basic.run("""
        10 FOR I=1 TO 2:FOR J=1 TO 2
        20 PRINT I*10+J;
        30 NEXT J:NEXT I
    """) == " 11 12 21 22"


def test_gosub_return(basic):
    assert basic.run("""
        10 GOSUB 100:GOSUB 100:END
        100 PRINT "S";:RETURN
    """) == "SS"


def test_if_then_else(basic):
    assert basic.run("""
        10 FOR I=1 TO 3
        20 IF I=2 THEN PRINT "T"; ELSE PRINT "F";
        30 NEXT
    """) == "FTF"


def test_on_goto(basic):
    assert basic.run("""
        10 FOR I=1 TO 3:ON I GOTO 100,200,300
        100 PRINT "A";:GOTO 400
        200 PRINT "B";:GOTO 400
        300 PRINT "C";
        400 NEXT
    """) == "ABC"


def test_do_loop_until(basic):
    assert basic.run("""
        10 I=0
        20 DO:I=I+1:PRINT I;:LOOP UNTIL I=3
    """) == " 1 2 3"


def test_do_loop_while(basic):
    assert basic.run("""
        10 I=3
        20 DO:PRINT I;:I=I-1:LOOP WHILE I>0
    """) == " 3 2 1"


def test_def_fn(basic):
    assert basic.run("""
        10 DEF FNS(X)=X*X
        20 PRINT FNS(7)
    """) == " 49\n"


def test_inc_dec(basic):
    assert basic.run("""
        10 A=1:B=9:INC A:DEC B
        20 PRINT A;B
    """) == " 2 8\n"


def test_swap_numeric(basic):
    assert basic.run("""
        10 A=1:B=9:SWAP A,B
        20 PRINT A;B
    """) == " 9 1\n"


def test_swap_string(basic):
    assert basic.run("""
        10 A$="X":B$="YZ":SWAP A$,B$
        20 PRINT A$;B$;LEN(A$)
    """) == "YZX 2\n"


def test_swap_array_elements(basic):
    assert basic.run("""
        10 DIM C(2):C(0)=1:C(1)=2:SWAP C(0),C(1)
        20 PRINT C(0);C(1)
    """) == " 2 1\n"


def test_swap_mixed_types_is_a_type_mismatch(basic):
    assert basic.run("""
        10 A=5:B$="HELLO":SWAP A,B$
    """) == "\nType mismatch Error in line 10"


def test_list_round_trips_a_line(basic):
    basic.enter("10 PRINT 1+2")
    assert basic.eval("LIST") == "\n10 PRINT 1+2\n"
