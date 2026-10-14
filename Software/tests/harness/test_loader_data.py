from loader_data import (ACK, EOT, IHEX_EOF, SOH, crc16, ihex_record,
                         xmodem_block)


def test_crc16_check_value():
    assert crc16(b"123456789") == 0x31C3


def test_xmodem_block_layout():
    data = bytes(range(128))
    blk = xmodem_block(1, data)
    assert blk[:3] == bytes([SOH, 1, 0xFE]) and blk[3:131] == data
    assert blk[131:] == crc16(data).to_bytes(2, "big") and len(blk) == 133


def test_xmodem_block_faults_differ_from_the_good_block():
    data = bytes(128)
    good = xmodem_block(2, data)
    assert xmodem_block(2, data, bad_crc=True) != good
    assert xmodem_block(2, data, bad_complement=True)[2] != good[2]


def test_ihex_record_matches_the_published_example():
    assert ihex_record(0x0030, bytes([0x02, 0x33, 0x7A])) == ":0300300002337A1E"


def test_ihex_eof_record():
    assert IHEX_EOF == ihex_record(0, b"", rtype=1) == ":00000001FF"


def test_ihex_bad_checksum_differs():
    assert ihex_record(0x10, b"\x01", bad_checksum=True) != ihex_record(0x10, b"\x01")
