#!/usr/bin/env bash
#
# desktop-shot.sh — a picture of the window the desktop surface generates.
#
# It generates a project, builds it and grabs a frame, all with
# SDL_VIDEODRIVER=dummy, so this runs on a machine with no display: the pixels
# come from SDL_RenderReadPixels, which reads back what the renderer drew rather
# than what a screen showed. That is the same reason the generated host has a
# `--shot` flag at all — "it exited 0" does not prove anything was drawn.
#
# Needs SDL2, CMake, a C++17 compiler and Pillow.
#
#   scripts/desktop-shot.sh
#
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if ! command -v cmake >/dev/null 2>&1; then
    echo "error: cmake is not installed" >&2
    exit 1
fi

cd "$work"
node "$here/bin/ranger-starter.js" init --name northwind --surfaces desktop --apply >/dev/null
# The compiler rather than a fresh download: this is the repository's own, and a
# generated project only needs it to be reachable from node_modules.
ln -s "$here/node_modules" node_modules
npm run desktop:build >/dev/null

# One frame is all a screenshot is. The flag has to come after the count.
SDL_VIDEODRIVER=dummy ./build/desktop-cmake/northwind 1 --shot "$work/window.bmp"

python3 "$here/scripts/wizard-shots/window.py" \
    "$work/window.bmp" "$here/docs/wizard/40-desktop-window.png" \
    "northwind — SDL2"
