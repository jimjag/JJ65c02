PROMPT = b"\r\nReady\r\n"


def test_two_live_str_values_do_not_alias(basic):
    # 73df9e9: STR$ returned a pointer into the shared conversion buffer.
    assert basic.eval('A$=STR$(12345):B$=STR$(777):PRINT A$;"|";B$') \
        == " 12345| 777\n"


def test_backspace_erases_the_character(basic):
    # d2d9636: backspace must echo BS, space, BS, and remove the character.
    emu = basic.emu
    emu.type_text("PRINT 12")
    emu.send(b"\x08")
    emu.expect_exact(b"\x08 \x08", 5.0)
    emu.type_text("3\r")
    assert emu.wait_for(PROMPT, 10) == b" 13\r\n" + PROMPT


def test_stop_then_cont_resumes(basic):
    assert basic.run("""
        10 PRINT "A"
        20 STOP
        30 PRINT "B"
    """) == "A\n\nBreak in line 20"
    assert basic.eval("CONT") == "B\n"
