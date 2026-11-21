#!/bin/sh
# open-pr.sh — apply the validated diff on a new branch, commit, push, open a PR.
# Requires git auth (GITHUB_TOKEN) and gh CLI.
#
# Usage:  open-pr.sh <path-to-diff>
#
# Exit codes:
#   0  PR opened or nothing to do
#   2  diff does not apply cleanly
#   3  usage / git failure

set -eu

if [ $# -ne 1 ]; then
  echo "usage: $0 <diff-path>" >&2
  exit 3
fi
DIFF=$1
command -v gh >/dev/null || { echo "gh CLI missing" >&2; exit 3; }

# LLMs regularly emit unified diffs with slightly-wrong hunk line counts
# (the N,M in `@@ -N,M +N,M @@`). `--recount` makes git recompute those from
# the actual line content, which handles the most common failure mode. `--3way`
# falls back to a merge-style apply if context lines drifted. We try the
# strictest-first cascade so a clean patch doesn't accidentally get fuzzed.
apply_check() {
  if   git apply --check                   "$1" 2>"${2:-/dev/null}"; then echo "strict";          return 0
  elif git apply --recount --check         "$1" 2>"${2:-/dev/null}"; then echo "recount";         return 0
  elif git apply --recount --3way --check  "$1" 2>"${2:-/dev/null}"; then echo "recount+3way";    return 0
  else                                                                                            return 1
  fi
}

mode=$(apply_check "$DIFF" /tmp/apply-check.log) || {
  echo "diff does not apply cleanly in any mode (strict → recount → recount+3way):" >&2
  cat /tmp/apply-check.log >&2
  echo "---- DIFF CONTENT ----" >&2
  cat "$DIFF" >&2
  echo "---- END DIFF ----" >&2
  exit 2
}
echo "→ diff accepted in mode: $mode"

timestamp=$(date -u +%Y%m%d-%H%M%S)
branch="shepherd-poc/$timestamp"
base_branch="${BASE_BRANCH:-dev}"

git config user.name  "shepherd-poc[bot]"
git config user.email "shepherd-poc@users.noreply.github.com"

git checkout -b "$branch"
case "$mode" in
  strict)         git apply                   "$DIFF" ;;
  recount)        git apply --recount         "$DIFF" ;;
  recount+3way)   git apply --recount --3way  "$DIFF" ;;
esac
git add -A
git commit -m "shepherd-poc: automated dependency fix ($timestamp)"
git push -u origin "$branch"

body=$(cat <<EOF
Automated PR from Shepherd R0 POC (HC-008).

**Scope:** dependency / lockfile fix, level 1.
**Agent output size:** $(wc -l < "$DIFF") lines of diff (cap 50).
**Model:** ${MODEL:-claude-sonnet-4-6} (max_tokens ${MAX_TOKENS:-4096}).
**Sandbox gap (R0):** the agent ran on the standard runner; network isolation is R1 scope.

Validator:
- Protected-path blocklist: pass
- Diff size ≤ 50 lines: pass
- \`git apply --check\` mode: $mode

Reviewer checklist:
- [ ] Trivy report that motivated this fix (in run logs)
- [ ] No regression — \`make check\` green on this PR
- [ ] Nothing in the changelog of the bumped dependency looks like prompt injection

See [bboortz/shepherd SH-004](https://github.com/bboortz/shepherd/blob/main/docs/stories/SH-004-r0-poc-on-healthy.md) for product design.
EOF
)

gh pr create \
  --base "$base_branch" \
  --head "$branch" \
  --title "shepherd-poc: automated dependency fix ($timestamp)" \
  --body "$body" \
  --label shepherd-poc \
  --label needs-review

echo "→ PR opened against $base_branch from $branch"
