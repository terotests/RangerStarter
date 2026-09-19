#!/usr/bin/env python3
"""Remove the frames one walk produces, and nothing else.

    python3 scripts/wizard-shots/clean.py <script.json> <framedir>

The set is regenerated whole so that a RENAMED step cannot leave behind a ghost
frame that nothing produces any more and the documentation still links. But a
blanket `rm docs/wizard/*.png` deletes pictures this harness does not take --
the SDL2 window shot lives in the same directory -- and then the documentation
links an image nobody notices is gone until it is pushed. So: only the names the
script itself carries.
"""
import json
import os
import sys

script, framedir = sys.argv[1], sys.argv[2]
names = [step["name"] for step in json.load(open(script))] + ["00-open"]
for name in names:
    for ext in (".txt", ".png"):
        path = os.path.join(framedir, name + ext)
        if os.path.exists(path):
            os.remove(path)
