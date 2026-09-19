#!/usr/bin/env bash
# Regenerate the wizard screenshots. See scripts/wizard-shots/README.md.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The frame set is regenerated whole, so a renamed step cannot leave a ghost
# frame behind that nothing produces any more and the documentation still links.
# A failed run leaves the directory empty; `git checkout docs/wizard` restores it.
rm -f "$here"/docs/wizard/*.txt "$here"/docs/wizard/*.png

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
