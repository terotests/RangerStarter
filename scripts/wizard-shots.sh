#!/usr/bin/env bash
# Regenerate the wizard screenshots. See scripts/wizard-shots/README.md.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
python3 "$here/scripts/wizard-shots/drive.py" \
    "$here/scripts/wizard-shots/script.json" "$work" "$here/docs/wizard" \
    "$here/bin/ranger-starter.js"
python3 "$here/scripts/wizard-shots/render.py" "$here/docs/wizard" "$here/docs/wizard"
