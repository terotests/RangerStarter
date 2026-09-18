---
name: example
description: Find a worked Ranger example by what it does — a parser, a PDF, a chart, a diagram, an app, a Figma file, a mobile screen — and set it up to run. Use when asked what Ranger can do, for an example of something, or before designing from scratch something the gallery has probably already solved.
---

# Finding an example

The index is `examples/INDEX.json`: every entry says what it DOES, what it
needs on disk, where it lives and how to run it.

```bash
cat examples/INDEX.json
```

Asked for a topic ("$ARGUMENTS" when this was invoked as a command), match it
against `does`, `teaches` and `title` — not only `id`. Then:

**`needs: "starter"`** — it is in this repository and runs now:

```bash
npm run example:calc
scripts/rgr run examples/calc/Calc.rgr -l=python
```

**`needs: "gallery"`** — it is a package in the Ranger repository, and the
entry's `add` field is the command that fetches it. `evg` (and `image`) are
MIT under `lib/` and need no notice. Everything under `gallery/` is AGPL: do
not run that command without saying what it means first, because building on
gallery code puts the resulting program under the AGPL unless the user holds
a commercial license. Name the license, then offer it:

```bash
scripts/add-gallery.sh evg      # MIT — just adds it
scripts/add-gallery.sh rave     # AGPL — say so first
```

**`needs: "repo"`** — it is a demo that only makes sense inside a full Ranger
checkout. Say so plainly and offer the clone rather than pretending:

```bash
git clone --depth 1 https://github.com/terotests/Ranger
cd Ranger && npm install
```

Some entries name a `skill` — `evg-edit` for documents, `rave` for
applications. Those arrive with `scripts/add-gallery.sh --skills`. Read the
skill before changing anything in that example; both exist to stop an
edit-and-hope loop that is expensive here.

## What to say back

Name the example, what it demonstrates, the command, and what will appear —
a file, a window, a printed line. If nothing in the index matches, say that
too, and pick the nearest thing that really exists rather than inventing a
command: an invented command costs more than an honest "no example for that
yet".
