#!/usr/bin/env bash
#
# package.sh — emit the packaging each target ecosystem expects, not just the
# source file.
#
# `rgr build` writes Main.kt. That is a file, not something Gradle can resolve.
# The compiler also knows how to write the manifest beside it — package.json
# for npm, build.gradle.kts for Gradle, Package.swift for SwiftPM,
# pyproject.toml for pip, a .csproj for NuGet, pubspec.yaml for pub — and this
# is the command that asks for them. The metadata comes from package.json, so
# there is one place to change the version.
#
#   scripts/package.sh                 what can be packaged
#   scripts/package.sh npm             build/pkg/npm
#   scripts/package.sh python swift6   several at once
#   scripts/package.sh all
#
# What each ecosystem then does with the directory — `npm publish`, `swift
# build`, `dotnet pack` — is its own business and needs its own toolchain.
#
# SPDX-License-Identifier: MIT
set -u

SRC=${RANGER_ENTRY:-src/Main.rgr}
OUT=build/pkg

usage() {
  cat <<'USAGE'
usage: scripts/package.sh <ecosystem…>

  npm       package.json + Main.js          (JavaScript, CommonJS modules)
  python    pyproject.toml + Main.py        (pip)
  csharp    .csproj + docfx.json + Main.cs  (NuGet)
  kotlin    build.gradle.kts + Main.kt      (Gradle, Dokka)
  swift6    Package.swift + .docc + Main.swift (SwiftPM)
  dart      pubspec.yaml + Main.dart        (pub)
  flutter   pubspec.yaml for Flutter + Main.dart
  all       every one of the above

Metadata is read from package.json. Output goes to build/pkg/<ecosystem>/.
USAGE
}

if [ $# -eq 0 ] || [ "${1-}" = "-h" ] || [ "${1-}" = "--help" ]; then
  usage; exit 0
fi

if [ ! -x node_modules/.bin/rgrc ]; then
  echo "package: node_modules/.bin/rgrc is missing — run 'npm install' first" >&2
  exit 1
fi
if [ ! -f "$SRC" ]; then
  echo "package: no such entry point: $SRC (set RANGER_ENTRY to change it)" >&2
  exit 1
fi

meta=$(node -e '
const p = require("./package.json");
const out = [
  p.name || "ranger-app",
  p.version || "0.1.0",
  p.description || "A Ranger program",
  typeof p.author === "string" ? p.author : (p.author && p.author.name) || "unknown",
  p.license || "MIT",
];
process.stdout.write(out.join("\n"));
') || exit 1

name=$(printf '%s' "$meta" | sed -n 1p)
version=$(printf '%s' "$meta" | sed -n 2p)
description=$(printf '%s' "$meta" | sed -n 3p)
author=$(printf '%s' "$meta" | sed -n 4p)
license=$(printf '%s' "$meta" | sed -n 5p)

base=$(basename "$SRC" .rgr)

want=("$@")
if [ "${1}" = "all" ]; then
  want=(npm python csharp kotlin swift6 dart)
fi

fail=0
for eco in "${want[@]}"; do
  case "$eco" in
    npm)     lang=es6;    ext=js;    extra=(-npm -nodemodule) ;;
    python)  lang=python; ext=py;    extra=(-apipackage) ;;
    csharp)  lang=csharp; ext=cs;    extra=(-apipackage) ;;
    kotlin)  lang=kotlin; ext=kt;    extra=(-apipackage) ;;
    swift6)  lang=swift6; ext=swift; extra=(-apipackage) ;;
    dart)    lang=dart;   ext=dart;  extra=(-pubspec) ;;
    flutter) lang=dart;   ext=dart;  extra=(-pubspec -flutter) ;;
    *) echo "package: unknown ecosystem '$eco'" >&2; usage >&2; exit 1 ;;
  esac

  dir="$OUT/$eco"
  rm -rf "$dir"
  mkdir -p "$dir"

  log=$(node_modules/.bin/rgrc "$SRC" "-l=$lang" "-d=$dir" "-o=$base.$ext" \
      "${extra[@]}" \
      "-name=$name" "-version=$version" "-description=$description" \
      "-author=$author" "-license=$license" 2>&1)

  if printf '%s' "$log" | grep -q "Compilation FAILED"; then
    printf '%s\n' "$log" | grep -A3 "\[FAIL\]" | head -30
    echo "package: $eco FAILED" >&2
    fail=1
    continue
  fi
  echo "$eco -> $dir"
  ls "$dir" | sed 's/^/    /'
done

exit $fail
