# The wizard

```bash
npm install
npx ranger-starter configure
```

Eight screens, and at the end a `ranger.project.json` and the project generated
from it.

**The wizard is a frontend.** It produces a configuration and nothing else — the
same file an agent writes by hand — so there is one generator and no second path
through it. If you would rather not answer questions:

```bash
ranger-starter init --name northwind --surfaces cli --targets es6,go --docs
ranger-starter plan       # what would change; writes nothing
ranger-starter apply
```

Every picture below is **generated from the wizard**, by driving the real program
inside a pty and screenshotting what it drew. The key scripts that produce them
are asserted in `src/starter/StarterTest.rgr`, so a picture that goes stale is a
test that fails. `npm run wizard:shots` rebuilds them.

---

## 1 — The name

![the name screen](wizard/00-open.png)

Lowercase letters, digits, `-` and `_`. It becomes the npm package name, the
Ranger class name and the default Android package and iOS bundle id, so the
wizard checks it against the same rule the planner validates with — a name the
wizard accepts cannot be a name the generator then rejects.

![typing a name](wizard/01-name-typed.png)

---

## 2 — Application or library

![the kind screen](wizard/02-kind.png)

This is **not** the same question as where it runs, and that separation is the
one design decision everything else follows from. A library can have a command
line surface; an application can have several surfaces at once. They are
independent dimensions, and the configuration stores them that way.

---

## 3 — Where it runs

![the surfaces screen](wizard/03-surfaces.png)

Pick as many as apply. Two of the seven are not built yet — and they are
**shown**, with the milestone that will bring them, rather than hidden. Hiding
them would hide the plan; offering them as selectable would let you build a
configuration that fails to apply. So they are visible and refuse to be ticked:

![an unavailable surface says why](wizard/04-unavailable.png)

---

## 4 — Which languages

![the targets screen](wizard/05-targets.png)

One source, compiled to each of these. The list is **the compiler's**, not the
wizard's: `ranger-starter` asks `rgrc -targets -json` and falls back to a bundled
table when the installed compiler is too old to answer — which today it always
is, so this is the bundled list. The hints come from the same table, so "npm
packaging" and "runs here" cannot drift from what the generated scripts do.

`TypeScript *` carries a star because it is not a `-l=` value: it compiles as
`-l=es6 -typescript`, and the generated script says so.

![two targets picked](wizard/06-targets-picked.png)

A surface with exactly one possible target — Android is Kotlin, iOS is Swift —
opens with it already ticked, so the question can be confirmed without reading
it.

---

## 4b — Which devices

Only Android and iOS ask this, because they are the only surfaces where the
answer is not derivable from anything else.

![the android devices screen](wizard/24-android-devices.png)

**These are not separate builds.** They are one app, and what they change is the
manifest, the minimum version and what the store says the app runs on:

| | |
| --- | --- |
| **Phone** | `minSdk 24`, the ordinary launcher |
| **Tablet** | the same build; a larger layout is yours to write |
| **TV** | adds `LEANBACK_LAUNCHER` and `androidx.tv:tv-material`. Without the category the app does not appear on a TV at all |
| **Wear** | forces `minSdk 30` — Wear OS 3 is API 30 and a lower minimum will not install — and adds the watch's own Compose material set |

![phone and tablet](wizard/25-android-devices-2.png)

On iOS the same question is the `UIDeviceFamily` list in `Info.plist`, which is
the only difference between "an iPhone app" and "an iPad app" once the binary
exists:

![the ios devices screen](wizard/28-ios-devices-2.png)

The two vocabularies do not overlap on purpose — Android has `phone`, iOS has
`iphone` — so one `--devices phone,tablet,iphone,ipad` on the command line is
routed to whichever surfaces know each name, and a name nobody knows is an
error rather than a silent default.

---

## 5 — Documentation

![the documentation screen](wizard/07-docs.png)

From `doc { … }` blocks in the source — the vocabulary the compiler already
parses. **Yes, and enforce it** adds `-apistrict` to `npm run docs:check`, which
makes an undocumented public declaration a build failure rather than a warning.

---

## 6 — Agents

![the agents screen](wizard/08-agents.png)

`AGENTS.md` is the generic file every coding agent reads: the exact commands, the
Ranger syntax traps, the generated-file policy, the per-surface rules. `CLAUDE.md`
stays small and points at it, and lists the skills the project installs.

Both are written **only between `<!-- ranger:start … -->` markers**. Everything
outside them is yours and is never touched, which is what makes re-running the
setup safe on a project you have been writing in.

---

## 7 — CI

![the CI screen](wizard/09-ci.png)

A workflow that runs what you run, in the order you run it: `npm install`,
`npm test`, a build per configured target, `docs:check` when documentation is on,
and `doctor` as a diagnostic step.

---

## 8 — Review

![the review screen](wizard/10-review.png)

The answers, as the configuration about to be written. `←` goes back to any of
them. A mobile surface shows its devices beside its target, because that is half
the answer — a watch build and a phone build differ only there:

![the review screen for two mobile surfaces](wizard/29-mobile-review.png)

---

## What each surface generates

| | |
| --- | --- |
| **Command line** | `src/Main.rgr`, a test that exits non-zero, `scripts/rgr.js`, and a build script per target |
| **Library** | an entry point per ecosystem, and `package:<target>` for each target with a manifest — npm, pip, NuGet, Gradle/Dokka, SwiftPM, pub |
| **Web** | `web/index.html`, `web/main.js`, a Ranger ES module compiled into `web/generated/`, and Vite |
| **Android** | `platforms/android` — a Gradle project with a Compose shell — and `src/Shared.rgr` compiled to Kotlin into the app's source set |
| **iOS** | `platforms/ios/App.swift` — a SwiftUI shell — and `scripts/ios-build.rgr`, which builds a `.app` with no `.xcodeproj` and no `xcodebuild` |

The web surface has three details worth knowing, each of which is a trap
somebody would otherwise hit once:

- `src/Web.rgr` has **no `main`**. `-esm` exports every class *and* calls `main`
  at the bottom of the emitted file, so a `main` there would run on page load.
- **`-esm` is not optional.** Without it the es6 target writes CommonJS, and the
  failure arrives as a Vite error about `require` that reads like a bundler
  problem rather than a missing compiler flag.
- The compiled module lands **inside Vite's root**. A module outside it needs
  `server.fs.allow`, and getting that wrong produces a 403 in dev that says
  nothing useful.

### The two mobile surfaces are one module

Android and iOS both default to `src/Shared.rgr`, class `Shared`, and compile
**the same file** to Kotlin and to Swift. That is the point of the language, and
two near-identical modules would be the opposite of it. The host shell on each
platform owns the lifecycle and the UI; the Ranger module owns what the app
knows, and has no `main` — the platform calls the shell and the shell calls it.

![the generated mobile project](wizard/30-mobile-generated.png)

The class is called `Shared` rather than `App` because `App` is a **SwiftUI
protocol**: a class of that name makes the host's `struct NorthwindApp: App`
resolve to the wrong thing. The host struct is named from the project for the
same reason.

Three more things worth knowing before they cost an afternoon:

- **`-ktpackage` must match the host's `package` declaration.** Both come from
  `surfaces.android.package`, so they cannot disagree — but if you edit one by
  hand, the mismatch does not fail the Ranger compile. It fails later, in
  Gradle, as an unresolved reference to a class that is right there in the
  source set.
- **iOS generates everywhere and builds only on a Mac.** `npm run ios:plan`
  prints the whole build — SDK, triple, device families, every command line —
  and executes nothing, on Linux and Windows too. `npm run doctor` reports the
  Xcode tools as *unavailable* rather than *missing*, because "missing" would
  send somebody looking for something they cannot install.
- **There is no `.xcodeproj` and no `xcodebuild`.** `scripts/ios-build.rgr`
  drives `xcrun`, `swiftc`, `plutil` and `codesign` through `lib/apple`, which
  ships inside `ranger-compiler` — nothing to install and nothing to declare.

---

## Driving it without the questionnaire

The wizard needs a terminal and refuses a pipe. Everything it does is available
as flags and JSON, and an agent should start with one call that answers what
this build can actually do:

```bash
npx ranger-starter describe --json
```

That gives the commands and their flags, which surfaces this build can generate
(as opposed to which ones the config file has slots for), the targets the
installed compiler has, the skills it can install, and a configuration that
works. Then:

```bash
npx ranger-starter init --name shopfront --surfaces cli,web --targets es6 --json
npx ranger-starter init --name shopfront --surfaces android,ios \
    --devices phone,tablet,iphone --json
npx ranger-starter plan --json      # the actions apply will perform
npx ranger-starter apply --json
npx ranger-starter doctor --json    # what this machine is missing
```

Every command takes `--json`, **including the failures**. Exit status is 0 for
worked, 1 for a problem with the project, 2 for a problem with the command line.

`describe --json` carries the `--devices` vocabulary for every surface that has
one, with the default that applies when the flag names none:

```json
{ "id": "android", "available": true, "defaultTarget": "kotlin",
  "devices": ["phone", "tablet", "tv", "wear"], "devicesDefault": ["phone"] }
```

So an agent never has to guess whether a tablet is `tablet` or `tablets` — a
guess is a JSON error, not a default.

---

## And then it generates

![the generated project](wizard/11-generated.png)

Twelve files, and `ranger.project.json` beside them as the source of truth.

Run it again and it will say `12 already correct` — generation is idempotent.
Turn a surface off and its files, its npm scripts and its `AGENTS.md` section go
away, while your own scripts and prose stay. Edit a generated file and the tool
notices and stops overwriting it, rather than clobbering your work.

```bash
npm run plan            # what would change; writes nothing
npm run setup           # the questions again
npm run doctor          # can this machine build what is configured?
```
