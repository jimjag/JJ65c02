import struct

from bitmap import Bitmap


def _bmp(width, height, rows):
    pad = (4 - width * 3 % 4) % 4
    body = b""
    for row in reversed(rows):
        for rgb in row:
            body += bytes((rgb & 0xFF, rgb >> 8 & 0xFF, rgb >> 16 & 0xFF))
        body += b"\0" * pad
    head = b"BM" + struct.pack("<IHHI", 54 + len(body), 0, 0, 54)
    info = struct.pack("<IiiHHIIiiII", 40, width, height, 1, 24, 0,
                       len(body), 2835, 2835, 0, 0)
    return head + info + body


def test_pixel_addresses_top_left_origin_with_row_padding():
    b = Bitmap(_bmp(3, 2, [[0x110000, 0x002200, 0x000033],
                           [0xAABBCC, 0x000000, 0xFFFFFF]]))
    assert (b.width, b.height) == (3, 2)
    assert b.pixel(0, 0) == 0x110000
    assert b.pixel(2, 0) == 0x000033
    assert b.pixel(0, 1) == 0xAABBCC
    assert b.pixel(2, 1) == 0xFFFFFF


def test_count():
    b = Bitmap(_bmp(2, 2, [[1, 2], [1, 1]]))
    assert b.count(1) == 3 and b.count(2) == 1 and b.count(9) == 0


def test_bbox_is_inclusive_and_none_when_absent():
    b = Bitmap(_bmp(4, 3, [[0, 0, 0, 0],
                           [0, 7, 0, 7],
                           [0, 0, 7, 0]]))
    assert b.bbox(7) == (1, 1, 3, 2)
    assert b.bbox(9) is None
