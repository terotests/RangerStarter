#!/usr/bin/env python3
"""Put a window frame around a frame grabbed from the SDL2 host.

    python3 scripts/wizard-shots/window.py <in.bmp> <out.png> <title>

The BMP is what `SDL_RenderReadPixels` read back out of the renderer, so it is
the pixels a display would have shown -- grabbed with SDL_VIDEODRIVER=dummy, on
a machine with no display at all. This only draws a title bar around it so the
documentation shows a window rather than a rectangle on a page.

Needs Pillow. Nothing else: no Chromium, no X server.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

BAR_H = 30
RADIUS = 10
BAR = (0x23, 0x27, 0x2f)
EDGE = (0x0f, 0x11, 0x15)
PAGE = (0x14, 0x16, 0x1a)
DOTS = [(0xff, 0x5f, 0x57), (0xfe, 0xbc, 0x2e), (0x28, 0xc8, 0x40)]
TEXT = (0x9a, 0xa3, 0xb2)


def font():
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ):
        try:
            return ImageFont.truetype(path, 13)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    src, dst, title = sys.argv[1], sys.argv[2], sys.argv[3]
    shot = Image.open(src).convert("RGB")
    w, h = shot.size

    out = Image.new("RGB", (w, h + BAR_H), PAGE)
    draw = ImageDraw.Draw(out)
    draw.rectangle([0, 0, w - 1, BAR_H - 1], fill=BAR)
    draw.line([0, BAR_H - 1, w - 1, BAR_H - 1], fill=EDGE)
    for i, colour in enumerate(DOTS):
        cx = 14 + i * 18
        cy = BAR_H // 2
        draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=colour)
    draw.text((78, BAR_H // 2), title, fill=TEXT, font=font(), anchor="lm")
    out.paste(shot, (0, BAR_H))

    # Round the outer corners by making them the page colour, the same trick the
    # terminal frames use.
    mask = Image.new("L", out.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, out.size[0] - 1, out.size[1] - 1],
                                           radius=RADIUS, fill=255)
    framed = Image.new("RGB", out.size, PAGE)
    framed.paste(out, (0, 0), mask)
    framed.save(dst)
    print("%-22s %dx%d  %4d KB" % (dst.rsplit("/", 1)[-1][:-4], framed.size[0],
                                   framed.size[1],
                                   __import__("os").path.getsize(dst) // 1024))


main()
