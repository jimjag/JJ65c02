def test_array(basic):
    assert basic.run("""
        10 DIM A(5)
        20 FOR I=0 TO 5:A(I)=I*2:NEXT
        30 PRINT A(0);A(5)
    """) == " 0 10\n"


def test_two_dimensional_array(basic):
    assert basic.run("""
        10 DIM A(2,2):A(1,2)=7:A(2,1)=9
        20 PRINT A(1,2);A(2,1);A(0,0)
    """) == " 7 9 0\n"


def test_string_array(basic):
    assert basic.run("""
        10 DIM A$(2):A$(0)="X":A$(2)="Z"
        20 PRINT A$(0);A$(1);A$(2)
    """) == "XZ\n"


def test_data_read_restore(basic):
    assert basic.run("""
        10 DATA 1,2,"THREE"
        20 READ A,B,C$:PRINT A;B;C$
        30 RESTORE:READ A:PRINT A
    """) == " 1 2THREE\n 1\n"


def test_poke_peek_and_doke_deek(basic):
    assert basic.run("""
        10 POKE $7000,171:DOKE $7002,4660
        20 PRINT PEEK($7000);DEEK($7002)
    """) == " 171 4660\n"
