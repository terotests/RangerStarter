See [AGENTS.md](AGENTS.md).

Skills in `.claude/skills/` load with this project:

- **ranger-start** — the layout, the build loop, adding files and dependencies.
- **ranger-lang** — read it before writing `.rgr`; the errors that point at the
  wrong line.
- **example** — worked examples by what they do (`examples/INDEX.json`).

`scripts/add-gallery.sh --skills` adds **evg-edit** and **rave** when the
gallery is brought in.
