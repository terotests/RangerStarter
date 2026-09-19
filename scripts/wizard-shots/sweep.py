#!/usr/bin/env python3
"""Remove frames this harness used to produce and no longer does.

    python3 scripts/wizard-shots/sweep.py <framedir> <script.json> [script.json …]

The frame directory holds pictures from more than one source -- the wizard walks
here, the SDL2 window shot from `scripts/desktop-shot.sh` -- so neither
`rm *.png` nor "delete what this run names" is right. The first deletes other
people's pictures; the second leaves a GHOST behind whenever a step is RENAMED,
because the old name is in nobody's list any more and the documentation goes on
linking it.

So the harness records what it owns, in `.owned.json`, and sweeps away anything
it owned last time and did not produce this time. A file it never produced is
not its business.

With no manifest yet, it writes one and deletes nothing: it cannot tell a ghost
of its own from somebody else's picture.
"""
import json
import os
import sys

framedir, scripts = sys.argv[1], sys.argv[2:]
manifest = os.path.join(framedir, ".owned.json")

owned = []
for script in scripts:
    for step in json.load(open(script)):
        owned.append(step["name"])
owned.append("00-open")
current = set()
for name in owned:
    for ext in (".txt", ".png"):
        current.add(name + ext)

previous = set()
if os.path.exists(manifest):
    previous = set(json.load(open(manifest)))

removed = []
for name in sorted(previous - current):
    path = os.path.join(framedir, name)
    if os.path.exists(path):
        os.remove(path)
        removed.append(name)

json.dump(sorted(current), open(manifest, "w"), indent=2)
if removed:
    print("swept: " + ", ".join(removed))
