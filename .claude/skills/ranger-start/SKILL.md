---
name: ranger-start
description: Work in this Ranger starter project — the build and test loop, where the sources go, how to reach all fourteen targets, and how to add a gallery dependency. Use when asked to add a feature, write a `.rgr` file, run or test this project, compile it to another language, or bring in EVG, Rave or another gallery package.
---

# This project

A Ranger project that compiles and runs from a clean clone. The compiler is
the npm package `ranger-compiler` in `node_modules` — no Ranger checkout is
involved, and nothing is installed globally.

```
src/Main.rgr           the entry point ranger.json names
src/Greeter.rgr        a class it imports
src/MainTest.rgr       npm test — exits non-zero when an expectation fails
examples/              worked examples; examples/INDEX.json says what each does
scripts/rgr            compile and run, and FAIL when the compile fails
scripts/targets.sh     all fourteen targets, and run the ones this machine has
scripts/add-gallery.sh add EVG (MIT) or opt into an AGPL gallery package
ranger.json            Ranger's own package file: entry point and dependencies
build/                 everything the compiler writes — gitignored
```

## The loop

```bash
npm start                              # compile src/Main.rgr to JS and run it
npm test                               # the test, which exits 1 on a failure
scripts/rgr check src/Greeter.rgr      # does this file compile?
scripts/rgr run src/Main.rgr -l=python # the same source, as Python
npm run targets                        # compile to all fourteen
npm run targets:run                    # and run the three this machine has
```

## Never call `rgrc` directly

`rgrc` prints `[FAIL]` and `Compilation FAILED`, and up to 3.5.1 **exited
zero**. So:

```bash
npx rgrc src/Main.rgr -o=Main.js && node build/Main.js     # ← DO NOT
```

The `&&` is satisfied by that zero, the previous build is still on disk, and
node runs **that**. The program prints what it printed before the edit: the
change looks applied, the test looks green, and neither is true. A later
compiler exits non-zero there, but which one this project installed is
`package.json`'s business, not the caller's.

`scripts/rgr` deletes the output first, reads the log as well as the exit
status, and treats a missing output file as an error. Use it. Every `npm`
script here goes through it.

## Before writing much Ranger

**Read the `ranger-lang` skill.** Four of Ranger's rules cost an hour each when
met by surprise: a returned call needs its own parentheses, one statement per
line, some method names are reserved and fail at every CALL SITE rather than
where they are defined, and arithmetic on a call result needs a variable.

## Adding a file

Put it in `src/`, import it by a path relative to the importing file:

```ranger
Import "Greeter.rgr"
```

Use one consistent path form for a given file across the project — mixing a
bare and a relative import of the same file has broken inherited-method
resolution.

## Adding a dependency

`ranger.json` is Ranger's package file. A local one is a path:

```json
{ "dependencies": { "shared": { "path": "../shared" } } }
```

A remote one is a git repository, a revision and a subdirectory, and
`npm run deps` fetches it and writes `ranger.lock`:

```json
{ "dependencies": {
    "evg": { "git": "https://github.com/terotests/Ranger.git",
             "rev": "HEAD", "subdir": "lib/evg" } } }
```

Either way the import is `Import "pkg:evg/EVGElement.rgr"`.

## The gallery, and the license line

EVG, the layout engine, lives in the Ranger repository under `lib/evg` and
is **MIT**, like this starter, the compiler and the runtime; so are the image
codecs under `lib/image`. `scripts/add-gallery.sh evg` adds it with no notice.

Rave, RangerFlow, Vela, the Office stack: they live under `gallery/` and they
are **AGPL-3.0-or-later**.

Nothing from the gallery is fetched by default. When one is genuinely wanted:

```bash
scripts/add-gallery.sh              # what can be added
scripts/add-gallery.sh evg          # adds lib/evg (MIT), no prompt
scripts/add-gallery.sh rave         # adds it, after saying what the AGPL means
scripts/add-gallery.sh --skills     # installs the evg-edit and rave skills
```

**Say what that means before running it.** Distributing a program built on
gallery code — including over a network — puts that program under the AGPL
unless the user holds a separate commercial license. Compiling their own
program with Ranger imposes nothing; that is the whole point of the split. If
the user has not said they accept the AGPL, ask rather than adding it.

## Targets disagree, and that is the bug worth finding

`to_double` takes `"10 "` in JavaScript and Python and refuses it in Go.
Numbers print as `7` in JavaScript and Go and `7.0` in Python. `npm run
targets:run` runs three of them and fails when the output differs — test the
VALUE, not the printed string, unless the string is the point.

## What else exists

`examples/INDEX.json` lists worked examples by what they DO. Read it before
designing something from scratch: the gallery has usually solved the shape of
the problem already. The full corpus — parsers for TypeScript, C++ and
JavaScript, a spreadsheet, a PowerPoint stack, a game engine, a chart runtime,
a node-graph editor, a Figma reader — is in the
[Ranger repository](https://github.com/terotests/Ranger).
