#!/usr/bin/env bash
# test-checks.sh TMP -- FX-1/FX-2 tests in a throwaway clone under TMP with an
# isolated HOME and a fake dotprofile holding deploy/SENTINEL:
#   A. original check-pre-commit.sh --fix (shared/ change staged): does it touch the dotprofile / stage deploy/?
#   B. fixed check-pre-commit.sh --fix: step 3 WARN, sentinel intact, nothing in deploy/ staged
#   C. fixed check-post-push.sh: step 7 PASS on a clean tree, FAIL after a deploy/ edit, sentinel intact
#   D. fixed githook: reminder only, sentinel intact, nothing staged
set -euo pipefail
tmp="$1"
c="$tmp/clone"; h="$tmp/home"; dot="$tmp/dot"
rm -rf "$c" "$h" "$dot"
git clone -q /Users/new-jose/repos/aitools "$c"
git -C "$c" config user.name Jose
git -C "$c" config user.email jose@nobul.tech
mkdir -p "$h/.aitools" "$dot/deploy" "$dot/claude"
git -C "$dot" init -q
printf 'keep me\n' > "$dot/deploy/SENTINEL"
printf '{"version":2,"profiles":{}}\n' > "$dot/profile.json"
git -C "$dot" add -A
git -C "$dot" -c user.name=t -c user.email=t@t commit -q -m init
printf '{"reposPath":"%s","repoPath":"%s","userRepoPath":"%s"}\n' "$tmp" "$c" "$dot" > "$h/.aitools/config.json"
export HOME="$h" AITOOLS_LOG_DIR="$tmp/logs"
unset AITOOLS_USER_REPO_PATH AITOOLS_PROFILE_FILE AITOOLS_MACHINE_ALIAS || true

sentinel() { if [ -f "$dot/deploy/SENTINEL" ]; then echo "sentinel: intact"; else echo "sentinel: GONE (dotprofile deploy/ rebuilt)"; fi; }

printf '\n# test\n' >> "$c/shared/rules/scratch.md"
git -C "$c" add shared/rules/scratch.md

echo "== A original pre-commit --fix"
rc=0; (cd "$c" && bash scripts/check-pre-commit.sh --fix) > "$tmp/A.txt" 2>&1 || rc=$?
echo "rc=$rc"; grep -E 'Build freshness|Deploy drift' "$tmp/A.txt" || echo "(no step 3/10 line: checklist aborted?)"
sentinel
git -C "$c" diff --cached --name-only -- deploy/ | sed -n '1,3p'
git -C "$c" reset -q -- deploy/
printf 'keep me\n' > "$dot/deploy/SENTINEL"

for f in check-pre-commit.sh check-pre-commit.ps1; do cp "$tmp/pc/out-origin_main/scripts/$f" "$c/scripts/$f"; done
for f in check-post-push.sh check-post-push.ps1; do cp "$tmp/pp/out-origin_main/scripts/$f" "$c/scripts/$f"; done
cp "$tmp/gh/out-origin_main/scripts/githooks/pre-commit" "$c/scripts/githooks/pre-commit"
cp "$tmp/gh/out-origin_main/scripts/init-hh-hooks.sh" "$c/scripts/init-hh-hooks.sh"

echo "== B fixed pre-commit --fix"
rc=0; (cd "$c" && bash scripts/check-pre-commit.sh --fix) > "$tmp/B.txt" 2>&1 || rc=$?
echo "rc=$rc"; grep -E 'Build freshness|Deploy drift' "$tmp/B.txt" || echo "(no step 3/10 line)"
sentinel
echo "staged deploy/: $(git -C "$c" diff --cached --name-only -- deploy/ | wc -l | tr -d ' ')"

echo "== C fixed post-push (clean deploy/)"
rc=0; (cd "$c" && bash scripts/check-post-push.sh) > "$tmp/C1.txt" 2>&1 || rc=$?
echo "rc=$rc"; grep -E 'Frozen deploy|drift audit' "$tmp/C1.txt" || echo "(no step 7 line)"
sentinel
first=$(git -C "$c" ls-files deploy | sed -n '1p')
printf '# edit\n' >> "$c/$first"
echo "== C fixed post-push (deploy/ edited: $first)"
rc=0; (cd "$c" && bash scripts/check-post-push.sh) > "$tmp/C2.txt" 2>&1 || rc=$?
echo "rc=$rc"; grep -E 'Frozen deploy|drift audit' "$tmp/C2.txt" || echo "(no step 7 line)"
echo "edit kept (no auto-reset): $(grep -c '# edit' "$c/$first")"
git -C "$c" checkout -q -- deploy/
sentinel

echo "== D fixed githook"
rc=0; (cd "$c" && bash scripts/githooks/pre-commit) > "$tmp/D.txt" 2>&1 || rc=$?
echo "rc=$rc"; sed -n '1,3p' "$tmp/D.txt"
sentinel
echo "staged deploy/: $(git -C "$c" diff --cached --name-only -- deploy/ | wc -l | tr -d ' ')"
