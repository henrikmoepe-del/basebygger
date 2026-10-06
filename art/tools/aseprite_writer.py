"""Writes indexed-colour .aseprite files (one frame, several layers) with no
dependencies, so concept art made in code opens in Aseprite with its layers
and palette intact. Format: https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md
Index 0 of the palette is the transparent colour.
"""
import struct
import zlib


def _string(text):
    data = text.encode("utf-8")
    return struct.pack("<H", len(data)) + data


def _chunk(kind, data):
    return struct.pack("<IH", len(data) + 6, kind) + data


def write(path, width, height, palette, layers):
    """palette: list of (r, g, b, a). layers: list of (name, bytes) where the
    bytes are width * height palette indices, bottom layer first."""
    chunks = []
    pal = struct.pack("<III8x", len(palette), 0, len(palette) - 1)
    for r, g, b, a in palette:
        pal += struct.pack("<HBBBB", 0, r, g, b, a)
    chunks.append(_chunk(0x2019, pal))
    for name, _ in layers:
        chunks.append(_chunk(0x2004, struct.pack("<HHHHHHB3x", 3, 0, 0, 0, 0, 0, 255) + _string(name)))
    for index, (_, pixels) in enumerate(layers):
        cel = struct.pack("<HhhBHh5x", index, 0, 0, 255, 2, 0)
        cel += struct.pack("<HH", width, height) + zlib.compress(bytes(pixels), 9)
        chunks.append(_chunk(0x2005, cel))
    body = b"".join(chunks)
    frame = struct.pack("<IHHH2xI", 16 + len(body), 0xF1FA, min(len(chunks), 0xFFFF), 100, len(chunks)) + body
    header = struct.pack(
        "<IHHHHHIHII B3x H BB hhHH 84x".replace(" ", ""),
        128 + len(frame), 0xA5E0, 1, width, height, 8, 1, 100, 0, 0,
        0, len(palette), 1, 1, 0, 0, 16, 16,
    )
    assert len(header) == 128
    with open(path, "wb") as f:
        f.write(header + frame)
