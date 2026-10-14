from minios_session import MENU

SCRATCH = "s@ s@ +"


def test_banner(forth):
    assert forth.banner == "\r\nMilliForth for JJ6502\r\nok> "


def test_s_at_pushes_0022(forth):
    assert forth.eval("s@ .") == " 0022"


def test_dot_does_not_drop(forth):
    assert forth.eval("s@ . .") == " 0022 0022"


def test_stack_display(forth):
    assert forth.eval(".S") == "S0498 00 "
    assert forth.eval("s@ s@ .S") == "S0494 02  0022 0022"


def test_return_stack_display(forth):
    assert forth.eval(".R") == "R04E0 00 "


def test_plus(forth):
    assert forth.eval("s@ s@ + .") == " 0044"


def test_nand(forth):
    assert forth.eval("s@ s@ nand .") == " FFDD"


def test_halve(forth):
    assert forth.eval("s@ 2/ .") == " 0011"


def test_zero_test(forth):
    assert forth.eval("s@ 0# .") == " FFFF"


def test_fetch(forth):
    forth.eval(f"s@ {SCRATCH} !")
    assert forth.eval(f"{SCRATCH} @ .") == " 0022"


def test_store_then_fetch(forth):
    forth.eval(f"{SCRATCH} {SCRATCH} !")
    assert forth.eval(f"{SCRATCH} @ .") == " 0044"


def test_emit_writes_the_low_byte(forth):
    assert forth.eval("s@ emit") == '"'


def test_colon_definition(forth):
    forth.eval(": sq s@ s@ + ;")
    assert forth.eval("sq .") == " 0044"


def test_unknown_word_aborts_silently_and_clears_the_stack(forth):
    assert forth.eval("s@ nonesuch", prompts=2) == ""
    assert forth.eval(".S") == "S0498 00 "


def test_abort_clears_the_stack(forth):
    forth.eval("s@ abort", prompts=2)
    assert forth.eval(".S") == "S0498 00 "


def test_words_lists_the_dictionary(forth):
    out = forth.eval("words")
    for name in ["tty", "bye", "abort", ".S", ".R", "dump", "words", ".", "2/",
                 "exec", ":$", ";$", "key", "emit", "!", "nand", "+", "@",
                 "0#", "s@", ";", ":", "exit"]:
        assert f" {name} " in out, name


def test_upper_case_words_are_unknown(forth):
    forth.eval("S@", prompts=1)
    assert forth.eval(".S") == "S0498 00 "


def test_tty_is_a_no_op_on_the_sim_build(forth):
    assert forth.eval("tty") == ""


def test_definitions_do_not_survive_re_entering_from_the_menu(menu, forth):
    forth.eval(": foo s@ ;")
    forth.leave()
    forth.enter()
    forth.left = False
    forth.eval("foo", prompts=1)
    assert forth.eval(".S") == "S0498 00 "


def test_bye_returns_to_the_menu(forth):
    out = forth.leave()
    assert out.startswith("\r\n1. Load RAM")
    assert out.endswith("A. About\r\nOK> ")
