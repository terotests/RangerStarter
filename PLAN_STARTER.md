# PLAN_STARTER — RangerStarter as the Ranger project configurator

Status: **M0 to M5, M7 (the wizard) and the web half of M6 are implemented and
tested.** See
§20, at the end, for exactly what exists, what it is verified against, and what
changed from this design once it met the compiler. §1 to §19 are the design as
originally written and are not edited to match.

This document is the plan for turning
this repository from a starter *tree* into a starter *tool*: a command line
program that asks what you are building, writes a project description, and
generates the project from it — for a human at a terminal and for a coding
agent in CI, through the same engine.

It is written against what the compiler and the libraries actually have today,
which is checked below rather than assumed. Every claim about an operator, a
flag or a library file was verified against `ranger-compiler` 3.5.1 and the
[Ranger repository](https://github.com/terotests/Ranger) at the revision this
was written. Where something is missing, it says so and says what it costs.

---

## 1. The one design decision everything else follows from

**The wizard, the project description and the generated project are three
separate things.**

```
  questions  ──►  ranger.project.json  ──►  ProjectPlan ──► FilePlan ──► disk
  (a frontend)      (the source of truth)      (pure)       (pure)     (the host)
```

The wizard is a frontend. It is not the product and it is not on the critical
path: an agent, a CI job or a second wizard written in a different language can
write the JSON directly and get a byte-identical project. Everything to the
right of the first arrow is pure — no filesystem, no terminal, no process — so
fifty configurations can be planned in a test without touching disk.

That is the whole architecture. The rest of this document is consequences.

### Why the current starter is too difficult

Cloning a tree means the reader has to work out which parts of it are theirs.
`src/Greeter.rgr` is an example, `scripts/targets.sh` is infrastructure,
`examples/` is documentation, and nothing in the tree says which is which. A
generated project has only the reader's own files in it, because everything
else was a decision the tool already made.

---

## 2. Three dimensions, not one menu

The obvious modelling — "1) library 2) mobile app 3) desktop app" — is wrong,
and it is wrong in a way that is expensive to undo later, because it bakes an
exclusive choice into the config file. There are three *independent*
dimensions:

| Dimension | Values | Cardinality |
| --- | --- | --- |
| **Kind** | `application`, `library` | one |
| **Surfaces** | `cli`, `web`, `server`, `desktop`, `android`, `ios` | many |
| **Targets** | the compiler's fourteen, per surface | many, constrained by the surface |

So all of these are expressible, and none of them is a special case:

```
application → web + android + ios          a product with three faces
library     → typescript + cpp + kotlin + python
application → cli → es6 + go + cpp         one tool, three binaries
library     → cli                          a library with a reference CLI
```

A `library` with surfaces is not a contradiction: the surfaces are what it is
*built against*, and a library with a `cli` surface gets a reference binary and
a smoke test, which is the most useful thing a library can have.

The wizard still asks simple questions. It just does not store the answers as
one enum.

---

## 3. `ranger.project.json`

The file is the product. It is versioned, hand-editable, and diffable in a
review.

```json
{
  "schema": 1,
  "name": "northwind",
  "kind": "application",
  "license": "MIT",

  "surfaces": {
    "cli":     { "enabled": true,  "targets": ["es6", "go"], "entry": "src/Main.rgr" },
    "library": { "enabled": false, "targets": [] },
    "web":     { "enabled": true,  "target": "es6", "tooling": "vite", "modules": "esm" },
    "server":  { "enabled": false, "target": "es6" },
    "desktop": { "enabled": false, "runtime": "sdl2", "target": "cpp" },
    "android": { "enabled": true,  "target": "kotlin",
                 "package": "com.example.northwind",
                 "devices": ["phone", "tablet"] },
    "ios":     { "enabled": true,  "target": "swift6",
                 "bundleId": "com.example.northwind",
                 "devices": ["iphone", "ipad"] }
  },

  "documentation": { "enabled": true, "api": true, "strict": false },
  "agents":        { "agentsMd": true, "claude": true, "skills": "auto" },
  "ci":            { "github": true, "targetMatrix": true }
}
```

### 3.1 It is not `ranger.json`, and that matters

`ranger.json` already exists and belongs to the **compiler**: it names the
entry point and the Ranger package dependencies, and `rgrc install` reads it.
The two files must not be merged now, and the generator must treat `ranger.json`
as an *output*:

```
ranger.project.json   the author's intent          (the tool's input)
        │
        ├──►  ranger.json          entry, dependencies, license   (merged)
        ├──►  package.json         scripts, devDependencies       (merged)
        └──►  everything else                                     (generated)
```

That ordering is also the migration path the review's "project manifest"
convergence wants: when the compiler, the package resolver, CodeGraph and the
docs generator eventually want one project description, `ranger.project.json`
is already the superset, and `ranger.json` is already derived from it rather
than maintained beside it. `schema: 1` is there so that merger does not need a
flag day.

### 3.2 Validation is part of the model, not the wizard

`validateConfig` answers a list of problems, each with a path into the JSON:

```
surfaces.android.target   "android needs kotlin; got swift6"
surfaces.cli.targets[2]   "llvm has no package manifest; it cannot carry a CLI surface alone"
name                      "must be a valid npm package name and a valid Ranger identifier"
```

The wizard runs it after every answer; `--non-interactive` runs it before
planning and refuses with a non-zero exit. Same function, two callers.

---

## 4. Architecture: a pure core and one host

```
                    ranger-starter core
                   /                   \
        no filesystem                NodeHost
        no terminal                      │
        no process                       │
              │                          │
   Config → Plan → FilePlan  ──────► apply / prompt / exec
```

Proposed layout in this repository:

```
src/starter/
    StarterMain.rgr            argv → a command → an exit code
    StarterConfig.rgr          the model, load, save, validate, defaults
    StarterPlanner.rgr         Config → ProjectPlan   (pure)
    StarterFilePlan.rgr        the actions, and their ordering            (pure)
    StarterGenerator.rgr       ProjectPlan → FilePlan  (pure)
    StarterTemplates.rgr       text templates and their substitution      (pure)
    StarterPackageJson.rgr     structured merge of package.json           (pure)
    StarterMarkdown.rgr        managed-section merge for Markdown         (pure)
    StarterManifest.rgr        what we wrote last time, and its hashes    (pure)
    StarterDoctor.rgr          tool checks, as decisions                  (pure)
    StarterWizard.rgr          the questionnaire as a state machine       (pure)
    StarterQuestions.rgr       the question set, contributed by profiles  (pure)

    profiles/
        StarterProfile.rgr     the trait every profile implements
        CliProfile.rgr
        LibraryProfile.rgr
        WebProfile.rgr
        ServerProfile.rgr
        DesktopSdl2Profile.rgr
        AndroidProfile.rgr
        IosProfile.rgr
        ProfileRegistry.rgr

    hosts/
        NodeHost.rgr           read, write, mkdir, delete, exec, terminal
        HostTerminal.rgr       raw-mode rendering and key decoding
        FakeHost.rgr           an in-memory host, for the tests

src/starter/StarterTest.rgr    golden plans, merges, wizard transitions
```

`StarterWizard` being pure is the part that is easy to get wrong and worth the
discipline: it is a state machine over `(questions, answers, keypress) →
(answers, what to draw)`. `HostTerminal` draws and reads. That is what makes
the questionnaire testable — a test feeds it the key sequence
`down space down space return` and asserts the resulting config, with no TTY
anywhere.

### 4.1 What the host needs, and what exists today

Everything the host needs is already an operator, with two exceptions.

| Need | Operator | Status |
| --- | --- | --- |
| Read a file | `read_file_sync path file` (optional string) | present |
| Write a file | `write_file path file data` | present |
| Create a directory | `create_dir path` | present |
| Does it exist | `file_exists path file`, `dir_exists path` | present |
| Run a program | `run_process_result prog args cwd capture env` | present, and `lib/Shell.rgr` is the face to write against |
| Arguments | `shell_arg i`, `shell_arg_cnt` — or `lib/CmdParams.rgr` | present |
| Exit status | `set_exit_code`, `exit` | present |
| Terminal drawing | `clear_screen`, `move_cursor`, `hide_cursor`, `show_cursor`, `write` | present |
| Keyboard | `on_keypress key { … }` + `poll_keypress` + `sleep_ms` | present — this is the `gallery/invaders` loop |
| **Delete a file** | `remove_file` — **es6 only**, in `lib/ranger-dir.rgr` | host-only, acceptable |
| **List a directory** | — | **missing** |

Two consequences, both fine:

* The host is es6 and may use `lib/ranger-dir.rgr`'s `remove_file`. The *core*
  never deletes; it emits a `delete` action and the host performs it.
* Nothing in the design needs to enumerate a directory. The generated-file
  manifest (§6.2) is what replaces "look at what is on disk", and it is better
  than a directory listing, because it also knows what it wrote *last* time.

**There is no blocking line read**, and none is needed: the wizard is a
raw-mode keypress loop, so text fields (project name, bundle id) are edited by
handling `backspace` and printable keys ourselves. That is about forty lines in
`HostTerminal` and it is the same code path on every target, which a
`readline`-based design would not be.

---

## 5. Profiles are plugins

A trait, a registry, and no `if web` anywhere in the generator.

```ranger
trait StarterProfile {
    fn id:string ()
    fn displayName:string ()
    fn kindsSupported:[string] ()
    fn targetsAllowed:[string] ()
    fn questions:[StarterQuestion] (cfg:StarterConfig)
    fn validate:[StarterProblem] (cfg:StarterConfig)
    fn contributeFiles:void (cfg:StarterConfig plan:ProjectPlan)
    fn contributeScripts:void (cfg:StarterConfig plan:ProjectPlan)
    fn contributeDependencies:void (cfg:StarterConfig plan:ProjectPlan)
    fn contributeAgentSections:void (cfg:StarterConfig plan:ProjectPlan)
    fn contributeSkills:void (cfg:StarterConfig plan:ProjectPlan)
    fn contributeDocumentation:void (cfg:StarterConfig plan:ProjectPlan)
    fn contributeDoctorChecks:void (cfg:StarterConfig plan:ProjectPlan)
}
```

Adding `WasmProfile` later is a file and one registry line. It does not touch
the wizard, the planner, the generator, `AGENTS.md` generation or the doctor —
which is the test of whether the seam is in the right place.

Ordering is the planner's business, not the profile's: profiles contribute into
a `ProjectPlan` whose script names, dependency set and Markdown sections are
merged deterministically (sorted by profile id, then by key) so that two
profiles contributing `docs` scripts produce the same file every time.

---

## 6. The FilePlan, and why generation is idempotent

`npm run setup` ten times must produce the same tree as once. This is the most
important engineering requirement in the document, because a configurator that
cannot be re-run is a configurator you use once — which is what the current
starter already is.

### 6.1 The actions

```
createFile        path, contents, ownership
mergeJson         path, a patch, a merge strategy per key
mergeMarkdown     path, section id, contents
deleteGenerated   path                      (only if we wrote it and it is unchanged)
addDependency     name, version, dev?       (recorded, installed once at the end)
runCommand        program, args, cwd        (post-generation, e.g. npm install)
```

`plan` prints them and writes nothing. `apply` performs them in that order.

### 6.2 Three ownerships, and a manifest

| Ownership | Examples | Behaviour |
| --- | --- | --- |
| `generated` | build scripts, host shells, CMakeLists, CI workflow | overwritten |
| `structured` | `package.json`, `ranger.json`, `vite.config.js` | parsed and merged; unknown keys kept |
| `managed` | `README.md`, `AGENTS.md`, `CLAUDE.md` | only between markers |

Markdown managed sections:

```md
<!-- ranger:start build-commands -->
…generated…
<!-- ranger:end build-commands -->
```

Everything outside the markers belongs to the author, forever.

`.ranger/generated.json` records every path the tool wrote and a hash of what
it wrote:

```json
{ "schema": 1,
  "files": { "desktop/CMakeLists.txt": { "sha256": "…", "profile": "desktop" } } }
```

That single file buys three properties nothing else does:

1. **Turning a surface off can remove its files.** Only the ones whose hash
   still matches; an edited file is kept and reported, never deleted.
2. **A re-run is a no-op.** Unchanged content is not rewritten, so `git status`
   is clean and the "zero diff" milestone is checkable by `git diff --exit-code`.
3. **An upgrade is legible.** When the tool's templates change, it can say "I
   want to update these four files you have not touched, and these two you
   have" instead of clobbering or giving up.

---

## 7. Commands

One engine, two front doors.

```bash
ranger-starter init          # wizard, then write config, then apply
ranger-starter configure     # wizard over the existing config
ranger-starter plan          # print the FilePlan, write nothing
ranger-starter apply         # config → disk, idempotent
ranger-starter doctor        # can this machine build what is configured?
ranger-starter targets       # what the installed compiler supports
```

In this repository, as npm scripts:

```json
{
  "start":  "node bin/ranger-starter.js run-or-setup",
  "setup":  "node bin/ranger-starter.js configure",
  "plan":   "node bin/ranger-starter.js plan",
  "doctor": "node bin/ranger-starter.js doctor"
}
```

### 7.1 What `npm start` means

```
no ranger.project.json  →  npm start runs the wizard
a ranger.project.json   →  npm start runs the project
```

This is the behaviour asked for — `npm install && npm start` and you are being
asked questions — and it stops being true the moment the project exists, which
is the only way `npm start` can mean what it means in every other npm project.
`npm run setup` is how you get back to the questions. The generated README says
exactly this in three lines.

### 7.2 Agent mode is the same engine

```bash
ranger-starter apply --non-interactive         # from ranger.project.json
ranger-starter apply --config other.json
ranger-starter plan --json                     # machine-readable FilePlan
ranger-starter init --non-interactive \
    --name northwind --kind application \
    --surface web --surface android \
    --target kotlin --devices phone,tablet --docs --agents claude
```

`--non-interactive` never prompts and never guesses: a missing required answer
is an error naming the flag or the JSON path that would supply it. `plan --json`
exists so an agent can read the consequences before allowing the write, which
is the review's best single idea and costs nothing once the plan is a value.

---

## 8. The wizard

A raw-mode keypress loop, drawn with `clear_screen` / `move_cursor` / `write`.
Single select is `up`/`down`/`return`; multi select adds `space`; text fields
handle printable keys and `backspace`. `ctrl-c` restores the cursor and exits
non-zero — `on_keypress`'s es6 template already handles that one.

```text
Ranger project setup                                    (2/6)

Where should it run?
  [x] Command line
  [x] Web
  [ ] Desktop (SDL2)
  [x] Android
  [ ] iOS
  [ ] Server

  space toggles · ↑↓ moves · ⏎ continues · ctrl-c aborts
```

The question *set* is contributed by profiles and ordered by the planner, so
the Android device question only exists because `AndroidProfile` is enabled,
and the target question's options come from the compiler (§9) rather than from
a list in the wizard.

The last screen is the plan, not a "Generate? y/n":

```text
Will create   14 files      Will modify  3      Will install  vite
  src/Main.rgr                package.json
  web/index.html              AGENTS.md
  platforms/android/…         README.md

  ⏎ apply · p full plan · b back
```

---

## 9. Ask the compiler which targets exist

Hardcoding the fourteen into the starter guarantees that in six months the
compiler's list, the starter's list and the documentation's list disagree.

**Compiler-side change (Ranger repository):** a `-targets` flag that prints the
target table, and `-json` for the machine form.

```bash
rgrc -targets -json
```

```json
[ { "id": "es6",   "name": "JavaScript ES6", "tier": "reference",
    "ext": "js",   "packaging": "npm" },
  { "id": "go",    "name": "Go",             "tier": "supported",
    "ext": "go",   "packaging": null },
  { "id": "llvm",  "name": "LLVM IR",        "tier": "experimental",
    "ext": "ll",   "packaging": null } ]
```

The list already exists as `allowed_languages` in
`compiler/VirtualCompiler.rgr:590`; `tier`, `ext` and `packaging` are the three
facts the starter needs that the compiler currently keeps implicitly (the
extension mapping is duplicated in `scripts/rgr` today, which is the
duplication this removes).

**The starter must work without it.** `ranger-compiler` 3.5.1 is what
`npm install` resolves today and it has no `-targets`. So: probe, parse, and on
any failure fall back to a bundled table with `"source": "bundled"` in the
`targets` output and a one-line note. The bundled table is the *only* place the
fourteen are written down in this repository.

---

## 10. The surfaces, one at a time

Seven profiles. The first four need no toolchain beyond Node; the last three
generate host shells that a platform toolchain builds.

### 10.1 `cli` — command line

The broadest surface: every target except `llvm` can carry it.

```
src/Main.rgr          the author's code
scripts/rgr           the compile-and-run wrapper this repo already has
```

Scripts: `start`, `build`, `check`, `test`, and `build:<target>` per chosen
target. The `-nodecli` flag adds the `#!/usr/bin/env node` header when the es6
target is chosen and `kind` is `application`, so the output is directly
executable.

### 10.2 `library` — a package for each ecosystem

No entry point, an exported surface, and the manifest each ecosystem expects.
The compiler writes those manifests itself (`-apipackage`, `-npm`, `-pubspec`,
`-csnamespace`, `-ktpackage`), which `scripts/package.sh` already drives. The
profile's job is to choose the flags per target and wire the scripts:

| Target | Manifest | Flag |
| --- | --- | --- |
| es6 | `package.json` | `-npm`, `-nodemodule` or `-esm` |
| typescript | `package.json` + `.d.ts` | `-typescript` on top of es6 |
| python | `pyproject.toml` | `-apipackage` |
| csharp | `.csproj` + `docfx.json` | `-apipackage -csnamespace=` |
| kotlin | `build.gradle.kts` (Dokka) | `-apipackage -ktpackage=` |
| swift6 | `Package.swift` + `.docc` | `-apipackage` |
| dart | `pubspec.yaml` | `-pubspec` (or `-flutter`) |
| cpp | CMake `add_library` | generated by this profile |
| go, rust, java7, scala, php | source + a build file | generated by this profile |

A library project gets `-apistrict` in CI when `documentation.strict` is set:
an undocumented public declaration then fails the build, which is the only way
API docs stay complete.

### 10.3 `web` — Vite and plain ES modules

Vanilla Vite over a Ranger-generated ES module. No React, no Vue, no Svelte —
framework adapters are a later profile, and starting with one would put a
framework between Ranger and the page on day one.

```
web/index.html
web/main.js            imports the generated module, mounts it
vite.config.js
```

```json
"web:compile": "scripts/rgr build src/Main.rgr -d=build/web -- -esm",
"web:dev":     "npm run web:compile && vite",
"web:build":   "npm run web:compile && vite build",
"web:preview": "vite preview"
```

`-esm` is the flag that makes the output importable; without it the es6 target
writes CommonJS and the Vite build fails in a way that reads like a Vite
problem. That is exactly the kind of thing the generated `AGENTS.md` section
must say out loud.

### 10.4 `server` — a service

Worth having in v1 because it is cheap: the compiler already has HTTP
primitives (`http_get_method`, `http_send`, `sse_send` and the rest) and
`lib/WebServerLib.rgr` is the face over them. Targets: `es6` and `go` to start.
Generates a request handler, a health route, and a `server:dev` script. No HTTP
framework selection in v1.

### 10.5 `desktop` — SDL2 through C++

```
Ranger ──► C++ ──► CMake ──► SDL2 binary
```

```
desktop/CMakeLists.txt
desktop/host/main.cpp        window, event pump, present
```

The application logic stays in `src/`; the host shell is generated and never
edited. The pattern is proven —
`gallery/rangerflow/platform/sdl/build.sh` and `gallery/book/platform/sdl/`
do exactly this — and the quirks it already knows about go straight into the
generated script and the doctor: `pkg-config --exists sdl2` then
`sdl2-config` as a fallback, `clang++` first on macOS and `g++` first on Linux,
`SDL_VIDEODRIVER=dummy` for a headless smoke test in CI.

`-cpp-single-thread` is offered as a config switch, with its warning: it drops
the atomics from reference counting, so a pointer copied across threads
corrupts the count.

Note on drawing: the starter's desktop profile generates a *window with an
event loop*, not a UI toolkit. EVG (`lib/evg`, MIT) is a layout engine and is
addable; the rasteriser and window layer the gallery apps present through
(`gallery/evg_window`, `gallery/game_engine/ui`) are **AGPL**. The profile must
say which is which before it offers either — see §14.

### 10.6 `android` — a Kotlin host shell

```
Ranger ──► Kotlin module ──► Gradle ──► Jetpack Compose host
```

```
platforms/android/settings.gradle.kts
platforms/android/app/build.gradle.kts
platforms/android/app/src/main/AndroidManifest.xml
platforms/android/app/src/main/kotlin/…/MainActivity.kt      host shell
platforms/android/app/src/main/kotlin/…/RangerBridge.kt      host ↔ module
build/android/<Name>.kt                                     generated, do not edit
```

Do not try to generate an Android ecosystem. Generate a boring, stable shell
that owns the lifecycle and calls into the Ranger module —
`gallery/process_counter_android` is that shape already, and its `ISSUES.md` is
the list of Kotlin gaps to expect.

Devices: `phone`, `tablet`, `tv`, `wear`. They select the manifest features,
the `minSdk`, and whether a Leanback or Wear dependency is added — they are not
separate builds.

Quirks that go in the generated `AGENTS.md`: `-ktpackage=` must match the
host's package or nothing resolves; the generated Kotlin goes under
`build/android` and is never hand-edited; `ANDROID_HOME`/`ANDROID_SDK_ROOT` and
a platform level are the doctor's business, not the build's.

### 10.7 `ios` — a Swift host shell, and no `.xcodeproj`

This is the surface with the most already built. `lib/apple/` is **MIT** and is
a complete Apple app builder driving `xcrun`, `swiftc`, `plutil`, `codesign`
and `simctl` over `lib/Shell.rgr` — including `AppleDeviceDoctor.rgr`, which is
the "why will the phone not take the app" chain walked in order. It is tested
on Linux without a Mac because `Shell` has a dry run.

So the iOS profile is a thin thing over an existing library:

```
platforms/ios/App.swift            host shell: lifecycle, a view, the bridge
platforms/ios/Info.plist.json      AppleAppSpec's input, not a hand-written plist
scripts/ios-build.rgr              AppleAppBuilder over the spec
build/ios/<Name>.swift             generated, do not edit
```

Devices: `iphone`, `ipad` in the wizard; `watch` and `tv` exist in
`AppleTarget` and are deferred to a later question rather than being dropped —
the config field is a list, so adding them later is not a schema change.

**Generation must work on Linux and Windows.** A machine with no Xcode can
generate the whole iOS surface and be told by the doctor that it cannot build
it. Refusing to *generate* on a non-Mac would make the config
machine-dependent, which is the one thing it must never be.

### 10.8 Deliberately not in v1

`wasm`, Electron, Tauri, watchOS, tvOS, Flutter UI, embedded, game engine,
Raspberry Pi. Each is a profile file later. Naming them here is the point:
the architecture is what makes them cheap, and adding any of them now would
hide defects in the planner behind template volume.

---

## 11. Per-target quirks the generator must know

Fourteen targets, and the ones that bite are not the exotic ones.

| Target | What the generator must do |
| --- | --- |
| `es6` | `-esm` for the web and for a modern library; `-nodemodule` for CommonJS; `-nodecli` for an executable. Getting this wrong fails in the bundler, not the compiler. |
| typescript | Not a `-l` value — it is `-l=es6 -typescript`. A wizard that offers "TypeScript" as a target must map it. |
| `python` | Numbers print `7.0` where JavaScript prints `7`; a generated smoke test must assert values, not printed strings. `pyproject.toml` via `-apipackage`. |
| `go` | `to_double` refuses `"10 "` where JavaScript and Python accept it, so generated code uses `(to_double (trim s))`. One package per directory. `-forever` for a program that must not fall off the end of main. |
| `cpp` | CMake, and `-cpp-single-thread` only for single-threaded builds. SDL2 discovery order. `-native-fast-alloc` for tool builds only. |
| `rust` | `-rust-shared-classes` is the default. A one-element array literal is flattened to its element ([ISSUES #84](https://github.com/terotests/Ranger/blob/master/ISSUES.md)) — generated code builds argument vectors with `push`, never an inline one-element literal. |
| `kotlin` | `-ktpackage=` must agree with the Android host package. Gradle + Dokka manifest from `-apipackage`. |
| `swift6` / `swift3` | Two targets, not one; `swift6` is the default and `swift3` is kept for old toolchains. SwiftPM + DocC from `-apipackage`. iOS goes through `lib/apple`, not `xcodebuild`. |
| `csharp` | `-csnamespace=`; `.csproj` + `docfx.json`. |
| `dart` | `-pubspec`, and `-flutter` changes the pubspec shape. Requires `-name= -version= -description=`. |
| `java7` | Library surface only in v1. JSON needs `org.json` on the classpath — the generated build file must carry it. |
| `scala` | Library surface only. |
| `php` | Library and server-side only; no packaging manifest generated. |
| `llvm` | Experimental. Cannot carry a surface on its own; offered only as an extra output of a `cli` surface, and the doctor says `clang` is needed. |

Two rules that apply to every target and belong in every generated
`AGENTS.md`:

* **Never call `rgrc` directly.** Compilers through 3.5.1 print
  `Compilation FAILED` and exit **0**, so `rgrc … && node build/Main.js` runs
  the *previous* build and the edit looks applied when it is not. Every
  generated script goes through `scripts/rgr`, which deletes the output first
  and reads the log as well as the status.
* **Targets disagree; `npm run targets:run` is what checks a portability
  claim.** Generated projects get that matrix when more than one target is
  configured.

---

## 12. `doctor`

Platform projects fail because the machine is missing something, and they fail
halfway through a build with an error from someone else's tool. The doctor is
the profiles' `contributeDoctorChecks` collected into one report.

```text
Ranger project doctor — northwind (application: web, android, ios)

  ✓ node 24.4.0
  ✓ ranger-compiler 3.5.1

Web
  ✓ vite 8.0.1

Android
  ✓ java 21
  ✓ gradle 8.9
  ✗ Android SDK platform 36      set ANDROID_HOME, then: sdkmanager "platforms;android-36"

iOS
  – unavailable on linux (needs macOS + Xcode command line tools)

1 actionable problem
```

Three properties, all of which come from making the checks *decisions* rather
than code that shells out inline:

* **Setup never requires the toolchains.** A Windows machine generates the iOS
  surface and is told it cannot build it. A missing toolchain is never a
  generation error.
* **The checks are testable**, because `lib/Shell.rgr`'s dry run records the
  command lines without running them — the same trick that lets
  `lib/apple/apple_test.rgr` check 151 things about an iOS build on Linux.
* **`– unavailable`** is a third state, distinct from ✗. An agent reading
  `doctor --json` must not try to fix macOS on Linux.

---

## 13. Documentation, and dogfooding the doc generator

### 13.1 The vocabulary already exists — use it exactly

Ranger's API documentation is a `doc { … }` block attached as the **tail** of a
declaration, and the compiler already parses it
(`compiler/ng_RangerDocBlock.rgr`). The keys, verified against that parser:

```ranger
fn planProject:ProjectPlan (cfg:StarterConfig) {
    …
} doc {
    public
    description "Turns a validated configuration into the project plan the generator writes from."
    param cfg "A configuration that has already passed validateConfig."
    returns "The plan: files, script entries, dependencies and agent sections."
    example planProjectExample
    since "0.2"
}
```

| Key | Form |
| --- | --- |
| visibility | `public`, `internal`, `experimental` |
| text | `description "…"` (repeatable; joined with a blank line) |
| parameters | `param name "…"` — **never restate the type**; the compiler knows it and a restated type is a type that will disagree |
| result | `returns "…"`, `throws "…"` |
| provenance | `since "…"`, `see "…"`, `category "…"`, `platform "…"`, `attr "…"` |
| examples | `example "literal"` or `example someFunction` (a name, compiled and type-checked) |
| deprecation | `deprecated { since "…" use "…" description "…" }` |

The block must be on the same line as the closing brace — `} doc {`. A `doc`
block on its own line binds to nothing. **No second tag syntax is invented for
the starter.**

Artifacts:

```bash
rgrc src/starter/StarterMain.rgr -apidoc=docs/api -apiformat=json,markdown
```

writes `docs/api/api.json` and `docs/api/api.md`.

### 13.2 What the starter documents about itself

`StarterConfig`, `ProjectPlan`, `FilePlan`, `StarterProfile`, `Generator`, and
the methods `loadConfig`, `validateConfig`, `planProject`, `applyPlan`,
`registerProfile` — each with a description, parameters, return value, and an
`example` reference where the example is worth compiling. `-apistrict` in this
repository's CI, so an undocumented public declaration is a build failure.

That makes the starter a genuine test of the doc generator on a real public
API, which is what the API docs work needs and what a hello-world starter
cannot provide.

### 13.3 What a generated project gets

When `documentation.enabled`:

```
docs/README.md
docs/api/          generated, never hand-edited
```

```json
"docs":       "scripts/rgr ... -- -apidoc=docs/api -apiformat=json,markdown",
"docs:check": "… -apistrict"
```

and one section in `AGENTS.md`. When documentation is off, the scripts, the
directory and the section all disappear — which is the managed-section
mechanism earning its keep.

---

## 14. AGENTS.md, CLAUDE.md, skills, README

### 14.1 One truth, one pointer

`AGENTS.md` is the generic file every coding agent reads: architecture,
source-of-truth files, exact commands, the Ranger syntax traps, the
generated-file policy, the enabled profiles, the docs policy, the license line.
`CLAUDE.md` stays small — read `AGENTS.md` first, then the skills available
here. This repository already has that split and it works; the change is that
the sections become generated.

Each profile contributes one section, between markers:

```md
<!-- ranger:start profile-android -->
Android output is generated from Ranger Kotlin into `build/android`. Do not edit
it. Host code is `platforms/android`. `-ktpackage` must match the host package.
<!-- ranger:end profile-android -->
```

### 14.2 The agent-facing section about the tool itself

The generated `AGENTS.md` must tell an agent how to reconfigure the project
without a questionnaire, because otherwise it will try to answer one:

```md
## Changing the project setup

`ranger.project.json` is the source of truth. To change what this project
builds, edit it and run:

    npm run plan     # what would change; writes nothing
    npm run setup -- --apply

Never hand-edit a file listed in `.ranger/generated.json`; change the config
and re-apply. Managed sections in this file, README.md and CLAUDE.md are
between `<!-- ranger:start … -->` markers — text outside them is yours.
```

### 14.3 Skills follow the profiles

Do not install every Ranger skill. Context size is a real cost: an iOS library
project should not carry SDL2 instructions.

| Configuration | Skills |
| --- | --- |
| always | `ranger-lang`, `ranger-start` |
| documentation on | `ranger-docs` |
| `web` | `ranger-web` |
| `desktop` | `ranger-sdl2` |
| `android` | `ranger-android` |
| `ios` | `ranger-ios` |
| a gallery dependency added | `evg-edit`, `rave` — via `scripts/add-gallery.sh --skills` |

Only `ranger-lang`, `ranger-start`, `example`, `evg-edit` and `rave` exist
today. The rest are written as the profiles land; `skills: "auto"` installs
what exists and says nothing about what does not.

### 14.4 The license line is generated too

This repository is MIT; so are the compiler, the runtime, `lib/evg` and
`lib/image`. Everything under `gallery/` is **AGPL-3.0-or-later**. The starter
never adds a gallery dependency on its own, and `desktop` is the surface where
this will come up first, because the SDL2 *window* is MIT-able but the
rasterised UI layer the gallery apps use is not. The rule stands: say what the
AGPL means before adding anything from `gallery/`, and never add it without
being asked.

### 14.5 README stays short

```md
# Northwind

A Ranger application for Web, Android and iOS.

## Start

    npm install
    npm start

## Commands

    npm test
    npm run web:dev
    npm run android:build
    npm run ios:build
    npm run docs
    npm run doctor

## Change what this project builds

    npm run setup

See AGENTS.md for development rules.
```

Not six hundred lines.

---

## 15. Testing

The planner being pure is what makes this cheap, and it is the reason for the
whole architecture.

| What | How |
| --- | --- |
| Golden plans | ~50 configurations → `FilePlan` → compared against a recorded text form. No disk. |
| Zero-diff re-run | generate into a temp dir, `apply` again, `git diff --exit-code`. |
| Surface removal | enable `desktop`, apply, disable, apply — its files are gone and nothing else changed. |
| A hand-edited file | apply, edit a generated file, apply — it is kept and reported, not clobbered. |
| package.json merge | an existing project with its own scripts and deps keeps all of them. |
| Markdown merge | text outside the markers survives byte-for-byte. |
| Wizard | key sequences → config, through `FakeHost`. No TTY. |
| Doctor | `Shell` dry run: the command lines and the verdicts, on any OS. |
| Core portability | `StarterConfig` + `StarterPlanner` + profiles compiled to all fourteen targets in CI, and *run* on es6, python and go with the same golden plans. Only `NodeHost` is es6-only. |
| Generated projects | a matrix job per surface: generate, then run that surface's own `npm test`/`doctor`. iOS and Android build steps are macOS/SDK-gated; generation is not. |

The last two are the ones that make this a Ranger demonstration rather than a
Node script that happens to be written in Ranger.

---

## 16. Publishing

```json
{
  "name": "ranger-starter",
  "bin": { "ranger-starter": "bin/ranger-starter.js" },
  "files": ["bin/", "build/starter/", "templates/", "README.md", "LICENSE"],
  "dependencies": { "ranger-compiler": "^3.5.1" }
}
```

```bash
npx ranger-starter            # wizard in the current directory
npx ranger-starter my-app     # and create it
```

`bin/ranger-starter.js` is the compiled `StarterMain` plus a three-line
shebang wrapper — the published artifact is JavaScript, so `npx` needs no
Ranger toolchain, and `ranger-compiler` comes along as a dependency so the
generated project can compile immediately.

Names checked on the registry: `ranger-starter`, `create-ranger-app` and
`ranger-start-app` are all free; `create-ranger` is taken. Recommendation:
publish `ranger-starter` as the package, and optionally `create-ranger-app` as
a four-line alias, because that is the package name `npm create ranger-app`
resolves to and it is the convention people will try.

The repository keeps working as a clone — `git clone && npm install && npm start`
is the same code path, reading the local build instead of the published one.

CI publishes on a tag, after the golden plans, the zero-diff check, the
fourteen-target compile and `-apistrict` all pass.

---

## 17. Milestones

The wizard is not first. The wizard is a frontend to a thing that must already
be correct.

| | Scope | Proof |
| --- | --- | --- |
| **M0** | `StarterConfig`, validation, `StarterPlanner`, `FilePlan` — all pure | 50 fixtures produce deterministic golden plans, no disk |
| **M1** | `NodeHost`, `apply`, `plan --json`, `--non-interactive` | an agent generates a CLI project with no prompts; `plan` writes nothing |
| **M2** | Idempotency: ownership tiers, `.ranger/generated.json`, JSON and Markdown merges | re-apply is `git diff --exit-code` clean; surface removal and hand-edit tests pass |
| **M3** | `CliProfile`, `LibraryProfile`; the target table from the compiler with a fallback | multi-target builds and per-ecosystem manifests |
| **M4** | `AGENTS.md`, `CLAUDE.md`, `README.md`, skills, CI workflow | files change with the config; text outside markers survives |
| **M5** | `doctor`, `doctor --json` | correct verdicts on Linux for surfaces it cannot build |
| **M6** | Docs profile; the starter documents its own API | `-apistrict` green; `docs/api` published from `doc { … }` blocks |
| **M7** | The wizard | `npm install && npm start` creates a project from questions |
| **M8** | `WebProfile` (+ Vite), `ServerProfile` | `npm run web:dev` serves; `server:dev` answers |
| **M9** | `DesktopSdl2Profile` | builds and runs headless in CI with `SDL_VIDEODRIVER=dummy` |
| **M10** | `AndroidProfile` | Gradle assembles the host with the generated Kotlin module |
| **M11** | `IosProfile` over `lib/apple` | generates on Linux; builds and launches on a simulator on macOS |
| **M12** | npm publish; `-targets -json` in the compiler | `npx ranger-starter` works from a clean machine |

M0–M2 are the load-bearing ones. If the planner and the idempotency are right,
everything after them is templates and a terminal.

### Ranger-repository work this depends on

| Change | Size | Blocking? |
| --- | --- | --- |
| `rgrc -targets [-json]` with tier, extension and packaging | small; the list is one line in `compiler/VirtualCompiler.rgr` | no — the starter falls back to a bundled table |
| A `doc { … }` block on a `class`, `record` or `shape` tail | `class X { } doc { }` is silently miscompiled today (ISSUES #75) | no — document methods and fields; avoid class-level tails |
| A directory-listing operator | — | no — the generated manifest replaces it |

---

---

## 18. Open decisions

Four things where a different answer changes the work, listed so they can be
decided rather than discovered:

1. **`npm start` overloading.** §7.1 makes it the wizard until a config exists,
   then the project. The alternative is `npm start` always running the project
   and printing "no ranger.project.json — run `npm run setup`". The overload is
   what was asked for and what reads better in a README; the alternative never
   surprises anyone. Currently planned: the overload.
2. **`typescript` as a target the wizard offers.** It is `-l=es6 -typescript`,
   not a target id. Offering it means the config holds something the compiler's
   target list does not, so it needs a `variants` field rather than a target
   entry. Currently planned: offer it, as a variant of `es6`.
3. **Does the wizard run `npm install`?** It has to, for `vite`. Currently
   planned: yes, as the last `runCommand`, skippable with `--no-install`.
4. **Where the starter's own sources live once it is a tool.** Keeping
   `src/Main.rgr` as an example beside `src/starter/` makes the repository its
   own worst test case — a generated project would want `src/` to itself.
   Currently planned: the tool is `src/starter/`, the example project moves to
   `examples/starter-project/`, and a generated project's `src/` is clean.

## 19. What this plan does not do

Framework adapters (React, Vue, Svelte), WASM, Electron, Tauri, watchOS, tvOS,
Flutter UI, embedded targets, a plugin system for third-party profiles, and
merging `ranger.project.json` into the compiler's own project manifest. Each is
named in §10.8 or §3.1 with the seam it arrives through, and none of them is
needed to prove the architecture.

---

## 20. What is built, and what the design got wrong

Written after implementing M0 to M2. The architecture above survived contact;
several of its details did not, and those are the interesting part.

### 20.1 What exists

| File | What it is |
| --- | --- |
| `StarterJson.rgr` | a JSON value, parser and writer with explicit key order |
| `StarterText.rgr` | sorting, line splitting, path and name helpers |
| `StarterHash.rgr` | the generated-file fingerprint |
| `StarterConfig.rgr` | `ranger.project.json` as a typed view over its tree |
| `StarterTargets.rgr` | the target table, from the compiler or bundled |
| `StarterPlan.rgr` | `ProjectPlan`: files, scripts, deps, sections, checks |
| `StarterProfile.rgr` | the profile base class and its seven contributions |
| `ProfileCli.rgr`, `ProfileLibrary.rgr`, `ProfileWeb.rgr`, `ProfileDesktop.rgr`, `ProfileAndroid.rgr`, `ProfileIos.rgr` | the six surfaces that work |
| `StarterProfiles.rgr` | the registry |
| `StarterTemplates.rgr` | the generated file bodies |
| `StarterPlanner.rgr` | `Config` -> `ProjectPlan`, plus the core files |
| `StarterMarkdown.rgr` | managed-region render and merge |
| `StarterJsonMerge.rgr` | structured merge with recorded ownership |
| `StarterManifest.rgr` | `.ranger/generated.json` |
| `StarterFilePlan.rgr` | `DiskState`, `FileAction`, `FilePlan`, pure apply |
| `StarterGenerator.rgr` | `ProjectPlan` + `DiskState` -> `FilePlan` |
| `StarterHost.rgr` | the only file that touches the world |
| `StarterMain.rgr` | argv -> a command -> an exit status |
| `StarterDump.rgr` | print a plan for a configuration built in code |
| `StarterDoctor.rgr` | the pure verdict for one check on one platform |
| `StarterDescribe.rgr` | `describe --json`, from the registries |
| `StarterWizard.rgr`, `StarterWizardView.rgr` | the pure state machine and the pure renderer |
| `StarterTest.rgr` | 423 checks, no filesystem |

### 20.2 What it is verified against

Not "it compiles". The following were run:

* **423 checks on three targets.** `npm run starter:test`, `:python` and `:go`
  all pass, with the compiler `npm install` resolves today.
* **Thirteen of fourteen targets compile** the core. Scala does not, for a
  reason that is not this code's -- see §20.5.
* **A generated project runs.** `init`, `apply`, `npm install`, `npm start`,
  `npm test`, `npm run build:go` -- end to end, in a scratch directory.
* **Applying twice is a no-op**, checked with `git diff --exit-code` on a real
  generated project and by a third pass in the test.
* **A surface toggled on and off leaves the project byte-identical** to one that
  never had it -- `package.json`, `AGENTS.md`, the seeds, all of it.
* **Author edits survive.** A hand-added `lint` script, a `workspaces` key and a
  paragraph of README prose all came through an apply untouched.
* **Three surfaces compile from one module.** A generated
  `desktop,android,ios` project compiles `src/Shared.rgr` to
  `platforms/android/app/src/main/generated/Shared.kt`, to
  `build/ios/Shared.swift` and to `build/desktop/Shared.cpp`; `npm run ios:plan`
  prints the whole iOS build on Linux, where it cannot be run.
* **The desktop surface runs.** A generated `desktop` project builds through
  CMake against the SDL2 an `apt-get install libsdl2-dev` provides and draws
  thirty frames under `SDL_VIDEODRIVER=dummy` -- with the PUBLISHED compiler,
  3.5.1, not a patched one.
* **A hand-edited generated file is kept and reported**, not overwritten.

### 20.3 The four open decisions, decided

1. **`npm start` overloading** -- not implemented yet and no longer needed in the
   form proposed. In a GENERATED project `npm start` runs the project, because a
   configuration exists by definition. The overload only matters for a cloned
   copy of this repository, which is M7's problem.
2. **TypeScript as a target** -- offered, as an `es6` variant. `StarterTarget`
   carries `variantOf`, `languageFlag()` answers `es6`, and the generated script
   is `-l=es6 -- -typescript`. A test asserts it, because the failure mode is
   `Invalid language : typescript` in somebody else's project.
3. **Does apply run `npm install`** -- yes, as the last action, suppressed by
   `--no-install`.
4. **Where the tool lives** -- `src/starter/`, FLAT. Not `src/starter/profiles/`
   as designed: profiles use inheritance, and importing one file by two different
   path spellings is the documented way to break inherited-method resolution.
   Moving the example project out of `src/` has not been done.

### 20.4 Where the design was wrong

* **The `rgr` wrapper cannot be a shell script.** `write_file` cannot set an
  executable bit, so a generated `scripts/rgr` would have to be run as `bash
  scripts/rgr` -- and `bash` is not on PATH in the shell npm uses on Windows. It
  is `scripts/rgr.js`, a node script, which adds no requirement the project did
  not already have and resolves the compiler out of `node_modules` directly
  instead of going through `npx`.
* **`sha256` in the manifest is a `fingerprint`.** There is no hash in a
  dependency-free core, and FNV-1a is not portable: it relies on wrapping at 32 or
  64 bits, and Ranger's `int` is a double on JavaScript, so the same file would
  fingerprint differently depending on which target wrote the manifest. It is two
  rolling polynomial hashes and the length, every intermediate under 1.4e11.
* **Only generated files are fingerprinted.** Recording one for `package.json`
  meant that after an author edited it, the next apply re-fingerprinted it and the
  manifest changed -- so "apply twice is a no-op" was false until the third pass.
  The fingerprint answers "may I overwrite this?", which is only ever asked about
  generated files.
* **Three operators had to be declared.** The compiler `npm install` resolves has
  no synchronous file read (`read_file` is async, `read_file_sync` postdates
  3.5.1), no file delete, and no `set_exit_code`; `main:int` is ignored on es6
  there too. Each is declared in `StarterHost.rgr` for es6, Python and Go, with
  the name of the built-in that replaces it.
* **`join` is not used.** On Go it emitted `strings.Join` without importing
  `strings`, so a program whose only use of that package was `join` produced Go
  that does not build. Fixed upstream (Ranger ISSUES.md #88) but not in the
  published compiler, so the core has `StarterText.joinWith`.
* **A class field needs an INLINE initialiser to be non-optional.** Assigning it
  in the constructor is not enough: the field still reads back as optional and
  cannot be passed to anything expecting the bare type. Three holder fields had
  to move their initialiser onto the declaration.
* **An enabled surface with no profile is an error.** The design did not say what
  should happen. Generating everything except that surface and saying nothing
  would produce a project quietly different from the one asked for.

### 20.5 Blocked, and on what

* **Scala.** The writer refuses `continue` inside a `for` loop
  (Ranger ISSUES.md #89), which is how every guard in this core is written; and
  separately it never emits the `@(main)` body at all while reporting success
  (#90), so a Scala build of ANY program in this repository is a library with no
  entry point. Both were found by this work and are recorded upstream. Neither is
  worked around here: inverting ten guards to dodge a compiler limitation is a
  workaround nobody would ever remove.
* **PHP** carries `$` in a string literal correctly only from the next compiler
  release (#83, fixed upstream). The templates are full of `$`, so a PHP build of
  the core produces broken string literals until then. It compiles.
* **`rgrc -targets -json`** does not exist, so `source` reads `bundled` and
  `doctor` says so.

### 20.6 M3 to M5, and the wizard

The four gaps this section used to list are closed.

* **Skills** arrive through an ASSET seam rather than embedded text. A SKILL.md
  is prose, not a template, but the planner needs its bytes because a generated
  file is fingerprinted -- so the host reads `templates/skills/` before planning
  and hands the texts over exactly as it hands over a `DiskState`.
  `templates/skills/INDEX.json` makes the set self-describing: adding a skill is a
  directory and one entry. A skill the package does not ship is not offered, and
  CLAUDE.md lists only what was installed.
* **A GitHub workflow** that runs what a contributor runs. `npm install`, not
  `npm ci`: a generated project has no lockfile.
* **`plan --json`** is the FilePlan as data -- the same value the text form
  renders.
* **`doctor` reads versions.** One process per check answers both "is it there"
  and "which one", and only node's format is claimed to be understood. Three
  things it got wrong first: `go --version` does not exist (checks carry an
  argument LIST now); `npx --no-install rgrc` answers an npm ERROR when the
  compiler is absent, so the compiler is a FILE check that reads the version out
  of its own manifest; and an unparseable version must not be called too old.
  `doctor --json` is the same verdicts as data, and the verdict rule lives in
  `StarterDoctor` -- pure, taking a platform NAME rather than the host, so a
  `darwin`-only check can be tested for "unavailable" on Linux.

**The wizard (M7)** is built, ahead of M6. Its state machine and its renderer are
both pure: `render` answers `[string]`, `onKey` takes a key name, and the host
only clears the screen and prints. Three things follow, and the middle one is why
it was worth the discipline:

* a test is a key script and an assertion about the configuration that comes out;
* the screenshots in [docs/WIZARD.md](docs/WIZARD.md) are GENERATED by driving
  the real program inside a pty, and the key scripts that make them are the same
  ones the tests assert on;
* the wizard produces a `StarterConfig` and nothing else, so there is exactly one
  generator and the interactive path is not a second implementation.

Getting it running cost two compiler bugs, both now fixed upstream
(Ranger ISSUES.md #91): the emitted keypress handler's own parameter was named
`key`, shadowing any Ranger variable of that name so the block received the host's
key OBJECT; and a key variable named anything else was emitted as `const`, so the
first keypress died with `TypeError: Assignment to constant variable`.

### 20.7 The web surface

`ProfileWeb` generates a page, a Ranger ES module it imports, and Vite. Verified
by generating a project, installing, building it, and LOADING THE BUILT PAGE in a
browser -- and the dev server too, because that is the path with the
`server.fs.allow` trap.

Three details, each a trap somebody would otherwise hit once:

* **The web surface has its own entry point**, `src/Web.rgr`, with no `main`.
  `-esm` exports every class AND calls `main` at the bottom of the emitted file,
  so compiling the command line entry for the browser would run the program on
  page load. Checked, not assumed.
* **`-esm` is not optional.** Without it the es6 target writes CommonJS and the
  failure arrives as a Vite error about `require`.
* **The compiled module lands inside Vite's root** (`web/generated/`), because a
  module outside the root needs `server.fs.allow` and getting that wrong is a 403
  that says nothing. That needed `ProjectPlan.addIgnore`: the `.gitignore` is a
  core file, and a profile that wanted a line in it would otherwise rewrite the
  whole thing.

A web-only project also exposed two gaps that were nothing to do with the web:
`npm start` and `npm test` are what everybody types without reading anything, and
a project without a command line surface had neither. The core supplies both now
-- `start` runs the dev server, and `test` type-checks without pretending to be a
test.

### 20.8 The two mobile surfaces

`ProfileAndroid` and `ProfileIos` are ONE Ranger module, `src/Shared.rgr`, class
`Shared`, compiled to Kotlin for one and to Swift for the other. Two
near-identical modules would be the opposite of what the language is for, and
both surfaces default to the same entry so that nothing has to arrange it.

* **The class is `Shared`, not `App`.** `App` is a SwiftUI PROTOCOL, and a class
  of that name makes the host's `struct NorthwindApp: App` resolve to the wrong
  thing. The host struct is named from the project for the same reason.
* **`-ktpackage` and the host's `package` declaration both come from
  `surfaces.android.package`**, so they cannot disagree. A mismatch does not fail
  the Ranger compile -- it fails later, in Gradle, as an unresolved reference to
  a class that is right there in the source set.
* **iOS builds without `.xcodeproj` and without `xcodebuild`.**
  `scripts/ios-build.rgr` drives `xcrun`, `swiftc`, `plutil` and `codesign`
  through `lib/apple`, which SHIPS INSIDE `ranger-compiler` -- nothing to install
  and nothing to declare. `lib/Shell.rgr`'s dry run is what makes it testable:
  `npm run ios:plan` prints the SDK, the triple, the device families and every
  command line, and executes nothing, so the build's DECISIONS are checked on a
  machine that is not a Mac. Verified that way on Linux.
* **Generating is not building.** The whole iOS surface generates on any machine
  and `doctor` reports the Xcode tools as `unavailable` rather than `missing`.
  Refusing to generate off a Mac would make the configuration machine-dependent,
  which is the one thing it must never be.

Device types are not separate builds. They change the minimum SDK, the manifest
and the dependencies of ONE app: `tv` adds `LEANBACK_LAUNCHER` (without which the
app does not appear on a TV at all) and `androidx.tv:tv-material`; `wear` forces
`minSdk 30`, because Wear OS 3 is API 30 and a lower minimum will not install.
The Android and iOS vocabularies do not overlap on purpose, so one
`--devices phone,tablet,iphone,ipad` is routed to whichever surfaces know each
name, and a name nobody knows is an error rather than a silent default.

The mobile surfaces exposed four things that were nothing to do with mobile:

* **`npm test` type-checked a file the project does not have.**
  `StarterPlanner.entryOf` picked the entry from a hardcoded surface chain --
  cli, then web, then cli again -- so a mobile-only project got `src/Main.rgr`.
  It asks the enabled profiles in registration order now, through a new
  `StarterProfile.entryOf`, so a new surface needs no line in that function.
* **`npm start` answered "missing script"** for a mobile-only project. It cannot
  run an APK, but it can do the nearest useful thing: Android installs on a
  device, iOS builds the bundle.
* **`gradle --version` was reported as a rule of dashes.** `firstLine` is not
  enough for a program that prints a banner first, so version reading is
  `StarterText.versionLine`: the first line carrying both a digit and a letter.
* **The doctor's `unavailable` line read backwards** -- "not available on darwin
  builds from here". It names both platforms now: "only checkable on macOS --
  this is Linux".

The screenshot harness gained something the mobile walk forced: each step may
name the lines its frame must contain, and a frame that does not match fails the
run. The first mobile walk produced a set of frames that looked plausible and
were all one step out of phase, because a target question for a single-target
surface opens ALREADY TICKED and the script's `space` was unticking it. A
screenshot nobody checks is a screenshot that documents last month.

### 20.9 The desktop surface

An SDL2 window over the SAME module the mobile surfaces use. `src/Shared.rgr`
compiles to C++, and `desktop/host/main.cpp` -- a seed, because what the window
draws is the point of having one -- owns the window, the event loop and the
pixels. Three hosts, one module.

* **The module is included, not linked.** The C++ target emits one `.cpp`
  carrying the class definitions and no header to go with them, so the host
  `#include`s it and the program is one translation unit. There was nothing to
  link against.
* **SDL2 is discovered two ways** -- `find_package(SDL2)` for the config package
  Homebrew and vcpkg ship, `pkg_check_modules` for the distribution one, which
  on Debian and Ubuntu is the only one there is. Knowing one of them fails on
  half the machines with a message about a missing package that is installed.
* **The renderer falls back to software.** A container, a VM or a runner has no
  accelerated renderer, and failing there rather than falling back is the single
  most common way a working SDL2 program looks broken.
* **`-cpp-single-thread` is a config switch and a WARNING, not a refusal.** It
  drops the atomics from reference counting; the generated host starts no
  threads, so it is correct as generated and wrong the moment one exists. `plan`
  says so every time it is on. It stays out of the wizard: the honest default is
  off, and anybody who needs it is already editing the file.
* **No gallery dependency, and the licence is why.** EVG (`lib/evg`) is MIT and
  addable; the rasteriser and window layer the gallery applications present
  through are AGPL-3.0-or-later. The profile generates a window with an event
  loop and pulls in neither.

**It found a compiler bug that only a module can find.** `rg_ordered_map::at`
throws `std::out_of_range`, and the C++ prelude never included `<stdexcept>`. A
whole program gets the header through the iostream chain and nobody ever
noticed; a module compiled for a host shell to include does not, and fails on a
declaration the user never wrote. Fixed upstream -- Ranger ISSUES.md #94, with a
test that compiles a `main`-less module against a host -- and the generated host
includes the header itself, because a generated project uses the PUBLISHED
compiler and 3.5.1 still has the bug. The include is harmless once the fix
ships.

Two things moved out of the planner while this landed, both the same mistake in
two places. `npm start`'s fallback was a chain of `if (cfg.isEnabled(...))` in
`ensureStartAndTest` -- the same hardcoded surface chain that had `entryOf`
type-checking a file a mobile project does not have. It is
`StarterProfile.startCommand` now, asked of the enabled profiles in registration
order, so which surface claims `start` is a property of the registry rather than
of a chain nobody remembers to extend.

CI steps are the same idea. `PlanScript` carries `inCi` and `ciSetup`, so a
surface that can be exercised on a plain runner says so and brings whatever the
runner has to install. Desktop is the only one of the three hosts that can:
SDL2 is an apt package, the dummy driver needs no display, and the frame limit
means the job ends. Android wants an SDK and iOS wants a Mac, so neither asks.

### 20.10 Driving it as an agent

`describe --json` is one call that answers the commands and their flags, which
surfaces this BUILD can generate, the targets the installed compiler has, the
skills it can install, and a configuration that works. It reads the profile
registry and the target table rather than a hand-kept list, so it cannot claim a
surface `apply` would refuse -- a test asserts that, and that the example it
prints plans cleanly.

Every command takes `--json`, including the failures: a `--json` run that
answered prose on error would leave an agent parsing sentences. Exit status is 0
worked, 1 a problem with the project, 2 a problem with the command line.

### 20.11 What is left

The server surface. Enabling it is an error that names the milestone; the wizard
shows it, greyed, with the same note.

**The server surface is blocked on a release, not on design.** Ranger's
`@(HttpServer)` annotation with `@(GET "/path")` methods now works on es6 as well
as Go -- that was Ranger ISSUES.md #93, fixed in this work: the es6 template
emitted `server.start(port)`, a call to a method nothing generated, so every
JavaScript HTTP server compiled cleanly and died on its first statement. The fix
is a new writer class, so it cannot be hand-patched into the published
`dist/rgrc.js`; a generated project uses the npm compiler, so the server profile
has to wait for `npm run build:dist` and a release.

The starter still does not document its own public API with `doc { … }` blocks,
though a generated project's seed does and its `docs:check` enforces it.
Publishing to npm (M12) is not done.
