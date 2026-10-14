"""Wire formats the loader tests send down the serial line."""
SOH, EOT, ACK, NAK, ESC = 0x01, 0x04, 0x06, 0x15, 0x1B


def crc16(data: bytes, crc: int = 0) -> int:
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def xmodem_block(number, data, *, bad_crc=False, bad_complement=False) -> bytes:
    assert len(data) == 128
    crc = crc16(data) ^ (0x0001 if bad_crc else 0)
    comp = (255 - number) ^ (0x55 if bad_complement else 0)
    return bytes([SOH, number & 0xFF, comp & 0xFF]) + data + crc.to_bytes(2, "big")


def ihex_record(addr, data, rtype=0, *, bad_checksum=False) -> str:
    body = bytes([len(data), addr >> 8, addr & 0xFF, rtype]) + bytes(data)
    checksum = (-sum(body)) & 0xFF
    if bad_checksum:
        checksum ^= 0x55
    return ":" + (body + bytes([checksum])).hex().upper()


IHEX_EOF = ihex_record(0, b"", rtype=1)
