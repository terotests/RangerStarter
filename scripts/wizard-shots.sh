#!/usr/bin/env bash
# Regenerate the wizard screenshots. See scripts/wizard-shots/README.md.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Two walks, each in its own empty directory: a command line project, and the
# two mobile surfaces -- which are the only ones with a device question, and the
# only place the shared-module answer is visible.
for script in script.json script-mobile.json; do
    dir=$work/$script
    mkdir -p "$dir"
    python3 "$here/scripts/wizard-shots/drive.py" \
        "$here/scripts/wizard-shots/$script" "$dir" "$here/docs/wizard" \
        "$here/bin/ranger-starter.js"
done
python3 "$here/scripts/wizard-shots/render.py" "$here/docs/wizard" "$here/docs/wizard"

# A frame this harness used to produce and no longer does -- a step that was
# renamed -- is swept away here, against a manifest of what it owns. Pictures it
# never took are left alone: the SDL2 window shot lives in this directory too.
python3 "$here/scripts/wizard-shots/sweep.py" "$here/docs/wizard" \
    "$here/scripts/wizard-shots/script.json" \
    "$here/scripts/wizard-shots/script-mobile.json"
