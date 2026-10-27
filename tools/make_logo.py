r"""SurvivorPlates logo, built from the game's 32x32 boss skull.

Usage: python tools/make_logo.py

Source: tools/skull_32.png, decoded from Interface\TargetingFrame\UI-TargetingFrame-Skull.blp
in the game's Data\patch.MPQ (the same skull the pile bars show on bosses).

The skull is scaled up with Scale2x three times (32 -> 256, keeps the pixel edges but
smooths diagonals), then Lanczos to size, on a dark round badge with a gold ring, above
three stacked pile bars. Writes:
  tools/logo.png  512x512, for the README
  icon.tga        64x64, the minimap button
  icon.ico        64/48/32/16 RGBA, read by the DrangedAddons manager (RGBA so its WPF
                  decoder accepts it)
"""
import math
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import os

TOOLS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TOOLS)
SRC = os.path.join(TOOLS, "skull_32.png")
SIZE = 512


def scale2x(im):
    """EPX/Scale2x: doubles size, keeps hard edges but smooths diagonals."""
    w, h = im.size
    src = im.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    dst = out.load()

    def px(x, y):
        x = min(max(x, 0), w - 1)
        y = min(max(y, 0), h - 1)
        return src[x, y]

    for y in range(h):
        for x in range(w):
            p = px(x, y)
            a, b, c, d = px(x, y - 1), px(x + 1, y), px(x - 1, y), px(x, y + 1)
            e0 = a if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != b and c != a) else p
            e3 = d if (b == d and b != a and d != c) else p
            dst[2 * x, 2 * y] = e0
            dst[2 * x + 1, 2 * y] = e1
            dst[2 * x, 2 * y + 1] = e2
            dst[2 * x + 1, 2 * y + 1] = e3
    return out


def smooth_skull(px_size):
    im = Image.open(SRC).convert("RGBA")
    for _ in range(3):  # 32 -> 256
        im = scale2x(im)
    im = im.resize((px_size, px_size), Image.LANCZOS)
    return im


def crisp_skull(px_size):
    return Image.open(SRC).convert("RGBA").resize((px_size, px_size), Image.NEAREST)


def badge():
    """Dark round badge with a gold ring, like a WoW portrait frame."""
    im = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    c = SIZE / 2
    r_outer = SIZE / 2 - 8
    # Radial dark fill.
    fill = Image.new("RGBA", (SIZE, SIZE))
    fp = fill.load()
    for y in range(SIZE):
        for x in range(SIZE):
            d = math.hypot(x - c, y - c) / r_outer
            t = min(1, d)
            col = (int(46 - 36 * t), int(30 - 24 * t), int(26 - 21 * t), 255)
            fp[x, y] = col
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse((c - r_outer, c - r_outer, c + r_outer, c + r_outer), fill=255)
    im.paste(fill, (0, 0), mask)
    # Gold ring: dark rim, bright band, inner shadow line.
    d = ImageDraw.Draw(im)
    for i, (w, col) in enumerate([(22, (60, 40, 10, 255)), (16, (196, 150, 52, 255)), (8, (250, 214, 110, 255))]):
        rr = r_outer - 3
        d.ellipse((c - rr, c - rr, c + rr, c + rr), outline=col, width=w - i * 2)
    rr = r_outer - 22
    d.ellipse((c - rr, c - rr, c + rr, c + rr), outline=(20, 12, 6, 255), width=3)
    return im


def glow(skull, color=(200, 30, 20), radius=18):
    a = skull.split()[3].filter(ImageFilter.GaussianBlur(radius))
    g = Image.new("RGBA", skull.size, color + (0,))
    g.putalpha(a.point(lambda v: int(v * 0.55)))
    return g


def compose(skull, y_off=0, bars=False):
    im = badge()
    s = skull.size[0]
    pos = ((SIZE - s) // 2, (SIZE - s) // 2 + y_off)
    im.alpha_composite(glow(skull), pos)
    im.alpha_composite(skull, pos)
    if bars:
        # Three stacked pile bars under the skull, like the addon's panel.
        d = ImageDraw.Draw(im)
        bw, bh, gap = 230, 22, 8
        x0 = (SIZE - bw) // 2
        y0 = 352
        fills = [0.9, 0.62, 0.35]
        for i, f in enumerate(fills):
            y = y0 + i * (bh + gap)
            d.rectangle((x0, y, x0 + bw, y + bh), fill=(0, 0, 0, 230))
            d.rectangle((x0 + 2, y + 2, x0 + 2 + int((bw - 4) * f), y + bh - 2), fill=(178, 52, 26, 255))
            # pale gold damage chunk after the fill
            cx = x0 + 2 + int((bw - 4) * f)
            d.rectangle((cx, y + 2, min(x0 + bw - 2, cx + 22), y + bh - 2), fill=(255, 228, 140, 255))
        # mask the bars to the badge circle
        mask = Image.new("L", (SIZE, SIZE), 0)
        r = SIZE / 2 - 30
        ImageDraw.Draw(mask).ellipse((SIZE / 2 - r, SIZE / 2 - r, SIZE / 2 + r, SIZE / 2 + r), fill=255)
        base = badge()
        base.alpha_composite(glow(skull), pos)
        base.alpha_composite(skull, pos)
        clipped = Image.composite(im, base, mask)
        im = clipped
        # redraw the ring on top
        ring = badge()
        ring_mask = Image.new("L", (SIZE, SIZE), 255)
        ImageDraw.Draw(ring_mask).ellipse((SIZE / 2 - r, SIZE / 2 - r, SIZE / 2 + r, SIZE / 2 + r), fill=0)
        im = Image.composite(ring, im, ring_mask)
    return im


logo = compose(smooth_skull(260), y_off=-62, bars=True)
logo.save(os.path.join(TOOLS, "logo.png"))
small = logo.resize((64, 64), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1, percent=60, threshold=2))
small.save(os.path.join(ROOT, "icon.tga"))
logo.convert("RGBA").save(os.path.join(ROOT, "icon.ico"), sizes=[(64, 64), (48, 48), (32, 32), (16, 16)])
print("wrote tools/logo.png, icon.tga and icon.ico")
