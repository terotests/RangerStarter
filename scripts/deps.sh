#!/usr/bin/env bash
#
# deps.sh — fetch what ranger.json names, and FAIL when the fetch fails.
#
# `rgrc install` had the same habit as the compiler: through 3.5.1 it prints
# `[FAIL]` and exits 0. In CI that means a `-frozen` check that cannot cover the
# lock still reports a green build. Later compilers exit non-zero; the log is
# read here either way, as it is in scripts/rgr.
#
#   scripts/deps.sh              fetch into the package cache, write ranger.lock
#   scripts/deps.sh -vendor      also write vendor/ranger/<name>
#   scripts/deps.sh -frozen      CI: fail rather than fetch what the lock misses
#
# SPDX-License-Identifier: MIT
set -u

if [ ! -x node_modules/.bin/rgrc ]; then
  echo "deps: node_modules/.bin/rgrc is missing — run 'npm install' first" >&2
  exit 1
fi

log=$(node_modules/.bin/rgrc install "$@" 2>&1)
status=$?
printf '%s\n' "$log"

if [ $status -ne 0 ] || printf '%s' "$log" | grep -q "\[FAIL\]"; then
  echo "deps: the dependency fetch failed" >&2
  exit 1
fi
