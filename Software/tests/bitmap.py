"""Reader for the 24-bit BMPs written by pico-code/sim/sim_dump.c."""

# Same order as palette[] in sim_dump.c.
PALETTE = [
    0x000000, 0xC00000, 0x00C000, 0xC0C000, 0x0000C0, 0xC000C0, 0x00C0C0, 0xC0C0C0,
    0x808080, 0xFF0000, 0x00FF00, 0xFFFF00, 0x0080FF, 0xFF00FF, 0x00FFFF, 0xFFFFFF,
]


class Bitmap:
    def __init__(self, data: bytes):
        assert data[:2] == b"BM", "not a BMP"
        self._data = data
        self._offset = int.from_bytes(data[10:14], "little")
        self.width = int.from_bytes(data[18:22], "little")
        self.height = int.from_bytes(data[22:26], "little")
        assert int.from_bytes(data[28:30], "little") == 24, "expected 24 bpp"
        self._stride = (self.width * 3 + 3) & ~3

    def pixel(self, x: int, y: int) -> int:
        i = self._offset + (self.height - 1 - y) * self._stride + x * 3
        b, g, r = self._data[i:i + 3]
        return r << 16 | g << 8 | b

    def count(self, rgb: int) -> int:
        return sum(self.pixel(x, y) == rgb
                   for y in range(self.height) for x in range(self.width))
