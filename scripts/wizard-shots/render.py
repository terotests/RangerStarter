#!/usr/bin/env python3
"""Render each captured wizard frame as a terminal-looking PNG.

    python3 scripts/wizard-shots/render.py <framedir> <outdir>

Needs Pillow and the Chromium that Playwright installs. The frames are plain text
captured from a real terminal; this only puts a window around them and colours
four kinds of line.
"""
import html, os, subprocess, sys, glob, tempfile, shutil
from PIL import Image

FRAMES = sys.argv[1]
OUT = sys.argv[2]
CHROME = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"

TEMPLATE = """<!doctype html>
<html><head><meta charset="utf-8">
<style>
  :root {{ color-scheme: dark; }}
  html, body {{ margin: 0; padding: 0; background: #14161a; }}
  .win {{
    width: 760px; margin: 0; padding: 0;
    background: #1b1e24; border-radius: 10px; overflow: hidden;
    box-shadow: 0 10px 30px rgba(0,0,0,.45);
    font-family: "DejaVu Sans Mono", "Liberation Mono", monospace;
  }}
  .bar {{
    height: 30px; display: flex; align-items: center; gap: 7px; padding: 0 12px;
    background: #23272f; border-bottom: 1px solid #0f1115;
  }}
  .dot {{ width: 11px; height: 11px; border-radius: 50%; }}
  .r {{ background: #ff5f57; }} .y {{ background: #febc2e; }} .g {{ background: #28c840; }}
  .title {{
    margin-left: 10px; color: #8b93a1; font-size: 11.5px; letter-spacing: .3px;
  }}
  pre {{
    margin: 0; padding: 14px 16px 16px;
    color: #d6dae2; font-size: 13px; line-height: 1.45;
    white-space: pre; tab-size: 4;
  }}
  /* the cursor row, the refusal line and the step counter carry the only colour */
  .cursor {{ color: #7ee787; }}
  .bad {{ color: #ff7b72; }}
  .dim {{ color: #6e7681; }}
  .rule {{ color: #2d323b; }}
  .step {{ color: #79c0ff; }}
</style></head>
<body><div class="win">
  <div class="bar"><span class="dot r"></span><span class="dot y"></span><span class="dot g"></span>
  <span class="title">{title}</span></div>
  <pre>{body}</pre>
</div></body></html>
"""

def markup(line):
    e = html.escape(line)
    if "─────" in line:
        return f'<span class="rule">{e}</span>'
    if line.strip().startswith("×"):
        return f'<span class="bad">{e}</span>'
    if "Ranger project setup" in line:
        # colour just the "n of m" on the right
        idx = e.rstrip().rfind(" ")
        head, tail = e[: e.rfind(tail_sep := " ")], ""
        parts = e.rsplit("  ", 1)
        if len(parts) == 2 and parts[1].strip():
            return parts[0] + "  " + f'<span class="step">{parts[1]}</span>'
        return e
    if line.startswith("  ▸") or line.startswith("▸"):
        return f'<span class="cursor">{e}</span>'
    if line.lstrip().startswith("–"):
        return f'<span class="dim">{e}</span>'
    if line.strip().startswith(("↑↓", "type a name", "⏎")):
        return f'<span class="dim">{e}</span>'
    if "for example:" in line:
        return f'<span class="dim">{e}</span>'
    return e

os.makedirs(OUT, exist_ok=True)
TMP = tempfile.mkdtemp(prefix="wizard-shots-")
made = []
for path in sorted(glob.glob(os.path.join(FRAMES, "*.txt"))):
    name = os.path.splitext(os.path.basename(path))[0]
    lines = open(path).read().rstrip("\n").split("\n")
    if not any(l.strip() for l in lines):
        continue
    body = "\n".join(markup(l) for l in lines)
    # The scratch HTML does not belong beside the pictures it produced.
    page = os.path.join(TMP, name + ".html")
    open(page, "w").write(TEMPLATE.format(title="ranger-starter configure", body=body))
    png = os.path.join(OUT, name + ".png")
    # Render into a window taller than anything can need, then crop to the window
    # chrome. Computing the height from the line count needs the font metrics to
    # be guessed, and a guess that is short CLIPS the frame -- which is exactly
    # the sort of thing a screenshot is supposed to rule out.
    subprocess.run(
        [CHROME, "--headless=new", "--no-sandbox", "--disable-gpu",
         "--hide-scrollbars", "--force-device-scale-factor=2",
         "--window-size=760,1400",
         f"--screenshot={png}", "file://" + os.path.abspath(page)],
        check=True, capture_output=True,
    )
    img = Image.open(png).convert("RGB")
    page_bg = img.getpixel((4, img.height - 4))          # outside the window
    # Walk up from the bottom to the last row that is not entirely page background.
    w, h = img.size
    bottom = h
    for y in range(h - 1, -1, -1):
        row = img.crop((0, y, w, y + 1)).getcolors(w + 1)
        if not (len(row) == 1 and row[0][1] == page_bg):
            bottom = y + 1
            break
    img.crop((0, 0, w, min(h, bottom + 24))).save(png)
    made.append((name, png, bottom))
shutil.rmtree(TMP, ignore_errors=True)

for name, png, h in made:
    im = Image.open(png)
    print(f"{name:22} {im.width}x{im.height}  {os.path.getsize(png)//1024:4} KB")
