# Ranger Starter

A [Ranger](https://terotests.github.io/Ranger/) project that compiles and runs
from a clean clone — and compiles the same file to **fourteen target
languages** on a machine with none of their toolchains installed.

The compiler is an npm dependency. There is no Ranger checkout here, nothing is
installed globally, and the whole thing is MIT.

```bash
git clone --depth 1 https://github.com/terotests/RangerStarter my-app
cd my-app
rm -rf .git && git init          # make it yours
npm install

npm start          # hei maailma
npm test           # three expectations, and an exit code CI can fail on
npm run targets    # the same source as Swift, Kotlin, Rust, Go, C++, …
```

`npm start` prints in about a second on a cold clone.

## What is in it

```
src/Main.rgr            the entry point ranger.json names
src/Greeter.rgr         a class it imports — two files, so Import is shown
src/MainTest.rgr        npm test; exits non-zero when an expectation fails
examples/               worked examples; INDEX.json says what each one does
scripts/rgr             compile and run, and FAIL when the compile fails
scripts/targets.sh      all fourteen targets, then run the ones this machine has
scripts/deps.sh         fetch what ranger.json names, and fail when the fetch fails
scripts/package.sh      package.json, pyproject.toml, Package.swift, build.gradle.kts, …
scripts/add-gallery.sh  add EVG (MIT) or opt in to an AGPL gallery package
ranger.json             Ranger's own package file: entry point and dependencies
.claude/skills/         agent skills, loaded by Claude Code in this directory
AGENTS.md               the same instructions for any coding agent
.github/workflows/ci.yml  build, test, all fourteen targets, and a run on three
build/                  everything the compiler writes — gitignored
```

## The one thing to know

**Ranger compilers through 3.5.1 print `[FAIL]` and then exit 0.** Written the
obvious way,

```bash
npx rgrc src/Main.rgr -o=Main.js && node build/Main.js     # ← DO NOT
```

the `&&` is satisfied by that zero, the *previous* build is still on disk, and
node runs that one. The program prints what it printed before your change: the
edit looks applied, the test looks green, and neither is true.

A failed compile exits non-zero in later compilers, but the one on this machine
is whatever `npm install` resolved. `scripts/rgr` does not depend on the
answer: it deletes the output first, reads the compiler's log as well as its
exit status, and treats a missing output file as an error.

```bash
scripts/rgr run   src/Main.rgr             # compile to JavaScript and run it
scripts/rgr run   src/Main.rgr -l=python   # the same source, as Python
scripts/rgr build src/Main.rgr -l=go       # compile only
scripts/rgr check src/Greeter.rgr          # does it compile? nothing else
```

Every `npm` script here goes through it. Nothing calls `rgrc` directly.

## Commands

| | |
| --- | --- |
| `npm start` | compile `src/Main.rgr` and run it |
| `npm test` | run `src/MainTest.rgr`; non-zero exit on a failed expectation |
| `npm run check` | does the entry point compile? |
| `npm run targets` | compile to all fourteen targets into `build/targets/` |
| `npm run targets:run` | and run the three this machine has, failing if they disagree |
| `npm run example:calc` | a recursive-descent parser, as JavaScript |
| `npm run deps` | fetch what `ranger.json` names; writes `ranger.lock` |
| `npm run deps:frozen` | the CI form: fail rather than fetch what the lock does not cover |
| `npm run package` | the packaging each ecosystem expects — see below |
| `npm run gallery` | list the gallery packages, and what adding one costs |

## Fourteen targets, one file

```
$ npm run targets

TARGET      RESULT    OUTPUT
----------  --------  ------
es6         ok        build/targets/es6/Main.js (34 lines)
python      ok        build/targets/python/Main.py (30 lines)
go          ok        build/targets/go/Main.go (48 lines)
cpp         ok        build/targets/cpp/Main.cpp (232 lines)
rust        ok        build/targets/rust/Main.rs (191 lines)
java7       ok        build/targets/java7/ (2 files, 39 lines)
kotlin      ok        build/targets/kotlin/Main.kt (43 lines)
swift6      ok        build/targets/swift6/Main.swift (43 lines)
swift3      ok        build/targets/swift3/Main.swift (43 lines)
dart        ok        build/targets/dart/Main.dart (38 lines)
php         ok        build/targets/php/Main.php (33 lines)
csharp      ok        build/targets/csharp/Main.cs (32 lines)
scala       ok        build/targets/scala/Main.scala (14 lines)
llvm        ok        build/targets/llvm/Main.ll (370 lines)

14 compiled, 0 failed
```

Generating Swift does not need Xcode, so this runs anywhere Node does. What it
proves is that each writer emitted source — how complete that source is varies
by target, and `ok` here is not a promise that the result builds and runs under
its own toolchain. Ranger is stronger on some targets than others, and the
[front page](https://terotests.github.io/Ranger/) says which.

`npm run targets:run` is the stronger check: it runs the JavaScript, the Python
and the Go and **fails when their output differs**. That is the bug worth
finding early, and it is a real one —

```
1 + 2 * 3 = 7      # JavaScript, Go
1 + 2 * 3 = 7.0    # Python
```

— so tests compare values, not printed strings, unless the string is the point.
`.claude/skills/ranger-lang/SKILL.md` has the list of places the targets
disagree; `to_double` on an untrimmed string is the expensive one.

## Dependencies

`ranger.json` is Ranger's package file, separate from `package.json`. A local
dependency is a path; a remote one is a git repository, a revision and a
subdirectory:

```json
{
  "name": "ranger-starter",
  "entry": "src/Main.rgr",
  "dependencies": {
    "shared": { "path": "../shared" },
    "evg": {
      "git": "https://github.com/terotests/Ranger.git",
      "rev": "HEAD",
      "subdir": "lib/evg"
    }
  }
}
```

`npm run deps` fetches them — the compiler speaks the Git pack protocol
itself, so no `git` process is spawned — and writes `ranger.lock` with the
resolved commit and a content hash. Transitive dependencies come with it: ask
for `vela` and `evg` arrives too, because `gallery/vela/ranger.json` says so —
and `image` and `zip` with it, because `lib/evg/ranger.json` names them.
Import either kind the same way:

```ranger
Import "pkg:evg/EVGElement.rgr"
```

`npm run deps:frozen` is the CI form: it fails rather than fetching anything
the lock does not already cover. Commit both `ranger.json` and `ranger.lock`;
`scripts/add-gallery.sh` pins the resolved commit into `ranger.json` for you,
because `rev: HEAD` is a moving target rather than a dependency.

`rgrc install` shared the compiler's habit of printing `[FAIL]` and exiting 0,
so these go through `scripts/deps.sh`, which reads the log — otherwise, on a
compiler through 3.5.1, a `-frozen` check that could not cover the lock would
still report a green CI build.

## Shipping it as a package

`rgr build` writes `Main.kt`. That is a file, not something Gradle can resolve.
The compiler also knows how to write the manifest each ecosystem expects, and
`scripts/package.sh` asks for it — with the name, version, description, author
and license read from `package.json`, so there is one place to change them.

```bash
npm run package                    # the list
scripts/package.sh npm             # build/pkg/npm:    package.json + Main.js
scripts/package.sh python swift6   # pyproject.toml,   Package.swift + .docc
npm run package:all                # npm, pip, NuGet, Gradle, SwiftPM, pub
```

```
csharp -> build/pkg/csharp
    Main.cs
    README.md
    docfx.json
    index.md
    ranger-starter.csproj
    toc.yml
```

What each ecosystem then does with that directory — `npm publish`,
`swift build`, `dotnet pack` — is its own business and needs its own toolchain.

## Agent skills

`.claude/skills/` is loaded automatically by Claude Code working in this
directory, and `AGENTS.md` says the same things to any other agent.

| | |
| --- | --- |
| **ranger-start** | the layout, the build loop, adding a file, adding a dependency |
| **ranger-lang** | the syntax traps whose error messages point at the wrong line — a returned call that needs its own parentheses, two statements on a line, the reserved method names that fail at every call site. Hours each, once |
| **example** | worked examples by what they DO, from `examples/INDEX.json` |

`scripts/add-gallery.sh --skills` adds **evg-edit** (reading, changing and
*checking* a laid-out document) and **rave** (designing an application) when
the gallery is brought in.

All three are MIT, like the rest of this repository. They are copies of the
skills the Ranger repository uses on itself — the upstream text is at
[`plugins/ranger/skills`](https://github.com/terotests/Ranger/tree/master/plugins/ranger/skills),
and `/plugin marketplace add terotests/Ranger` installs them as a plugin
instead, for working in a directory that is not this one.

## The gallery, and the license line

| | |
| --- | --- |
| This starter, the compiler, the runtime, `lib/` — including EVG (`lib/evg`) and the image codecs (`lib/image`) | **MIT** |
| Anything under `gallery/` in the Ranger repository | **AGPL-3.0-or-later** |

EVG — a CSS layout engine with no browser in it: flex, grid, stylesheets,
text, and a display list any painter can draw — is MIT, like the compiler. A
program with a screen is still your program.

Rave, RangerFlow, Vela, DataGrid, the Office stack and the PDF tools are the
gallery. They are not sample code; they are the application stack, and they
are deliberately not MIT.

**Nothing is fetched by default.** When you want one:

```bash
scripts/add-gallery.sh              # what can be added
scripts/add-gallery.sh evg          # adds lib/evg — MIT, no notice needed
scripts/add-gallery.sh rave         # adds gallery/rave — after saying what the AGPL means
scripts/add-gallery.sh --skills     # the evg-edit and rave skills
```

It writes the dependency into `ranger.json` and the sources into
`vendor/ranger/<name>`, which `.gitignore` keeps out of this MIT tree.

Building on gallery code puts the program you distribute under the AGPL —
including when you only serve it over a network — unless you hold a separate
commercial license. Compiling **your own** program with Ranger imposes nothing:
the compiler is a tool, and its MIT license does not attach to its output, any
more than GCC's does. That is the whole point of the split, and
[LICENSING.md](https://github.com/terotests/Ranger/blob/master/LICENSING.md)
is it in full.

## Where to go next

- [The front page](https://terotests.github.io/Ranger/) — what Ranger is and
  what it reaches.
- [The documentation](https://terotests.github.io/Ranger/docs/) — install,
  types, optionals, traits, generics, and an operator reference generated from
  the compiler's own sources.
- [The playground](https://terotests.github.io/Ranger/playground/) — Ranger
  compiled in a browser tab, with nothing installed.
- [The Ranger repository](https://github.com/terotests/Ranger) — the compiler,
  the gallery and the full example corpus.

Ranger is **experimental**. Target quality varies by language and by feature
area, and you should expect to fix a bug or add a capability now and then. It
is strongest as a portable-algorithm compiler and a DSL toolchain.

## License

MIT — see [LICENSE](LICENSE). Use this as the starting point for anything,
including proprietary work.
