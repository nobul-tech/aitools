# S3-Path32 verification: check-pre-push step 7 on macOS (issue #32)

Mission DEPLOY-PATH, S3-Path32, session commander 10cf255a-c, 2026-10-21.

## Finding: the fix is already on main

Issue #32 is still OPEN, but its fix merged on 2026-10-03 in commit
`7aacdef` ("Pre-push step 7: verify the dotprofile deploy/ against a fresh
build"). That commit is on `origin/main` (`git branch -r --contains 7aacdef`
lists `origin/main`). It never referenced #32, so the issue was never closed.
The 360aa8f3-8 handoff (G11) and its verification (`S3-Handoff-V-verification.md`
row "Issue #32 ... TRUE (OPEN)") checked the issue state, not the code.

Step 7 on `origin/main` (`c8573ed`), in `scripts/check-pre-push.sh` and
`scripts/check-pre-push.ps1`:

- Triggers on `scripts/setup-*.{sh,ps1}`, `scripts/build-deploy.*`,
  `scripts/aitools-lib.*` and `shared/`.
- Resolves `userRepoPath` from `$HOME/.aitools/config.json`
  (`resolve_config` / `ResolveConfig` in check-lib). That is the same file
  and key `build-deploy.sh` reads to set `DEPLOY_DIR="$_urp/deploy"`.
- SKIPs when `userRepoPath` is unset or has no `.git`.
- Copies the dotprofile's committed tree (`git archive HEAD`) into a temp dir,
  writes a temp `config.json` (repoPath = this checkout, userRepoPath = the
  temp copy), runs `build-deploy.sh` under `HOME=<temp>`, and compares the
  rebuilt `deploy/` with the committed one. PASS when they match. FAIL names
  the stale files. FAIL when the rebuild fails.
- Never reads or writes `aitools/deploy/`.
- Never builds into the real dotprofile. The rebuild targets the temp copy
  under a temp HOME. This is #86-safe today. X-B2 must keep it safe once M3
  adds `AITOOLS_USER_REPO_PATH`.

`7aacdef` was tested on Linux only ("(tested: Linux)" in its message). This
record adds macOS coverage for both scripts.

## Environment

- macOS 27.0.1 (26A434), node v26.3.1, pwsh at `/opt/homebrew/bin/pwsh`
  (version unknown: a direct pwsh call was blocked, see below).
- Worktree `/Users/new-jose/repos/aitools/.claude/worktrees/wf_b4d5e039-e6e-3`,
  base `origin/main` = `c8573ed`.
- Run 2026-10-21T22:57:05Z to 22:58:01Z.

## Method

The harness is a scratch script (gitignored),
`.aitools/scratch/S3-Path32/verify-step7.sh`, reproduced below. It:

1. Builds a fake dotprofile (git repo with `claude/rules/test-rule.md` and a v2
   `profile.json`). It runs `build-deploy.sh` from `origin/main` into it under an
   isolated HOME, then commits the 42 generated `deploy/` files.
2. Creates a throwaway branch `verify/s3-path32-step7` from `origin/main`. It
   commits one comment line appended to `scripts/setup-pandoc.sh` and `.ps1`,
   which are copied as-is into `deploy/`. That gives step 7 a deploy-relevant push.
3. Makes a copy of `check-pre-push.ps1` with the OS guard removed
   (`scripts/s3path32-check-pre-push.ps1`, deleted afterwards). This is the same
   method `7aacdef` used.
4. Runs the whole of `check-pre-push.sh` and the PS1 copy, each with `HOME`
   set to a fresh isolated dir, for 5 cases.
5. Deletes the PS1 copy and the throwaway branch, then fingerprints the real
   dotprofile deploy/ again.

Every HOME, config and dotprofile is under
`.aitools/scratch/S3-Path32/run/`. Raw outputs are in `.../out/`.

## Results (step 7 line plus summary, verbatim)

| Case | Setup | bash | PS1 |
|------|-------|------|-----|
| 1 no config | `HOME` empty | `[SKIP] userRepoPath not configured -- dotprofile deploy/ not verified`, exit 0 | same line, exit 0 |
| 2 not a repo | userRepoPath = dir with no `.git` | `[SKIP] userRepoPath not configured -- dotprofile deploy/ not verified`, exit 0 | same, exit 0 |
| 3 stale | fake deploy/ built from origin/main, branch changed setup-pandoc | `[FAIL] dotprofile deploy/ is stale (setup-pandoc.ps1 setup-pandoc.sh) -- run build-deploy.sh and commit in <fake>`, exit 1 | same line, exit 1 |
| 4 fresh | fake deploy/ rebuilt from branch and committed | `[PASS] dotprofile deploy/ matches a fresh build`, exit 0 | same, exit 0 |
| 5 extra file | committed `deploy/stray-file.txt` | `[FAIL] dotprofile deploy/ is stale (stray-file.txt) -- ...`, exit 1 | same, exit 1 |

Summaries: case 1 `5 PASS, 2 SKIP, 3 WARN, 0 FAIL`; case 2 `5 PASS, 1 SKIP,
4 WARN, 0 FAIL`; cases 3 and 5 `6 PASS, 0 SKIP, 3 WARN, 1 FAIL`; case 4
`7 PASS, 0 SKIP, 3 WARN, 0 FAIL`. bash and PS1 gave identical counts in every case.

Real dotprofile `/Users/new-jose/repos/aitools-nobul-jose`: the `deploy/`
content hash was `31212e5d56de` before and after the run. Its HEAD moved from
`31474f3` to `0b0ca4f` during the run. That commit is "delegation.md: element 2
requires reading all project and user rules" (author Jose,
2026-10-21T15:57:11-07:00), and it touches only `claude/rules/delegation.md`.
Another session made it. The harness never writes to that repo, so its final
equality check (HEAD + hash) reported a false "changed".

## Not covered

- The FAIL path for a failed rebuild (`rebuild into a dotprofile copy failed`).
  No input made `build-deploy.sh` exit non-zero without code changes.
- bash: `node not found` WARN. PS1: `Git Bash not found` WARN.
- PS1 on Windows (Git Bash lookup, `$env:HOME` handling). This machine is macOS.
- `bash -n` on `check-pre-push.sh` passed. The standalone pwsh parser check was
  blocked (see below). The unmodified PS1 still parsed and ran to completion
  under pwsh in all 5 cases.

## Observations (not fixed: out of scope, or another mission's)

1. Step 10 (user repo push), both scripts: when `userRepoPath` is not a git repo,
   it tests only `-d` / `Test-Path`. `git -C` then walks up to the enclosing
   repo and reports that repo's commits. In case 2 it printed "1 unpushed
   commit(s) in user repo", which was the aitools throwaway commit.
2. pre-commit step 3 `--fix` (`check-pre-commit.sh`) runs `build-deploy.sh`
   under the real HOME (it rebuilds the real dotprofile deploy/, #86) and then
   runs `git add deploy/` in aitools, the frozen path. Issue #32 named it as
   "may also be affected". This mission did not change it.
3. Parity gap, latent: bash compares recursively (`diff -rq`), but PS1 compares
   only top-level files (`Get-ChildItem -File`). deploy/ is flat today (no
   subdirectories in the fake or the real deploy/), so the results match.
4. X-B2 (M3) still has to change this step: set `AITOOLS_USER_REPO_PATH`
   explicitly for the rebuild, unset `AITOOLS_PROFILE_FILE` /
   `AITOOLS_MACHINE_ALIAS`, and add `aitools-profile.js` to the trigger regex
   (S4-Review-report.md batch 7). None of those variables exist on main yet
   (`grep -rn AITOOLS_USER_REPO_PATH scripts` returns nothing).

## Blocked calls

- `/opt/homebrew/bin/pwsh -NoProfile -Command '...ParseFile...'` was blocked by
  standing-order-guard: "USO: Simple Bash commands only --: Don't use ';' to
  chain commands."
- `pwsh -NoProfile -File .aitools/scratch/S3-Path32/parse-ps1.ps1 -Path ...` and
  `bash --version` were blocked by worktree isolation: "This agent is isolated in
  the worktree ..., but this command runs pwsh in a plain command; what it reads
  or is handed as shell text cannot be shown not to run git. Refusing to run it".
  Earlier `bash` calls in the same session were allowed, including the harness
  run.

## Harness (verbatim)

```bash
#!/usr/bin/env bash
# S3-Path32 scratch harness: exercise check-pre-push step 7 (bash + PS1) on macOS
# under isolated HOMEs and a fake dotprofile. Throwaway; never touches the real HOME
# or the real dotprofile. Usage: bash verify-step7.sh
set -euo pipefail

WT=/Users/new-jose/repos/aitools/.claude/worktrees/wf_b4d5e039-e6e-3
S="$WT/.aitools/scratch/S3-Path32"
R="$S/run"
OUT="$S/out"
PWSH=/opt/homebrew/bin/pwsh
VBR=verify/s3-path32-step7
PS1COPY="$WT/scripts/s3path32-check-pre-push.ps1"

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] [s3-path32-verify] [info] %s\n' "$(ts)" "$*"; }
cleanup() {
    rm -f "$PS1COPY"
    if [ "$(git -C "$WT" rev-parse --abbrev-ref HEAD)" = "$VBR" ]; then
        git -C "$WT" switch -q "$orig_branch"
        git -C "$WT" branch -q -D "$VBR"
    fi
}
die() { printf '[%s] [s3-path32-verify] [error] %s\n' "$(ts)" "$*" >&2; cleanup; exit 1; }
orig_branch=$(git -C "$WT" rev-parse --abbrev-ref HEAD)

rm -rf "$R" "$OUT"
mkdir -p "$R" "$OUT"
cd "$WT"

# Real dotprofile fingerprint (read-only) so we can prove it was not touched.
REAL_URP=$(node -e 'try{const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(c.userRepoPath)console.log(c.userRepoPath)}catch(e){console.error("real config unreadable: "+e.message)}' "/Users/new-jose/.aitools/config.json")
real_fp() {
    if [ -n "$REAL_URP" ] && [ -d "$REAL_URP/deploy" ]; then
        printf 'HEAD=%s deploy-sha=%s\n' "$(git -C "$REAL_URP" rev-parse HEAD)" "$(find "$REAL_URP/deploy" -type f -print0 | sort -z | xargs -0 shasum | shasum | cut -c1-12)"
    else
        echo "no real dotprofile deploy/ found"
    fi
}
REAL_BEFORE=$(real_fp)
log "real dotprofile ($REAL_URP) before: $REAL_BEFORE"

git switch -q -c "$VBR" origin/main

# --- Fake dotprofile F, deploy/ built from origin/main ---
F="$R/fake-dotprofile"
mkdir -p "$F/claude/rules"
printf '# test rule\n' > "$F/claude/rules/test-rule.md"
printf '{"version":2,"identity":{"git":{"name":"Test User","email":"test@example.com"}},"profiles":{"test":{"name":"Test","company":"TestCo"}}}\n' > "$F/profile.json"
git -C "$F" init -q -b main
git -C "$F" add -A
git -C "$F" -c user.name=t -c user.email=t@example.com commit -q -m "fake dotprofile"

mkconfig() { # $1=home dir, $2=userRepoPath
    mkdir -p "$1/.aitools"
    printf '{"repoPath":"%s","userRepoPath":"%s","machineAlias":"test"}\n' "$WT" "$2" > "$1/.aitools/config.json"
}
mkconfig "$R/h-build" "$F"
HOME="$R/h-build" bash "$WT/scripts/build-deploy.sh" > "$OUT/build-main.log" 2>&1 || die "build from origin/main failed (see $OUT/build-main.log)"
git -C "$F" add -A
git -C "$F" -c user.name=t -c user.email=t@example.com commit -q -m "deploy from origin/main"
log "fake dotprofile deploy/ files: $(find "$F/deploy" -type f | wc -l | tr -d ' ')"

# --- Throwaway commit with a deploy-relevant change ---
printf '# s3-path32 verification marker\n' >> scripts/setup-pandoc.sh
printf '# s3-path32 verification marker\n' >> scripts/setup-pandoc.ps1
git add scripts/setup-pandoc.sh scripts/setup-pandoc.ps1
git -c user.name=t -c user.email=t@example.com commit -q -m "verification: touch setup-pandoc"

# PS1 copy with the OS guard removed (it exits on non-Windows).
perl -0pe 's/# OS guard: use \.sh on macOS\/Linux\r?\n.*?\r?\n}\r?\n//s' scripts/check-pre-push.ps1 > "$PS1COPY"
if grep -q 'This script is for Windows' "$PS1COPY"; then die "guard strip failed"; fi

run_case() { # $1=name, $2=home
    local rc
    rc=0; HOME="$2" bash "$WT/scripts/check-pre-push.sh" > "$OUT/$1-sh.log" 2>&1 || rc=$?
    log "case $1 bash exit=$rc"
    printf 'exit=%s\n' "$rc" >> "$OUT/$1-sh.log"
    rc=0; HOME="$2" "$PWSH" -NoProfile -File "$PS1COPY" > "$OUT/$1-ps1.log" 2>&1 || rc=$?
    log "case $1 ps1 exit=$rc"
    printf 'exit=%s\n' "$rc" >> "$OUT/$1-ps1.log"
}

# Case 1: no config -> SKIP
mkdir -p "$R/h-empty"
run_case 1-noconfig "$R/h-empty"

# Case 2: userRepoPath points at a dir that is not a git repo -> SKIP
mkdir -p "$R/not-a-repo"
mkconfig "$R/h-norepo" "$R/not-a-repo"
run_case 2-notrepo "$R/h-norepo"

# Case 3: fake dotprofile deploy/ built from origin/main, branch changed setup-pandoc -> FAIL
mkconfig "$R/h-fake" "$F"
run_case 3-stale "$R/h-fake"

# Case 4: rebuild fake dotprofile deploy/ from this branch, commit -> PASS
HOME="$R/h-build" bash "$WT/scripts/build-deploy.sh" > "$OUT/build-branch.log" 2>&1 || die "build from branch failed"
git -C "$F" add -A
git -C "$F" -c user.name=t -c user.email=t@example.com commit -q -m "deploy from branch"
run_case 4-fresh "$R/h-fake"

# Case 5: committed deploy/ has an extra file a fresh build would not produce -> FAIL naming it
printf 'stray\n' > "$F/deploy/stray-file.txt"
git -C "$F" add -A
git -C "$F" -c user.name=t -c user.email=t@example.com commit -q -m "stray file"
run_case 5-extra "$R/h-fake"

# Cleanup: PS1 copy, throwaway branch.
cleanup

REAL_AFTER=$(real_fp)
log "real dotprofile after: $REAL_AFTER"
if [ "$REAL_BEFORE" != "$REAL_AFTER" ]; then die "real dotprofile changed"; fi
log "real dotprofile unchanged"
```

The first run stopped at "guard strip failed": the PS1 file has CRLF line
endings and the regex expected LF. The harness was fixed (`\r?\n`) and cleanup
was added to `die`. The worktree was restored by hand (PS1 copy removed,
branch switched back, `verify/s3-path32-step7` deleted at `5ce975d`), and the
run above is the second one.
