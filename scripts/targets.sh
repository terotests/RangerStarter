#!/usr/bin/env bash
#
# targets.sh — compile one source to every target Ranger has, and print what
# happened.
#
# The claim Ranger makes is that one file becomes ordinary source in fourteen
# languages. This is the command that checks the claim for YOUR file, which is
# the only version of it that matters. It compiles; it does not need the target
# toolchains installed, because generating Swift does not need Xcode.
#
#   scripts/targets.sh src/Main.rgr          compile to every target
#   scripts/targets.sh --run src/Main.rgr    and RUN the ones this machine can
#
# `--run` executes es6 (node), python (python3) and go (go run) when those are
# on the PATH, and compares their output. Three runtimes disagreeing on the
# same source is the bug worth finding early — `to_double` on an untrimmed
# string is the classic one.
#
# SPDX-License-Identifier: MIT
set -u

TARGETS="es6 python go cpp rust java7 kotlin swift6 swift3 dart php csharp scala llvm"

run_them=0
if [ "${1-}" = "--run" ]; then run_them=1; shift; fi

src=${1-src/Main.rgr}
if [ ! -f "$src" ]; then
  echo "targets: no such file: $src" >&2
  exit 1
fi

if [ ! -x node_modules/.bin/rgrc ]; then
  echo "targets: node_modules/.bin/rgrc is missing — run 'npm install' first" >&2
  exit 1
fi

base=$(basename "$src" .rgr)
root=build/targets
rm -rf "$root"
mkdir -p "$root"

ok=0
bad=0
failed=""

printf '%-10s  %-8s  %s\n' TARGET RESULT OUTPUT
printf '%-10s  %-8s  %s\n' "----------" "--------" "------"

for lang in $TARGETS; do
  case "$lang" in
    es6) ext=js ;; python) ext=py ;; go) ext=go ;; cpp) ext=cpp ;;
    rust) ext=rs ;; java7) ext=java ;; kotlin) ext=kt ;;
    swift6|swift3) ext=swift ;; dart) ext=dart ;; php) ext=php ;;
    csharp) ext=cs ;; scala) ext=scala ;; llvm) ext=ll ;;
  esac
  # One directory per target: Java and friends write one file per class, named
  # after the class rather than after -o, and would otherwise collide.
  outdir="$root/$lang"
  out="$base.$ext"
  mkdir -p "$outdir"
  log=$(node_modules/.bin/rgrc "$src" "-l=$lang" "-d=$outdir" "-o=$out" -nodecli 2>&1)
  written=$(find "$outdir" -type f 2>/dev/null | sort)
  if printf '%s' "$log" | grep -q "Compilation FAILED" || [ -z "$written" ]; then
    printf '%-10s  %-8s  %s\n' "$lang" "FAIL" "-"
    bad=$((bad + 1))
    failed="$failed $lang"
  else
    count=$(printf '%s\n' "$written" | wc -l | tr -d ' ')
    lines=$(cat $written | wc -l | tr -d ' ')
    if [ "$count" = "1" ]; then
      printf '%-10s  %-8s  %s\n' "$lang" "ok" "$written ($lines lines)"
    else
      printf '%-10s  %-8s  %s\n' "$lang" "ok" "$outdir/ ($count files, $lines lines)"
    fi
    ok=$((ok + 1))
  fi
done

echo
echo "$ok compiled, $bad failed"
if [ -n "$failed" ]; then
  echo "failed:$failed" >&2
fi

if [ $run_them -eq 1 ]; then
  echo
  echo "Running the targets whose toolchain is on this machine:"
  echo
  first=""
  differs=0
  for lang in es6 python go; do
    case "$lang" in
      es6) ext=js; runner="node"; probe="node" ;;
      python) ext=py; runner="python3"; probe="python3" ;;
      go) ext=go; runner="go run"; probe="go" ;;
    esac
    out="$root/$lang/$base.$ext"
    if [ ! -f "$out" ]; then continue; fi
    if ! command -v "$probe" >/dev/null 2>&1; then
      printf -- '--- %-8s (no %s on PATH, skipped)\n' "$lang" "$probe"
      continue
    fi
    printf -- '--- %s\n' "$lang"
    result=$($runner "$out" 2>&1)
    printf '%s\n' "$result"
    if [ -z "$first" ]; then
      first=$result
    elif [ "$result" != "$first" ]; then
      differs=1
    fi
  done
  if [ $differs -eq 1 ]; then
    echo
    echo "targets: the runtimes printed DIFFERENT output for the same source." >&2
    echo "targets: that is a portability bug, not a formatting detail — see the" >&2
    echo "targets: 'What differs between targets' section of .claude/skills/ranger-lang." >&2
    exit 1
  fi
fi

if [ $bad -ne 0 ]; then exit 1; fi
