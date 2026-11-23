#!/bin/sh
# test_HRC_001_hook_tiers.sh — hook-commit + hook-push fleet-tier wrappers (SH-042)
# Fleet story: shepherd/docs/stories/SH-042-hook-tiers.md
# Fleet plan:  shepherd/docs/plan/SH-042-hook-tiers-plan.md
# CAPs:        dev-cycle.tier.hook-commit, dev-cycle.tier.hook-push
#
# HRC mapping (per v3 Layer 3):
#   COMMIT_STEPS = prettier-check        (new target; invokes `npx prettier . --check`)
#   PUSH_STEPS   = check                 (alias for `npm run check` = tsc + eslint)

set -u
pass=0; fail=0

assert_rc() { want=$1; shift; "$@" >/dev/null 2>&1; rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL want=$want got=$rc: $*"; fi; }

assert_grep() { needle=$1; shift
  if "$@" 2>&1 | grep -Fq -- "$needle"; then pass=$((pass + 1))
  else fail=$((fail + 1)); echo "FAIL output missing '$needle' from $*"; fi; }

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
cd "$repo" || exit 1

# ----- Scenario 1 — hook-commit + hook-push declared .PHONY ---------------
# Line-continuation tolerant: fold logical .PHONY: line to one line then grep.
phony=$(awk '/^\.PHONY:/{flag=1} flag{printf "%s ", $0; if ($0 !~ /\\$/) {print ""; flag=0}}' Makefile)
if printf '%s' "$phony" | grep -Fq "hook-commit"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL .PHONY missing hook-commit"; fi
if printf '%s' "$phony" | grep -Fq "hook-push";   then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL .PHONY missing hook-push"; fi
if printf '%s' "$phony" | grep -Fq "prettier-check"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL .PHONY missing prettier-check"; fi

# ----- Scenario 2 — dry-run resolves without executing recipes ------------
assert_rc 0 make -n hook-commit
assert_rc 0 make -n hook-push
assert_rc 0 make -n prettier-check

# ----- Scenario 3 — hook-commit dry-run invokes the commit steps ----------
# HRC COMMIT_STEPS = prettier-check → expands to `npx prettier . --check`.
assert_grep "npx prettier"   make -n hook-commit
assert_grep "--check"        make -n hook-commit

# ----- Scenario 4 — hook-push dry-run invokes the push steps --------------
# HRC PUSH_STEPS = check → expands to `npm run check`.
assert_grep "npm run check"  make -n hook-push

# ---------------------------------------------------------------------------
echo "pass=$pass fail=$fail"
[ "$fail" = 0 ]
