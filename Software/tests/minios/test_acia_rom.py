def test_variant_boots_with_the_acia_enabled(loader_menu):
    assert "ACIA-enabled" in loader_menu.boot_output
    assert b"ACIA-enabled" in loader_menu.peer.wait_for(b"ACIA-enabled")
