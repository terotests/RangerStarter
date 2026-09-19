---
name: ranger-build
description: Build, run and test this Ranger project — the compile loop that fails loudly, which target each script writes, and what is generated and must not be edited. Use when asked to run, build, test or compile anything here, when a build seems to have had no effect, or before editing a file under build/ or one listed in .ranger/generated.json.
---

# Building this project

The compiler is the npm package `ranger-compiler` in `node_modules`. There is no
Ranger checkout and nothing is installed globally.

```bash
npm install
npm start      # compile the entry point and run it
npm test       # exits non-zero when an expectation fails
```

## Never call `rgrc` directly

Ranger compilers through 3.5.1 print `[FAIL]` and `Compilation FAILED` and then
**exit 0**. So this:

```bash
npx rgrc src/Main.rgr -o=Main.js && node build/Main.js     # ← DO NOT
```

is satisfied by that zero, the previous build is still on disk, and node runs
**that one**. The program prints what it printed before your edit: the change
looks applied, the test looks green, and neither is true.

`scripts/rgr.js` deletes the output first, reads the compiler's log as well as
its exit status, and treats a missing output file as a failure. Every npm script
in this project goes through it.

```bash
node scripts/rgr.js check src/Main.rgr            # does it compile? nothing else
node scripts/rgr.js run   src/Main.rgr            # compile to JS and run
node scripts/rgr.js run   src/Main.rgr -l=python  # the same source, as Python
node scripts/rgr.js build src/Main.rgr -l=go      # compile only
```

`npm run` with no arguments lists every script this project's configuration
produced.

## What is generated

`.ranger/generated.json` lists every file `ranger-starter` wrote, with a
fingerprint. **Do not edit a file it names.** Change `ranger.project.json` and
re-apply:

```bash
npm run plan            # what would change; writes nothing
npm run setup -- --apply
```

If you edit a generated file anyway, the tool notices and stops overwriting it —
which means it also stops updating it, and you own that file from then on. It
says so rather than clobbering your work.

Three kinds of file are treated differently:

| | |
| --- | --- |
| generated | overwritten while it still matches its fingerprint |
| `package.json`, `ranger.json` | parsed and merged; your own keys are kept where they are |
| `README.md`, `AGENTS.md`, `CLAUDE.md` | only the regions between `<!-- ranger:start … -->` markers are written; the rest is yours |

Everything under `build/` is compiler output. It is gitignored and is never worth
editing.

## Targets disagree

If this project is configured for more than one target, run the test on more
than one before believing a portability claim:

```bash
node scripts/rgr.js run src/MainTest.rgr
node scripts/rgr.js run src/MainTest.rgr -l=python
node scripts/rgr.js run src/MainTest.rgr -l=go
```

- `to_double` accepts `"10 "` on JavaScript and Python and refuses it on Go, so
  `(to_double (trim text))` is the portable form.
- Numbers print as `7` on JavaScript and Go and `7.0` on Python. Test the value,
  not the printed string.

Read `AGENTS.md` for the rest: the project's own rules, the per-surface notes,
and the license line.
