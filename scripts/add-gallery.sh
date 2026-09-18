#!/usr/bin/env bash
#
# add-gallery.sh — bring a Ranger gallery project into this one, on purpose.
#
# THE LICENSE MATTERS HERE, and it is why this is a separate command rather
# than a dependency that ships with the starter.
#
#   This starter, the compiler, the runtime and lib/   MIT
#     — including lib/evg (the layout engine) and lib/image (the codecs)
#   Anything under gallery/                            AGPL-3.0-or-later
#
# Rave, RangerFlow, Vela, the Office stack, DataGrid, the PDF writer: they are
# not sample code, they are the application stack, and building a product on
# them puts that product under the AGPL unless you hold a separate commercial
# license. Compiling your OWN program with Ranger does not — that is the whole
# point of the split. EVG itself is MIT: a program with a screen is still your
# program. `add-gallery.sh evg` adds it without the notice below, because
# there is nothing to warn about.
#
#   https://github.com/terotests/Ranger/blob/master/LICENSING.md
#
# So nothing here is fetched by default. You ask for it, by name, and the
# sources land in vendor/ranger/<name>, which .gitignore keeps out of this MIT
# tree.
#
#   scripts/add-gallery.sh                 list what can be added
#   scripts/add-gallery.sh evg             add lib/evg (MIT, no prompt)
#   scripts/add-gallery.sh rave            add gallery/rave (asks first)
#   scripts/add-gallery.sh rave --yes      add it without asking
#   scripts/add-gallery.sh --skills        install the evg-edit and rave skills
#
# SPDX-License-Identifier: MIT
set -u

REPO="https://github.com/terotests/Ranger.git"
REV="HEAD"

 # MIT packages under lib/ in the Ranger repository.
known_lib() {
  cat <<'LIST'
evg          a CSS layout and rendering engine with no browser in it: flex, grid, stylesheets, text, the display list
image        the JPEG and PNG codecs and the raster buffers EVG decodes and paints with
LIST
}

# AGPL packages under gallery/.
known() {
  cat <<'LIST'
rave         routed, responsive, accessible applications, checked without a browser
rangerflow   Mermaid / PlantUML / Graphviz / D2 parsed and laid out as real geometry
vela         Vega and Vega-Lite charts
markdown     a Markdown document pipeline: PDF, decks, diagrams
pdf_writer   PDF output with embedded fonts and vector graphics
datagrid     a spreadsheet: grid, formulas, XLSX
figma        reading and writing .fig files
codegraph    analysing a JavaScript or C++ project and drawing it
ts_parser    a TypeScript parser written in Ranger
js_parser    a JavaScript parser written in Ranger
ui           the UI component layer
LIST
}

usage() {
  echo "usage: scripts/add-gallery.sh <name> [--yes]    add lib/<name> or gallery/<name> as a dependency"
  echo "       scripts/add-gallery.sh --skills          install the evg-edit and rave agent skills"
  echo
  echo "Libraries (MIT, under lib/ — added without a prompt):"
  echo
  known_lib | sed 's/^/  /'
  echo
  echo "Gallery projects (AGPL-3.0-or-later):"
  echo
  known | sed 's/^/  /'
  echo
  echo "Any other directory of https://github.com/terotests/Ranger/tree/master/gallery"
  echo "works too — the name is the directory name."
}

install_skills() {
  # The evg-edit and rave skills describe the gallery, so they arrive with it
  # rather than with the starter. The skill text itself is MIT (it lives
  # outside gallery/ in the Ranger repository); what it describes is not.
  tmp=$(mktemp -d)
  echo "fetching the skills from $REPO …"
  cat > "$tmp/ranger.json" <<JSON
{
  "name": "skills-fetch",
  "version": "0.0.0",
  "entry": "none.rgr",
  "dependencies": {
    "skills": { "git": "$REPO", "rev": "$REV", "subdir": "plugins/ranger/skills" }
  }
}
JSON
  here=$(pwd)
  fetchlog=$( cd "$tmp" && "$here/node_modules/.bin/rgrc" install -vendor 2>&1 )
  printf '%s\n' "$fetchlog"
  if printf '%s' "$fetchlog" | grep -q "\[FAIL\]"; then
    echo "add-gallery: the fetch failed" >&2; rm -rf "$tmp"; exit 1
  fi
  for s in evg-edit rave; do
    if [ -f "$tmp/vendor/ranger/skills/$s/SKILL.md" ]; then
      mkdir -p ".claude/skills/$s"
      cp "$tmp/vendor/ranger/skills/$s/SKILL.md" ".claude/skills/$s/SKILL.md"
      echo "  .claude/skills/$s/SKILL.md"
    else
      echo "add-gallery: $s was not in the fetched tree" >&2
    fi
  done
  rm -rf "$tmp"
  echo
  echo "Installed. These two describe AGPL gallery code; the starter itself stays MIT."
}

if [ ! -x node_modules/.bin/rgrc ]; then
  echo "add-gallery: node_modules/.bin/rgrc is missing — run 'npm install' first" >&2
  exit 1
fi

name=${1-}
case "$name" in
  ""|-h|--help|--list) usage; exit 0 ;;
  --skills) install_skills; exit 0 ;;
esac

yes=0
if [ "${2-}" = "--yes" ] || [ "${2-}" = "-y" ]; then yes=1; fi

# Where the package lives in the Ranger repository, and so which license.
case "$name" in
  evg|image|zip) subdir="lib/$name"; license="MIT" ;;
  *)             subdir="gallery/$name"; license="AGPL-3.0-or-later" ;;
esac

if [ "$license" = "MIT" ]; then
  echo
  echo "  $subdir is MIT, like this starter and the compiler. Adding it."
  yes=1
else
cat <<NOTE

  gallery/$name is licensed AGPL-3.0-or-later.

  Using it in a program you distribute puts that program under the AGPL —
  including over a network, which is what the "Affero" in the name is for —
  unless you hold a separate commercial license from the copyright holder.

  The compiler, the runtime and this starter are MIT and stay MIT. Compiling
  your own program with Ranger imposes nothing. Building ON the gallery does.

  https://github.com/terotests/Ranger/blob/master/LICENSING.md

NOTE

fi

if [ $yes -eq 0 ]; then
  printf "  Add gallery/%s to this project? [y/N] " "$name"
  read -r answer </dev/tty || answer=""
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "  nothing was added."; exit 0 ;;
  esac
fi

node - "$name" "$REPO" "$REV" "$subdir" <<'NODE'
const fs = require("node:fs");
const [name, repo, rev, subdir] = process.argv.slice(2);
const file = "ranger.json";
const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
pkg.dependencies = pkg.dependencies || {};
pkg.dependencies[name] = { git: repo, rev, subdir };
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
console.log(`ranger.json: dependency "${name}" -> ${subdir}`);
NODE

echo
./scripts/deps.sh -vendor || exit 1

# Pin what was actually fetched. `rev: HEAD` is not a dependency, it is a
# moving target: a clean checkout a week later resolves it to something else,
# and `deps:frozen` cannot match it against the lock at all. ranger.lock has
# the commit the fetch landed on, so write that back.
node - "$name" <<'NODE'
const fs = require("node:fs");
const name = process.argv[2];
let lock;
try {
  lock = JSON.parse(fs.readFileSync("ranger.lock", "utf8"));
} catch (e) {
  console.error("add-gallery: no ranger.lock to pin from");
  process.exit(0);
}
const locked = lock.packages && lock.packages[name];
if (!locked || !locked.rev) process.exit(0);
const pkg = JSON.parse(fs.readFileSync("ranger.json", "utf8"));
if (pkg.dependencies && pkg.dependencies[name]) {
  pkg.dependencies[name].rev = locked.rev;
  fs.writeFileSync("ranger.json", JSON.stringify(pkg, null, 2) + "\n");
  console.log(`ranger.json: "${name}" pinned to ${locked.rev}`);
}
NODE

if [ "$license" = "MIT" ]; then
  vendor_note="vendor/ is gitignored: fetched sources are rebuilt from ranger.lock, not committed."
else
  vendor_note="vendor/ is gitignored: it is someone else's AGPL source, not yours."
fi

cat <<DONE

  vendor/ranger/$name is on disk and ranger.lock records the commit.
  $vendor_note

  Import it from a .rgr file with the pkg: form —

      Import "pkg:$name/<SomeFile.rgr>"

  Commit ranger.json and ranger.lock. 'npm run deps' on a clean checkout
  fetches the same commit again; 'npm run deps:frozen' is the CI form and
  fails rather than fetching something the lock does not cover.

  The evg-edit and rave skills are worth having before editing an EVG
  document or a Rave app:  scripts/add-gallery.sh --skills
DONE
