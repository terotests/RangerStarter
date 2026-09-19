# Working in this project

A Ranger project. One typed source language, fourteen target languages, and a
compiler that is an npm dependency rather than a checkout.

Read `.claude/skills/ranger-start/SKILL.md` for the layout and the loop, and
`.claude/skills/ranger-lang/SKILL.md` before writing any `.rgr`. What follows
is the short version — the parts that cost the most when missed.

## Compilers through 3.5.1 exit 0 when they fail

`rgrc` prints `[FAIL]` and `Compilation FAILED`, and up to 3.5.1 **returned
success**.

```bash
npx rgrc src/Main.rgr -o=Main.js && node build/Main.js     # ← DO NOT
```

The `&&` is satisfied by that zero, the previous build is still on disk, and
node runs that one: the edit looks applied and the test looks green when
neither is true. Later compilers exit non-zero, but which one is installed here
is `npm install`'s answer, not yours.

Use `scripts/rgr`, which deletes the output first, reads the log as well as the
exit status, and fails on a missing output file.

```bash
scripts/rgr run   src/Main.rgr           # compile to JS and run
scripts/rgr run   src/Main.rgr -l=python # same source, as Python
scripts/rgr build src/Main.rgr -l=go     # compile only
scripts/rgr check src/Main.rgr           # does it compile? nothing else
```

Every `npm` script in `package.json` goes through it.

## Commands

| | |
| --- | --- |
| `npm start` | compile `src/Main.rgr` and run it |
| `npm test` | `src/MainTest.rgr` — exits non-zero when an expectation fails |
| `npm run targets` | compile to all fourteen targets into `build/targets/` |
| `npm run targets:run` | and run the three this machine has, failing if they disagree |
| `npm run example:calc` | the bundled parser example |
| `npm run deps` | fetch what `ranger.json` names, write `ranger.lock` |
| `npm run package` | the manifest each target ecosystem expects, into `build/pkg/` |
| `npm run gallery` | what can be added from the Ranger gallery, and what that costs |

## The configurator: `src/starter/`

This repository is becoming the **project configurator** for Ranger, written in
Ranger. [PLAN_STARTER.md](PLAN_STARTER.md) is the design; what exists today is
the engine, not the questionnaire.

```
ranger.project.json  ->  StarterConfig  ->  ProjectPlan  ->  FilePlan  ->  disk
   (the intent)           (a view over        (pure)        (pure)       (the host)
                           the JSON tree)
```

Everything left of the last arrow is pure -- no filesystem, no terminal, no
process -- which is why `npm run starter:test` runs 437 checks over plans and
merges without touching a disk, and why it runs on **three targets**:

```bash
npm run starter:test           # es6
npm run starter:test:python
npm run starter:test:go
npm run starter:targets        # compiles the core to every target
```

| | |
| --- | --- |
| `npm run starter:build` | compile the CLI to `bin/StarterMain.js` (`npm install` does this) |
| `npm run starter:dump` | print a plan for a configuration built in code |
| `npm run starter:frames` | the wizard's screens, drawn from a scripted key sequence |
| `npm run wizard:shots` | regenerate the screenshots in `docs/WIZARD.md` |
| `npm run desktop:shot` | a picture of the window the desktop surface generates, taken with no display |
| `node bin/ranger-starter.js help` | the commands |

The questionnaire is [`docs/WIZARD.md`](docs/WIZARD.md), screen by screen. Its
state machine (`StarterWizard`) and its renderer (`StarterWizardView`) are both
pure — `render` answers lines, `onKey` changes state, and the host only clears
the screen and prints. That is what makes the wizard testable from a key script
and what makes the screenshots generated rather than captured by hand.

Driving it without a questionnaire, which is what an agent should do. Start with
`describe`: it is one call that answers the commands and their flags, the
surfaces this build can actually generate (as opposed to the ones the config file
has slots for), the targets the installed compiler has, the skills it can
install, and a configuration that works.

```bash
node bin/ranger-starter.js describe --json
node bin/ranger-starter.js init --name demo --surfaces cli,web --targets es6,go --docs --json
node bin/ranger-starter.js plan --json      # the actions apply will perform
node bin/ranger-starter.js apply --json
node bin/ranger-starter.js doctor --json    # what this machine is missing
```

Android and iOS also take `--devices`. `describe --json` carries each surface's
vocabulary and the default that applies when the flag names none, so there is
nothing to guess:

```bash
node bin/ranger-starter.js init --name demo --surfaces android,ios \
    --devices phone,tablet,iphone --json
```

The two vocabularies do not overlap — Android has `phone`, iOS has `iphone` — so
one list is routed to whichever surfaces know each name. A name nobody knows is
an error, not a silent default.

`desktop`, `android` and `ios` are three hosts for **one** module,
`src/Shared.rgr`, compiled to C++, Kotlin and Swift. Desktop is the only one a
plain CI runner can prove, and the generated workflow runs
`npm run desktop:smoke` — thirty frames under `SDL_VIDEODRIVER=dummy` — after
installing `libsdl2-dev`.

Every command takes `--json`, **including the failures** — a `--json` run that
answered prose on error would leave an agent parsing sentences, which is the
thing the flag exists to avoid. Exit status is 0 for worked, 1 for a problem
with the project, 2 for a problem with the command line.

`describe` reads the profile registry and the target table, not a hand-kept
list, so a surface it reports as available is one `apply` will generate. A test
asserts that, and that the example configuration it prints plans cleanly.

Three things to know before changing any of it:

- **`src/starter/` is flat on purpose.** Profiles use inheritance, and importing
  one file by two different path spellings (`"X.rgr"` from here, `"../X.rgr"`
  from a subdirectory) is the documented way to break inherited-method
  resolution. No subdirectories until that stops being true.
- **Generation is idempotent, and that is tested.** A generated file is
  fingerprinted in `.ranger/generated.json`; `package.json` is parsed and merged;
  README/AGENTS/CLAUDE are written only between `<!-- ranger:start ... -->`
  markers. Applying twice changes nothing, turning a surface off removes exactly
  what it added, and a file you have edited is kept and reported rather than
  overwritten.
- **Six operators are declared in `StarterHost.rgr`** -- a synchronous file
  read, a file delete, setting the exit code, the platform name, whether stdin is
  a terminal, and giving stdin back -- because the compiler `npm install`
  resolves (3.5.1) has none of them. Each carries the name of the built-in that
  replaces it, where there is one. `StarterText.joinWith` is there for the same reason
  (`join` on Go was missing its import until Ranger ISSUES.md #88).

## Syntax rules that fail somewhere other than the mistake

- **A returned call may need its own parentheses.** `return (fn1(3))`. A dotted
  receiver is folded for you — `return this.helper()` parses — a bare local
  lambda is not.
- **One statement per line.** `{ x = 1  return true }` is a parse error however
  tidy it looks.
- **Reserved method names.** Defining `contains`, `startsWith`, `endsWith`,
  `trim`, `first`, `last`, `remove`, `insert`, `write`, `read`, `normalize`,
  `toString`, `has`, `sqrt`, `make` or `wrap` on your own class compiles, and then every CALL
  SITE fails with "Class X does not have method …". Rename.
- **Never start a statement with a parenthesised receiver.** Bind first:
  `def recv:T (expr)` then `recv.method()`.
- **Optional annotations go on the name**, not the type:
  `fn find@(optional):Thing (path:string)`.
- Integer division is `idiv`; `/` is real division. Elvis is prefix:
  `(?? value fallback)`. There is no `abs` builtin.

## Targets disagree — check, do not assume

`to_double` accepts `"10 "` in JavaScript and Python and refuses it in Go, so
`(to_double (trim text))` is the portable form. Numbers print as `7` in
JavaScript and Go and `7.0` in Python, so test the value rather than the
printed string. `npm run targets:run` is what actually checks a portability
claim.

## The license line

| | |
| --- | --- |
| This project, the compiler, the runtime, `lib/` — including EVG (`lib/evg`) and `lib/image` | **MIT** |
| Anything under `gallery/` in the Ranger repository | **AGPL-3.0-or-later** |

EVG, the layout engine, is MIT: `scripts/add-gallery.sh evg` adds it with no
notice, because there is nothing to warn about. Rave, RangerFlow, Vela,
DataGrid, the Office and PDF stacks are the gallery. Nothing from it is
fetched by default. `scripts/add-gallery.sh` adds one on purpose, and it
prints what the AGPL means before it does.

**Do not add a gallery dependency without saying what it means first.**
Distributing a program built on gallery code — including over a network — puts
that program under the AGPL unless the author holds a separate commercial
license. Compiling their own program with Ranger imposes nothing.

`vendor/` is gitignored for the same reason: fetched AGPL sources do not belong
in this MIT tree.

## Where the rest is

The gallery, the full example corpus and the compiler's own sources are in the
[Ranger repository](https://github.com/terotests/Ranger).
[LICENSING.md](https://github.com/terotests/Ranger/blob/master/LICENSING.md) is
the license split in full; the
[documentation](https://terotests.github.io/Ranger/docs/) has types, optionals,
traits, generics and the operator reference.
