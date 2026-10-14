def test_variant_boots_with_the_acia_enabled(loader_menu):
    assert "ACIA-enabled" in loader_menu.boot_output
    assert b"ACIA-enabled" in loader_menu.peer.wait_for(b"ACIA-enabled")


def _crc16(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def test_a_whole_xmodem_block_in_one_write_is_acked(loader_menu):
    data = bytes(range(128))
    crc = _crc16(data)
    loader_menu.press(b"1", b"start: ")
    loader_menu.emu.send(b"L")
    loader_menu.peer.wait_for(b"C", 20)
    loader_menu.peer.send(bytes([1, 1, 254]) + data + bytes([crc >> 8, crc & 255]))
    assert loader_menu.peer.wait_for(b"\x06", 60)[-1:] == b"\x06"
    loader_menu.peer.send(b"\x1b")
    loader_menu.emu.wait_for(b"OK> ", 20)
