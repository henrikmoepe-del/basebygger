"""Turns the PixelLab pictures into what the art lab draws (art_lab/pixellab/ready).

    python3 art_lab/pixellab/prep.py

No PixelLab generations are used. It:
- removes the house from the backdrop by mirroring its left half (below the sky);
- cuts a wall piece and a single stone block out of the keep, so they match it;
- shrinks the peasant animations to half size (each 2 x 2 square of pixels
  becomes the colour most of it has) and lays each one out as a strip,
  also with the tunic in red, green and brown.
"""
import glob
import os
from collections import Counter

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "ready")


def load(name):
    return Image.open(os.path.join(HERE, name)).convert("RGBA")


def half(im):
    """Half size, keeping hard pixel edges: each 2 x 2 square takes its most common colour."""
    w, h = im.width // 2, im.height // 2
    out = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            cells = [px[2 * x + dx, 2 * y + dy] for dy in (0, 1) for dx in (0, 1)]
            solid = [c for c in cells if c[3] > 128]
            if len(solid) >= 2:
                out.putpixel((x, y), Counter(solid).most_common(1)[0][0])
    return out


def backdrop():
    """The right half becomes the left half mirrored; the mirrored sun is then
    painted over with the sky colour of its row."""
    im = load("backdrop.png")
    left = im.crop((0, 0, im.width // 2, im.height))
    im.paste(left.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (im.width // 2, 0))
    px = im.load()
    sun_x = im.width - 29          # the sun sits at x 29 on the left
    for y in range(12, 33):
        sky = px[sun_x - 11, y]
        for x in range(sun_x - 9, sun_x + 10):
            px[x, y] = sky
    im.save(os.path.join(OUT, "backdrop.png"))


def wall_and_block():
    keep = load("keep.png")
    # plain bricks beside the lower window, and the battlements along the top
    bricks = keep.crop((31, 66, 55, 106))
    merlons = keep.crop((26, 34, 98, 57))
    w = 240
    wall = Image.new("RGBA", (w, merlons.height + bricks.height))
    for x in range(0, w, merlons.width):
        wall.alpha_composite(merlons, (x, 0))
    for x in range(0, w, bricks.width):
        for y in range(merlons.height, wall.height, bricks.height):
            wall.alpha_composite(bricks, (x, y))
    wall.save(os.path.join(OUT, "wall.png"))
    keep.crop((31, 128, 45, 136)).save(os.path.join(OUT, "block.png"))


TUNICS = {"red": 0.0, "green": 0.3, "brown": 0.08}


def recolour(im, hue):
    """The blue tunic in another colour: blue pixels get a new hue, same light and dark."""
    import colorsys
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and b > r + 12 and b >= g:
                h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
                if hue == 0.08:
                    s *= 0.6
                nr, ng, nb = colorsys.hls_to_rgb(hue, l, s)
                px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return out


def strips():
    for action in ["walk", "carry", "hammer", "pull", "climb"]:
        files = sorted(glob.glob(os.path.join(HERE, action + "_*.png")), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
        frames = [half(Image.open(f).convert("RGBA")) for f in files]
        strip = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height))
        for i, f in enumerate(frames):
            strip.alpha_composite(f, (i * f.width, 0))
        strip.save(os.path.join(OUT, action + ".png"))
        for colour, hue in TUNICS.items():
            recolour(strip, hue).save(os.path.join(OUT, "%s_%s.png" % (action, colour)))
        print(action, len(frames), "frames")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    backdrop()
    wall_and_block()
    strips()
