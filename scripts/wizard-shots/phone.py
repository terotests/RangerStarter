#!/usr/bin/env python3
"""Put a simple phone frame around an emulator screenshot.

    python3 scripts/wizard-shots/phone.py <in.png> <out.png> <title>

Needs Pillow. The input is usually `adb exec-out screencap -p`.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

BEZEL = 14
BAR_H = 28
RADIUS = 22
BEZEL_COLOUR = (0x1a, 0x1d, 0x24)
BAR = (0x23, 0x27, 0x2f)
EDGE = (0x0f, 0x11, 0x15)
PAGE = (0x14, 0x16, 0x1a)
TEXT = (0x9a, 0xa3, 0xb2)


def font():
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
    ):
        try:
            return ImageFont.truetype(path, 12)
        except OSError:
            continue
    return ImageFont.load_default()


def main():
    src, dst, title = sys.argv[1], sys.argv[2], sys.argv[3]
    shot = Image.open(src).convert("RGB")
    w, h = shot.size
    framed_w = w + BEZEL * 2
    framed_h = h + BEZEL * 2 + BAR_H

    out = Image.new("RGB", (framed_w, framed_h), PAGE)
    draw = ImageDraw.Draw(out)
    draw.rounded_rectangle(
        [0, 0, framed_w - 1, framed_h - 1],
        radius=RADIUS,
        fill=BEZEL_COLOUR,
    )
    draw.rectangle([BEZEL, BEZEL, framed_w - BEZEL - 1, BEZEL + BAR_H - 1], fill=BAR)
    draw.line([BEZEL, BEZEL + BAR_H - 1, framed_w - BEZEL - 1, BEZEL + BAR_H - 1], fill=EDGE)
    draw.text((BEZEL + 12, BEZEL + BAR_H // 2), title, fill=TEXT, font=font(), anchor="lm")
    out.paste(shot, (BEZEL, BEZEL + BAR_H))

    mask = Image.new("L", out.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, out.size[0] - 1, out.size[1] - 1], radius=RADIUS, fill=255
    )
    final = Image.new("RGB", out.size, PAGE)
    final.paste(out, (0, 0), mask)
    final.save(dst)
    print(
        "%-22s %dx%d  %4d KB"
        % (dst.rsplit("/", 1)[-1][:-4], final.size[0], final.size[1], __import__("os").path.getsize(dst) // 1024)
    )


main()
