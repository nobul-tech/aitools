#!/usr/bin/env bash
# test-deploy-harness-mdm.sh -- tests for the MDM deploy-harness that
# scripts/build-deploy.sh generates into <dotprofile>/deploy/
#
# Runs build-deploy.sh under an isolated HOME whose config.json points at a
# fixture dotprofile (a git repo in a temp directory), so the real HOME and the
# real dotprofile are never touched; the sources are this repo (read only).
# Then runs the dev path (scripts/deploy-harness.sh) and the generated MDM path
# (a copy of deploy/ outside any repo, with a git on PATH that always fails)
# under two more isolated HOMEs and compares the results.
# Cases: build output and parse (bash -n, pwsh parser), extraction by body
# markers (no marker line copied, section 5b kept; a missing or duplicated
# marker fails the build and leaves deploy/ as it was), the payload data file
# (deploy-harness.payload), the size gate (a script over the Intune limit is a
# WARN with its fix hint, listed again at the end, and the build passes; a
# forced case pads the fixture dotprofile so a .sh goes over 1 MB), cursor header
# port and step 4 (MDM), no adopt target in MDM, dotprofile rules and skills
# embedded (skills manifest same as dev), first run / rerun / edit / dry
# run equivalence (trees, exec bits, summary rows, exit codes), no git needed
# at run time, --help, config.json: a fresh HOME (no bootstrap) skips the
# writer with OK "config.json" "n/a (no bootstrap)" and exit 0, the dev path
# calls the writer, --skip-config / -SkipConfig skip it (dev and MDM); a
# damaged payload (whole-file checksum), a damaged record, a missing payload
# or a truncated script (ERROR, exit 1, .sh and .ps1), conflicts (same ERROR
# rows, exit 1), build from a non-git dotprofile (pre-push step 7's
# git-archive copy) gives the same output, and the .ps1 pair on pwsh with the
# OS guards disabled in temp copies.
# Platform: macOS, Linux (needs node, perl, git; pwsh optional). Exit 1 if any
# case fails.
#
# Usage: bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 30' "$0"
    exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_ROOT="$(mktemp -d)"
# KEEP_TMP=1 keeps the temp directory (printed at the end) for debugging.
if [ "${KEEP_TMP:-}" = "1" ]; then
    trap 'printf "kept: %s\n" "$TMP_ROOT"' EXIT
else
    trap 'rm -rf "$TMP_ROOT"' EXIT
fi

PASS=0
FAIL=0
SKIP=0
OUT=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$OUT" ] && [ -f "$OUT" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$OUT" | tail -n 20
        fi
    fi
}

for t in node perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

DOT="$TMP_ROOT/dot"
mkdir -p "$DOT/claude/rules" "$DOT/claude/skills/dskill/ref"
printf 'user rule one\n' > "$DOT/claude/rules/user1.md"
printf 'user rule two\n' > "$DOT/claude/rules/user2.md"
printf 'dotprofile skill\n' > "$DOT/claude/skills/dskill/SKILL.md"
printf 'dotprofile skill ref\n' > "$DOT/claude/skills/dskill/ref/r.md"
git -C "$DOT" init -q
gitc -C "$DOT" add -A
gitc -C "$DOT" commit -q -m fixture

write_config() {  # write_config HOME_DIR
    mkdir -p "$1/.aitools"
    printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' \
        "$TMP_ROOT" "$ROOT" "$DOT" > "$1/.aitools/config.json"
}

# build NAME -- build-deploy.sh into $DOT/deploy, then copy deploy/ to $TMP_ROOT/NAME
build() {
    local hb="$TMP_ROOT/home-build-$1"
    write_config "$hb"
    OUT="$TMP_ROOT/build-$1.out"
    HOME="$hb" bash "$ROOT/scripts/build-deploy.sh" > "$OUT" 2>&1
    echo $? > "$TMP_ROOT/build-$1.rc"
    rm -rf "$TMP_ROOT/$1"
    mkdir -p "$TMP_ROOT/$1"
    if [ -d "$DOT/deploy" ]; then cp -Rp "$DOT/deploy" "$TMP_ROOT/$1/deploy"; fi
}

# Failing git for the MDM runs: the MDM path must not need git. One exception:
# the terminal review menu displays its diff with `git diff --no-index` (#81);
# without git it shows "(diff unavailable)" and the menu still works.
mkdir -p "$TMP_ROOT/fakegit"
printf '#!/bin/sh\necho "$*" >> "%s/fakegit.calls"\nexit 99\n' "$TMP_ROOT" > "$TMP_ROOT/fakegit/git"
chmod +x "$TMP_ROOT/fakegit/git"

# run SIDE NAME ARGS... -- SIDE dev|mdm, NAME = case dir; HOME = $TMP_ROOT/NAME-SIDE
run() {
    local side="$1" name="$2" h; shift 2
    h="$TMP_ROOT/$name-$side"
    [ -f "$h/.aitools/config.json" ] || write_config "$h"
    OUT="$TMP_ROOT/$name-$side.out"
    : > "$TMP_ROOT/$name-$side.summary"
    if [ "$side" = dev ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" AITOOLS_LOG_DIR="$h/logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name-$side.summary" \
            bash "$ROOT/scripts/deploy-harness.sh" "$@" < /dev/null > "$OUT" 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" PATH="$TMP_ROOT/fakegit:$PATH" AITOOLS_LOG_DIR="$h/logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name-$side.summary" \
            bash "$TMP_ROOT/$BUILD/deploy/deploy-harness.sh" "$@" < /dev/null > "$OUT" 2>&1
    fi
    echo $? > "$TMP_ROOT/$name-$side.rc"
}

rc_of() { cat "$TMP_ROOT/$1.rc"; }
same_rc() { [ "$(rc_of "$1-dev")" = "$(rc_of "$1-mdm")" ]; }
same_summary() { cmp -s "$TMP_ROOT/$1-dev.summary" "$TMP_ROOT/$1-mdm.summary"; }
row() { grep -qxF "$2" "$TMP_ROOT/$1.summary"; }
same_trees() {  # same_trees NAME -- six directories and exec bits identical
    local k a="$TMP_ROOT/$1-dev/.aitools" b="$TMP_ROOT/$1-mdm/.aitools"
    for k in reference registries hooks rules skills bin; do
        diff -r -x '*.bak.*' "$a/$k" "$b/$k" > /dev/null 2>&1 || return 1
    done
    [ "$(cd "$a" && find reference registries hooks rules skills bin -type f -perm -u+x | sort)" = \
      "$(cd "$b" && find reference registries hooks rules skills bin -type f -perm -u+x | sort)" ]
}
no_fake_git() { [ ! -s "$TMP_ROOT/fakegit.calls" ]; }
# Every recorded call is the review display's `git ... diff --no-index` (#81)
only_review_diff_git() {
    [ ! -s "$TMP_ROOT/fakegit.calls" ] || ! grep -qv -e ' diff --no-index ' "$TMP_ROOT/fakegit.calls"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
BUILD=b1
build b1
G="$TMP_ROOT/b1/deploy"
check "build: exit 0" "[ \"\$(rc_of build-b1)\" = 0 ]"
check "build: deploy-harness.sh/.ps1 and the config writer bundle generated" \
    "[ -x '$G/deploy-harness.sh' ] && [ -f '$G/deploy-harness.ps1' ] && [ -x '$G/setup-user-config.sh' ] && [ -f '$G/setup-user-config.ps1' ] && [ -f '$G/aitools-profile.sh' ] && [ -f '$G/aitools-profile.ps1' ] && [ -f '$G/aitools-json.pl' ] && [ -f '$G/aitools-json.ps1' ]"
check "MDM parse: bash -n deploy-harness.sh" "bash -n '$G/deploy-harness.sh'"
if command -v pwsh >/dev/null 2>&1; then
    printf '%s\n' '$e = $null' \
        '$null = [System.Management.Automation.Language.Parser]::ParseFile($args[0], [ref]$null, [ref]$e)' \
        'if ($e.Count -gt 0) { $e | ForEach-Object { [Console]::WriteLine($_.Message) }; exit 1 }' > "$TMP_ROOT/parse.ps1"
    check "MDM parse: pwsh parser deploy-harness.ps1" "pwsh -NoProfile -File '$TMP_ROOT/parse.ps1' '$G/deploy-harness.ps1' > /dev/null"
else
    printf 'SKIP MDM parse .ps1 (pwsh not found)\n'; SKIP=$((SKIP + 1))
fi
check "cursor (MDM): step 4 once in .sh and .ps1" \
    "[ \"\$(grep -c 'Step 4: Cursor user rules' '$G/setup-user-cursor.sh')\" = 1 ] && [ \"\$(grep -c 'Step 4: Cursor user rules' '$G/setup-user-cursor.ps1')\" = 1 ]"
check "cursor (MDM): header ported from the source (five things, rules scope)" \
    "grep -q '^# Does five things:' '$G/setup-user-cursor.sh' && grep -q '^# Does five things:' '$G/setup-user-cursor.ps1' && grep -q 'Managed: one <name>.mdc per' '$G/setup-user-cursor.sh' && grep -q 'Managed: one <name>.mdc per' '$G/setup-user-cursor.ps1' && ! grep -q 'Does three things' '$G/setup-user-cursor.sh'"
check "MDM: no adopt target (.sh and .ps1)" \
    "grep -qF '\"\$TOOL\" \"\$item\" \"\"  # MDM' '$G/deploy-harness.sh' && ! grep -qF '\"\$item\" \"\$src\"' '$G/deploy-harness.sh' && grep -qF -- '-AdoptPath \"\"  # MDM' '$G/deploy-harness.ps1' && ! grep -qF -- '-AdoptPath \$p.Src' '$G/deploy-harness.ps1'"
check "MDM: dotprofile rules embedded (payload record)" \
    "perl -ne '\$f = 1 if /^dotprofile\\/claude\\/rules\\/user1\\.md\\t0\\t\\d+\\t[0-9a-f]{64}\$/; END { exit(\$f ? 0 : 1) }' '$G/deploy-harness.payload'"
check "payload: data file beside the scripts, none inline" \
    "[ -f '$G/deploy-harness.payload' ] && ! grep -q '^mdm_unpack ' '$G/deploy-harness.sh' && ! grep -q '^Expand-MdmPayload ' '$G/deploy-harness.ps1' && grep -q '^MDM_PAYLOAD_SHA256=[0-9a-f]\{64\}$' '$G/deploy-harness.sh'"
# size_gate_warned DIR OUT -- every generated .ps1 (200000) / .sh (1000000) at or
# over its Intune limit has its WARN in the build output, twice (inline and the
# end-of-build list); one under it has none (FX-12: WARN, not a build FAIL)
# Each over-limit WARN carries its fix hint (deploy-harness: the payload; the
# others: FX-35). The end-of-build header counts them, and "ready for MDM
# deployment" is printed only when none is over. SIZE_GATE_OVER is set to the
# number of over-limit scripts found.
SIZE_GATE_OVER=0
size_gate_warned() {
    local f n max sz line hint over=0
    for f in "$1"/*.ps1 "$1"/*.sh; do
        [ -f "$f" ] || continue
        n="${f##*/}"
        case "$n" in *.ps1) max=200000 ;; *) max=1000000 ;; esac
        # a wc failure must fail the check, not read as 0 bytes (under the limit)
        sz=$(wc -c < "$f") || return 1
        sz=$((sz + 0))
        case "$n" in
            deploy-harness.*) hint="move content to deploy-harness.payload" ;;
            *)                hint="see FX-35 (inlined lib)" ;;
        esac
        line="deploy/$n is $sz bytes, over the Intune script limit ($max) -- $hint"
        if [ "$sz" -ge "$max" ]; then
            [ "$(grep -F -- '[warn]' "$2" | grep -cF -- "$line")" = 2 ] || return 1
            over=$((over + 1))
        else
            if grep -F -- "[warn] deploy/$n is " "$2" | grep -qF "over the Intune script limit"; then
                return 1
            fi
        fi
    done
    SIZE_GATE_OVER=$over
    if [ "$over" -gt 0 ]; then
        grep -qF -- "[warn] $over generated script(s) over the Intune script limit (WARN only, the build does not fail):" "$2" || return 1
        ! grep -qF 'ready for MDM deployment' "$2" || return 1
    else
        grep -qF 'Scripts are self-contained and ready for MDM deployment' "$2" || return 1
        ! grep -qF 'generated script(s) over the Intune script limit' "$2" || return 1
    fi
}
check "size gate: a generated script over its Intune limit is a WARN, not a build failure (FX-12)" \
    "[ \"\$(rc_of build-b1)\" = 0 ] && size_gate_warned '$G' '$TMP_ROOT/build-b1.out'"

# Forced over-limit case, independent of the real script sizes: a copy of the
# fixture dotprofile whose claude/CLAUDE.md template is padded by ~1.2 MB.
# build-deploy embeds that template in the generated setup-user-claude.sh (the
# fallback template), so that .sh is over 1 MB. (Dotprofile rules are no
# longer embedded there since the rules fan-out, FO-3: they reach endpoints
# through deploy-harness.) If the gate were removed or stopped measuring .sh
# files, there would be no WARN and this check fails.
DOT_BIG="$TMP_ROOT/dot-big"
cp -Rp "$DOT" "$DOT_BIG"
rm -rf "$DOT_BIG/deploy"
mkdir -p "$DOT_BIG/claude"
perl -e 'print "\n## Padding (size-gate test)\n\n"; print "x" x 99, "\n" for 1 .. 12000' >> "$DOT_BIG/claude/CLAUDE.md"
gitc -C "$DOT_BIG" add -A
gitc -C "$DOT_BIG" commit -q -m padding
HB_BIG="$TMP_ROOT/home-build-big"
mkdir -p "$HB_BIG/.aitools"
printf '{\n  "version": 3,\n  "reposPath": "%s",\n  "repoPath": "%s",\n  "userRepoPath": "%s"\n}\n' \
    "$TMP_ROOT" "$ROOT" "$DOT_BIG" > "$HB_BIG/.aitools/config.json"
OUT="$TMP_ROOT/build-big.out"
env -u AITOOLS_USER_REPO_PATH HOME="$HB_BIG" bash "$ROOT/scripts/build-deploy.sh" > "$OUT" 2>&1
echo $? > "$TMP_ROOT/build-big.rc"
big_sh_over() {
    local sz
    sz=$(wc -c < "$DOT_BIG/deploy/setup-user-claude.sh") || return 1
    [ "$((sz + 0))" -ge 1000000 ] || return 1
    size_gate_warned "$DOT_BIG/deploy" "$OUT" || return 1
    [ "$SIZE_GATE_OVER" -ge 1 ]
}
check "size gate (forced): a .sh padded over 1 MB is a WARN with the FX-35 hint, build exit 0" \
    "[ \"\$(rc_of build-big)\" = 0 ] && big_sh_over"
OUT=""
check "payload: the script's sha256 is the payload's (CRs removed)" \
    "[ \"\$(perl -MDigest::SHA=sha256_hex -0777 -ne 's/\\r//g; print sha256_hex(\$_)' '$G/deploy-harness.payload')\" = \"\$(perl -ne 'print \$1 if /^MDM_PAYLOAD_SHA256=(\\S+)/' '$G/deploy-harness.sh')\" ]"
check "markers: no marker line copied into the MDM scripts" \
    "! grep -qE '^# --- (BEGIN|END) (scope|body|config bootstrap check|dotprofile lookup) ' '$G/deploy-harness.sh' && ! grep -qE '^# --- (BEGIN|END) (scope|body|config bootstrap check|dotprofile lookup) ' '$G/deploy-harness.ps1'"
check "markers: sections 1, 3 and 5b extracted, section 2 replaced, scope in the header" \
    "( for f in '$G/deploy-harness.sh' '$G/deploy-harness.ps1'; do grep -q '^# 1\\. config.json' \"\$f\" && grep -q '^# 3\\. The six directories' \"\$f\" && grep -q '^# 5b\\. Rules manifest' \"\$f\" && grep -q '^# 2\\. (MDM) Embedded sources' \"\$f\" && ! grep -q '^# 2\\. Dotprofile' \"\$f\" && grep -q '^# Managed (' \"\$f\" || exit 1; done )"
check "markers: MDM bootstrap check replaced the dev comment" \
    "grep -qF 'SKIP_CONFIG=\"no bootstrap\"' '$G/deploy-harness.sh' && grep -qF '\$configSkip = \"no bootstrap\"' '$G/deploy-harness.ps1' && ! grep -q 'Dev path: aitools-install writes the bootstrap keys' '$G/deploy-harness.sh'"

# ---------------------------------------------------------------------------
# Equivalence: first run, rerun, edit, dry run
# ---------------------------------------------------------------------------
run dev eq
run mdm eq
check "first run: dev exit 0, MDM same exit code" "[ \"\$(rc_of eq-dev)\" = 0 ] && same_rc eq"
check "first run: same six directories and exec bits" "same_trees eq"
check "first run: same summary rows" "same_summary eq"
check "first run: config.json written by the MDM writer, same as dev" "cmp -s '$TMP_ROOT/eq-dev/.aitools/config.json' '$TMP_ROOT/eq-mdm/.aitools/config.json'"
check "first run: dotprofile rule deployed by MDM" "grep -qx 'user rule one' '$TMP_ROOT/eq-mdm/.aitools/rules/user1.md'"
check "first run: dotprofile skill embedded and deployed by MDM (nested file)" \
    "perl -ne '\$f = 1 if /^dotprofile\\/claude\\/skills\\/dskill\\/ref\\/r\\.md\\t0\\t\\d+\\t[0-9a-f]{64}\$/; END { exit(\$f ? 0 : 1) }' '$G/deploy-harness.payload' && grep -qx 'dotprofile skill ref' '$TMP_ROOT/eq-mdm/.aitools/skills/dskill/ref/r.md'"
check "first run: skills manifest written by MDM, same as dev, lists the dotprofile skill" \
    "cmp -s '$TMP_ROOT/eq-dev/.aitools/skills/.aitools-skills-manifest' '$TMP_ROOT/eq-mdm/.aitools/skills/.aitools-skills-manifest' && grep -qx \"dskill\$(printf '\\t')dotprofile\" '$TMP_ROOT/eq-mdm/.aitools/skills/.aitools-skills-manifest'"
check "first run: MDM needed no git" "no_fake_git"
run dev eq
run mdm eq
check "rerun: everything verified, same rows" "grep -q '^OK|harness files|[0-9]* verified$' '$TMP_ROOT/eq-mdm.summary' && same_summary eq && same_rc eq"
printf 'local edit\n' > "$TMP_ROOT/eq-dev/.aitools/rules/user2.md"
printf 'local edit\n' > "$TMP_ROOT/eq-mdm/.aitools/rules/user2.md"
run dev eq
run mdm eq
# WARN, not OK: the non-interactive overwrite logs a warning and the library
# raises the row to WARN; the dev path does the same (next check).
check "edit then rerun (non-interactive): source wins in MDM, 1 updated" \
    "grep -qx 'user rule two' '$TMP_ROOT/eq-mdm/.aitools/rules/user2.md' && grep -q '^WARN|harness files|1 updated' '$TMP_ROOT/eq-mdm.summary'"
check "edit then rerun: same rows and files as dev" "same_summary eq && same_trees eq"
if ! same_summary eq; then diff "$TMP_ROOT/eq-dev.summary" "$TMP_ROOT/eq-mdm.summary" | perl -pe 's/^/      | /'; fi
PTY="$ROOT/tests/managed-files/pty-run.py"
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then
    printf 'local edit\n' > "$TMP_ROOT/eq-mdm/.aitools/rules/user1.md"
    OUT="$TMP_ROOT/pty-mdm.out"
    : > "$TMP_ROOT/pty-mdm.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$TMP_ROOT/eq-mdm" PATH="$TMP_ROOT/fakegit:$PATH" \
        AITOOLS_LOG_DIR="$TMP_ROOT/eq-mdm/logs" AITOOLS_SUMMARY_FILE="$TMP_ROOT/pty-mdm.summary" \
        python3 "$PTY" --input 's\n' --log "$OUT" -- bash "$TMP_ROOT/b1/deploy/deploy-harness.sh"
    echo $? > "$TMP_ROOT/pty-mdm.rc"
    check "terminal review (MDM): overwrite offered, adopt and merge not; skip keeps LOCAL" \
        "[ \"\$(rc_of pty-mdm)\" = 0 ] && grep -q '\[o\]verwrite' '$OUT' && ! grep -q 'accept & adopt :' '$OUT' && ! grep -q 'merge & adopt  :' '$OUT' && grep -qx 'local edit' '$TMP_ROOT/eq-mdm/.aitools/rules/user1.md' && grep -q '^WARN|harness files|1 skipped' '$TMP_ROOT/pty-mdm.summary'"
    check "terminal review (MDM) without git: diff unavailable, menu still shown" \
        "grep -q 'diff unavailable' '$OUT' && grep -q '\[o\]verwrite' '$OUT'"
else
    printf 'SKIP terminal review case (python3 pty not available)\n'; SKIP=$((SKIP + 1))
fi

run dev dry --dry-run
run mdm dry --dry-run
check "dry run: same rows, nothing deployed" \
    "same_summary dry && same_rc dry && grep -q '^OK|harness files|dry-run: [0-9]* create, 0 update$' '$TMP_ROOT/dry-mdm.summary' && [ ! -e '$TMP_ROOT/dry-mdm/.aitools/rules' ]"
run mdm help --help
check "--help: exit 0, MDM header, nothing deployed" \
    "[ \"\$(rc_of help-mdm)\" = 0 ] && grep -q 'MDM path of scripts/deploy-harness.sh' '$TMP_ROOT/help-mdm.out' && [ ! -e '$TMP_ROOT/help-mdm/.aitools/rules' ]"
check "runs: MDM called git only to display the review diff" "only_review_diff_git"

# ---------------------------------------------------------------------------
# config.json (HARNESS Q3, --skip-config): one code path, OK "config.json" n/a rows
# ---------------------------------------------------------------------------
# A copy of deploy/ whose writer is a stub that records each call.
mkdir -p "$TMP_ROOT/stub/deploy"
cp -Rp "$TMP_ROOT/b1/deploy/." "$TMP_ROOT/stub/deploy/"
printf '#!/usr/bin/env bash\necho "$*" >> "%s/writer.calls"\nexit 0\n' "$TMP_ROOT" > "$TMP_ROOT/stub/deploy/setup-user-config.sh"
chmod +x "$TMP_ROOT/stub/deploy/setup-user-config.sh"
writer_calls() { if [ -f "$TMP_ROOT/writer.calls" ]; then perl -ne '$n++; END { print $n + 0 }' "$TMP_ROOT/writer.calls"; else echo 0; fi; }
# run_fresh NAME ARGS... -- the stub MDM copy under a HOME with no ~/.aitools at all
run_fresh() {
    local name="$1" h; shift
    h="$TMP_ROOT/$name-mdm"
    OUT="$TMP_ROOT/$name-mdm.out"
    : > "$TMP_ROOT/$name-mdm.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" PATH="$TMP_ROOT/fakegit:$PATH" AITOOLS_LOG_DIR="$TMP_ROOT/$name-logs" \
        AITOOLS_SUMMARY_FILE="$TMP_ROOT/$name-mdm.summary" \
        bash "$TMP_ROOT/stub/deploy/deploy-harness.sh" "$@" < /dev/null > "$OUT" 2>&1
    echo $? > "$TMP_ROOT/$name-mdm.rc"
}
rm -f "$TMP_ROOT/writer.calls"
run_fresh fresh
check "fresh HOME (MDM, no bootstrap): exit 0, OK config.json n/a row, no ERROR row" \
    "[ \"\$(rc_of fresh-mdm)\" = 0 ] && row fresh-mdm 'OK|config.json|n/a (no bootstrap)' && ! grep -q '^ERROR|' '$TMP_ROOT/fresh-mdm.summary'"
check "fresh HOME (MDM): writer not called, harness files deployed" \
    "[ \"\$(writer_calls)\" = 0 ] && grep -qx 'user rule one' '$TMP_ROOT/fresh-mdm/.aitools/rules/user1.md' && grep -q '^OK|harness files|[0-9]* added' '$TMP_ROOT/fresh-mdm.summary' && [ ! -e '$TMP_ROOT/fresh-mdm/.aitools/config.json' ]"
# Only one bootstrap key: still no bootstrap
mkdir -p "$TMP_ROOT/half-mdm/.aitools"
printf '{\n  "version": 3,\n  "reposPath": "%s"\n}\n' "$TMP_ROOT" > "$TMP_ROOT/half-mdm/.aitools/config.json"
run_fresh half
check "MDM, config.json without repoPath: n/a (no bootstrap), writer not called" \
    "[ \"\$(rc_of half-mdm)\" = 0 ] && row half-mdm 'OK|config.json|n/a (no bootstrap)' && [ \"\$(writer_calls)\" = 0 ]"
# Bootstrap present: the MDM writer runs
mkdir -p "$TMP_ROOT/boot-mdm"
write_config "$TMP_ROOT/boot-mdm"
run_fresh boot
check "MDM with bootstrap keys: writer called once, no n/a row" \
    "[ \"\$(rc_of boot-mdm)\" = 0 ] && [ \"\$(writer_calls)\" = 1 ] && ! grep -q '^OK|config.json|' '$TMP_ROOT/boot-mdm.summary'"
rm -f "$TMP_ROOT/writer.calls"
run_fresh skipm --skip-config
check "--skip-config (MDM, fresh HOME): n/a (written by installer) wins, writer not called" \
    "[ \"\$(rc_of skipm-mdm)\" = 0 ] && row skipm-mdm 'OK|config.json|n/a (written by installer)' && ! grep -q 'no bootstrap' '$TMP_ROOT/skipm-mdm.summary' && [ \"\$(writer_calls)\" = 0 ]"
check "dev path: the writer ran (its own rows), no config.json n/a row" \
    "grep -q '^[A-Z]*|aitools config|' '$TMP_ROOT/eq-dev.summary' && ! grep -q '|config.json|' '$TMP_ROOT/eq-dev.summary'"
run dev skipd --skip-config
cp "$TMP_ROOT/skipd-dev/.aitools/config.json" "$TMP_ROOT/skipd-config.before"
run dev skipd --skip-config
check "--skip-config (dev): exit 0, OK config.json n/a (written by installer), writer not run" \
    "[ \"\$(rc_of skipd-dev)\" = 0 ] && row skipd-dev 'OK|config.json|n/a (written by installer)' && ! grep -q '|aitools config|' '$TMP_ROOT/skipd-dev.summary' && cmp -s '$TMP_ROOT/skipd-config.before' '$TMP_ROOT/skipd-dev/.aitools/config.json' && ! grep -q '\"meta\"' '$TMP_ROOT/skipd-dev/.aitools/config.json'"
run dev helpd --help
check "--help (dev): documents --skip-config, no marker lines" \
    "[ \"\$(rc_of helpd-dev)\" = 0 ] && grep -q -- '--skip-config' '$TMP_ROOT/helpd-dev.out' && ! grep -q -- '--- BEGIN' '$TMP_ROOT/helpd-dev.out' && ! grep -q -- '--- END' '$TMP_ROOT/helpd-dev.out'"

# ---------------------------------------------------------------------------
# Damaged payload: whole-file checksum, one damaged record, a missing payload
# and a truncated script fail loudly
# ---------------------------------------------------------------------------
mkdir -p "$TMP_ROOT/bad/deploy"
cp -Rp "$TMP_ROOT/b1/deploy/." "$TMP_ROOT/bad/deploy/"
# corrupt_record FILE -- replace the first base64 line of user1.md's record
corrupt_record() {
    perl -i -ne 'if ($skip) { print "QUJD\n"; $skip = 0; next } $skip = 1 if /^dotprofile\/claude\/rules\/user1\.md\t/; print' "$1"
}
corrupt_record "$TMP_ROOT/bad/deploy/deploy-harness.payload"
BUILD=bad
run mdm corrupt
check "damaged payload (checksum): exit 1, ERROR payload damaged, nothing deployed" \
    "[ \"\$(rc_of corrupt-mdm)\" = 1 ] && row corrupt-mdm 'ERROR|harness files|payload damaged' && grep -q 'sha256 mismatch' '$TMP_ROOT/corrupt-mdm.out' && [ ! -e '$TMP_ROOT/corrupt-mdm/.aitools/rules' ]"
# The same damage with the script's sha256 updated: the record check catches it
NEWSHA=$(perl -MDigest::SHA=sha256_hex -0777 -ne 's/\r//g; print sha256_hex($_)' "$TMP_ROOT/bad/deploy/deploy-harness.payload")
perl -i -pe "s/^MDM_PAYLOAD_SHA256=.*/MDM_PAYLOAD_SHA256=$NEWSHA/" "$TMP_ROOT/bad/deploy/deploy-harness.sh"
run mdm record
check "damaged record: exit 1, ERROR row, that file not deployed, the others are" \
    "[ \"\$(rc_of record-mdm)\" = 1 ] && grep -q '^ERROR|harness files|1 embedded file(s) damaged' '$TMP_ROOT/record-mdm.summary' && grep -q 'user1.md is damaged' '$TMP_ROOT/record-mdm.out' && [ ! -e '$TMP_ROOT/record-mdm/.aitools/rules/user1.md' ] && [ -f '$TMP_ROOT/record-mdm/.aitools/rules/user2.md' ]"
# A CRLF copy of the payload (Windows checkout with autocrlf) still verifies
cp -p "$TMP_ROOT/b1/deploy/deploy-harness.payload" "$TMP_ROOT/bad/deploy/deploy-harness.payload"
cp -p "$TMP_ROOT/b1/deploy/deploy-harness.sh" "$TMP_ROOT/bad/deploy/deploy-harness.sh"
perl -pi -e 's/\n/\r\n/' "$TMP_ROOT/bad/deploy/deploy-harness.payload"
run mdm crlf
check "CRLF payload: verified and deployed (exit 0)" \
    "[ \"\$(rc_of crlf-mdm)\" = 0 ] && grep -qx 'user rule one' '$TMP_ROOT/crlf-mdm/.aitools/rules/user1.md'"
rm -f "$TMP_ROOT/bad/deploy/deploy-harness.payload"
run mdm nopayload
check "missing payload: exit 1, ERROR payload missing, nothing deployed" \
    "[ \"\$(rc_of nopayload-mdm)\" = 1 ] && row nopayload-mdm 'ERROR|harness files|payload missing' && [ ! -e '$TMP_ROOT/nopayload-mdm/.aitools/rules' ]"
cp -p "$TMP_ROOT/b1/deploy/deploy-harness.payload" "$TMP_ROOT/bad/deploy/deploy-harness.payload"
# Truncated copies (review B1): the guard is the first command, so every cut
# after it -- inside the inlined library (a bash parse error otherwise, exit
# 2), at a top-level line in section 1 (exit 0 with nothing done otherwise),
# or in sections 3-7 -- exits 1 with the row and deploys nothing.
# trunc_case NAME PERL_EXPR -- cut a copy of b1's script at byte PERL_EXPR($s = size, $t = text)
trunc_case() {
    cp -p "$TMP_ROOT/b1/deploy/deploy-harness.sh" "$TMP_ROOT/bad/deploy/deploy-harness.sh"
    perl -e 'my ($f, $e) = @ARGV; my $s = -s $f; open my $h, "<", $f or die; my $t = do { local $/; <$h> }; close $h; my $n = eval $e; die "no cut point\n" unless $n && $n < $s; truncate($f, $n) or die "truncate: $!\n"' \
        "$TMP_ROOT/bad/deploy/deploy-harness.sh" "$2"
    run mdm "$1"
}
trunc_case trunc40 'int($s * 0.40)'
check "truncated script at 40% (inside the library): exit 1, ERROR row, nothing deployed" \
    "[ \"\$(rc_of trunc40-mdm)\" = 1 ] && row trunc40-mdm 'ERROR|harness files|script truncated' && [ ! -e '$TMP_ROOT/trunc40-mdm/.aitools/rules' ]"
trunc_case truncs1 'index($t, "\n# 1. config.json") + 1'
check "truncated script at the section 1 heading: exit 1, ERROR row, nothing deployed" \
    "[ \"\$(rc_of truncs1-mdm)\" = 1 ] && row truncs1-mdm 'ERROR|harness files|script truncated' && [ ! -e '$TMP_ROOT/truncs1-mdm/.aitools/rules' ]"
trunc_case trunc95 'int($s * 0.95)'
check "truncated script at 95% (sections 3-7): exit 1, ERROR row, nothing deployed" \
    "[ \"\$(rc_of trunc95-mdm)\" = 1 ] && row trunc95-mdm 'ERROR|harness files|script truncated' && [ ! -e '$TMP_ROOT/trunc95-mdm/.aitools/rules' ]"
check "truncation guard: the first command of the generated script (before the library)" \
    "[ \"\$(perl -ne 'if (/^if command -v perl .*END OF GENERATED SCRIPT/) { print \$.; exit }' '$G/deploy-harness.sh')\" -lt \"\$(perl -ne 'if (/^logging_init\\b/ || /^set -euo pipefail\$/) { print \$.; exit }' '$G/deploy-harness.sh')\" ]"
# A record line with a non-numeric size (sha updated): malformed, payload damaged
cp -p "$TMP_ROOT/b1/deploy/deploy-harness.sh" "$TMP_ROOT/bad/deploy/deploy-harness.sh"
perl -i -pe 's/^(dotprofile\/claude\/rules\/user1\.md\t0\t)\d+/${1}x/' "$TMP_ROOT/bad/deploy/deploy-harness.payload"
NEWSHA=$(perl -MDigest::SHA=sha256_hex -0777 -ne 's/\r//g; print sha256_hex($_)' "$TMP_ROOT/bad/deploy/deploy-harness.payload")
perl -i -pe "s/^MDM_PAYLOAD_SHA256=.*/MDM_PAYLOAD_SHA256=$NEWSHA/" "$TMP_ROOT/bad/deploy/deploy-harness.sh"
run mdm malformed
check "malformed record (size not a number): exit 1, ERROR payload damaged, nothing deployed" \
    "[ \"\$(rc_of malformed-mdm)\" = 1 ] && row malformed-mdm 'ERROR|harness files|payload damaged' && grep -q 'malformed record line' '$TMP_ROOT/malformed-mdm.out' && [ ! -e '$TMP_ROOT/malformed-mdm/.aitools/rules' ]"
BUILD=b1

# ---------------------------------------------------------------------------
# Conflicts: a dotprofile rule named like a project rule (case differs)
# ---------------------------------------------------------------------------
printf 'dotprofile copy\n' > "$DOT/claude/rules/Git-Safety.md"
gitc -C "$DOT" add -A
gitc -C "$DOT" commit -q -m dup
BUILD=b2
build b2
run dev dup
run mdm dup
check "conflict: both exit 1 with the same ERROR row" \
    "[ \"\$(rc_of dup-dev)\" = 1 ] && same_rc dup && row dup-mdm 'ERROR|harness files|Git-Safety.md: dup in dotpr...' && same_summary dup"
check "conflict: first source wins in MDM" "cmp -s '$ROOT/.claude/rules/git-safety.md' '$TMP_ROOT/dup-mdm/.aitools/rules/git-safety.md' && same_trees dup"

# ---------------------------------------------------------------------------
# Build from a non-git dotprofile (pre-push step 7 builds into a git-archive copy)
# ---------------------------------------------------------------------------
mv "$DOT/.git" "$TMP_ROOT/dot.git"
BUILD=b3
build b3
mv "$TMP_ROOT/dot.git" "$DOT/.git"
check "non-git dotprofile: build exit 0 with a warning" \
    "[ \"\$(rc_of build-b3)\" = 0 ] && grep -q 'not in a git work tree -- embedding every file on disk' '$TMP_ROOT/build-b3.out'"
check "non-git dotprofile: generated deploy-harness identical to the git build" \
    "cmp -s '$TMP_ROOT/b2/deploy/deploy-harness.sh' '$TMP_ROOT/b3/deploy/deploy-harness.sh' && cmp -s '$TMP_ROOT/b2/deploy/deploy-harness.ps1' '$TMP_ROOT/b3/deploy/deploy-harness.ps1' && cmp -s '$TMP_ROOT/b2/deploy/deploy-harness.payload' '$TMP_ROOT/b3/deploy/deploy-harness.payload'"

# ---------------------------------------------------------------------------
# Markers (HARNESS Q6): a missing or duplicated marker fails the build, and the
# dotprofile deploy/ is left as it was (the build is staged)
# ---------------------------------------------------------------------------
# A copy of the sources build-deploy reads (not a git checkout: the snapshot
# lists files on disk, as for pre-push step 7's copy).
RC="$TMP_ROOT/repo-copy"
mkdir -p "$RC/.claude"
cp -Rp "$ROOT/scripts" "$ROOT/shared" "$ROOT/reference" "$ROOT/registries" "$RC/"
for d in hooks skills rules; do
    if [ -d "$ROOT/.claude/$d" ]; then cp -Rp "$ROOT/.claude/$d" "$RC/.claude/"; fi
done
cp -p "$DOT/deploy/deploy-harness.sh" "$TMP_ROOT/deploy-before.sh"
# marker_build NAME PERL_EDIT FILE -- edit FILE in the copy, build, restore it
marker_build() {
    local hb="$TMP_ROOT/home-build-$1"
    cp -p "$RC/scripts/$3" "$TMP_ROOT/$3.orig"
    perl -i -pe "$2" "$RC/scripts/$3"
    write_config "$hb"
    OUT="$TMP_ROOT/build-$1.out"
    HOME="$hb" AITOOLS_USER_REPO_PATH="$DOT" bash "$RC/scripts/build-deploy.sh" > "$OUT" 2>&1
    echo $? > "$TMP_ROOT/build-$1.rc"
    cp -p "$TMP_ROOT/$3.orig" "$RC/scripts/$3"
}
marker_build nomark 's/^# --- END dotprofile lookup .*\n//' deploy-harness.sh
check "markers: a missing END marker fails the build (.sh source)" \
    "[ \"\$(rc_of build-nomark)\" != 0 ] && grep -q 'END dotprofile lookup.*matches 0 lines' '$TMP_ROOT/build-nomark.out'"
marker_build dupmark 's/^(# --- BEGIN scope .*)$/$1\n$1/' deploy-harness.ps1
check "markers: a duplicated BEGIN marker fails the build (.ps1 source)" \
    "[ \"\$(rc_of build-dupmark)\" != 0 ] && grep -q 'BEGIN scope.*matches 2 lines' '$TMP_ROOT/build-dupmark.out'"
check "markers: failed builds left the dotprofile deploy/ as it was" \
    "cmp -s '$TMP_ROOT/deploy-before.sh' '$DOT/deploy/deploy-harness.sh' && [ -f '$DOT/deploy/deploy-harness.payload' ]"

# ---------------------------------------------------------------------------
# PS1 pair on pwsh (OS guards disabled in temp copies, stub config writer)
# ---------------------------------------------------------------------------
if command -v pwsh >/dev/null 2>&1; then
    P="$TMP_ROOT/ps1"
    mkdir -p "$P/dev/scripts" "$P/dev/shared" "$P/dev/.claude" "$P/mdm/deploy"
    stub='param([switch]$DryRun, [switch]$Force)
Add-Content -LiteralPath (Join-Path $env:AITOOLS_TEST_ROOT "ps-writer.calls") -Value "called"
exit 0'
    export AITOOLS_TEST_ROOT="$TMP_ROOT"
    ps_calls() { if [ -f "$TMP_ROOT/ps-writer.calls" ]; then perl -ne '$n++; END { print $n + 0 }' "$TMP_ROOT/ps-writer.calls"; else echo 0; fi; }
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/deploy-harness.ps1" > "$P/dev/scripts/deploy-harness.ps1"
    cp "$ROOT/scripts/aitools-lib.ps1" "$ROOT/scripts/harness-db.py" "$ROOT/scripts/read-session.py" "$ROOT/scripts/read-session-full.py" "$P/dev/scripts/"
    printf '%s\n' "$stub" > "$P/dev/scripts/setup-user-config.ps1"
    ln -s "$ROOT/reference" "$P/dev/reference"
    ln -s "$ROOT/registries" "$P/dev/registries"
    for d in hooks skills rules; do ln -s "$ROOT/shared/$d" "$P/dev/shared/$d"; done
    for d in skills rules; do ln -s "$ROOT/.claude/$d" "$P/dev/.claude/$d"; done
    perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$TMP_ROOT/b1/deploy/deploy-harness.ps1" > "$P/mdm/deploy/deploy-harness.ps1"
    cp -p "$TMP_ROOT/b1/deploy/deploy-harness.payload" "$P/mdm/deploy/"
    printf '%s\n' "$stub" > "$P/mdm/deploy/setup-user-config.ps1"
    # The b1 snapshot has no dup; the dotprofile now has one: use b1's state.
    gitc -C "$DOT" rm -q claude/rules/Git-Safety.md
    gitc -C "$DOT" commit -q -m undup
    for side in dev mdm; do
        h="$TMP_ROOT/ps-$side"; write_config "$h"
        if [ "$side" = dev ]; then f="$P/dev/scripts/deploy-harness.ps1"; else f="$P/mdm/deploy/deploy-harness.ps1"; fi
        OUT="$TMP_ROOT/ps-$side.out"
        : > "$TMP_ROOT/ps-$side.summary"
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/ps-$side.summary" \
            pwsh -NoProfile -File "$f" < /dev/null > "$OUT" 2>&1
        echo $? > "$TMP_ROOT/ps-$side.rc"
    done
    check "ps1: same exit code (0), summary rows and files" \
        "[ \"\$(rc_of ps-dev)\" = 0 ] && same_rc ps && same_summary ps && diff -r -x logs -x config.json '$TMP_ROOT/ps-dev/.aitools' '$TMP_ROOT/ps-mdm/.aitools' > /dev/null"
    check "ps1: with bootstrap keys both paths ran the writer (dev, MDM)" "[ \"\$(ps_calls)\" = 2 ]"
    # ps_run NAME FILE HOME_SETUP(fresh|config) ARGS... -- one pwsh run
    ps_run() {
        local name="$1" f="$2" setup="$3" h; shift 3
        h="$TMP_ROOT/ps-$name"
        if [ "$setup" = config ]; then write_config "$h"; fi
        OUT="$TMP_ROOT/ps-$name.out"
        : > "$TMP_ROOT/ps-$name.summary"
        # PS_TMPDIR: the temp root .NET uses for the stage directory (cleanup check)
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$TMP_ROOT/ps-$name-logs" \
            AITOOLS_SUMMARY_FILE="$TMP_ROOT/ps-$name.summary" TMPDIR="${PS_TMPDIR:-${TMPDIR:-/tmp}}" \
            pwsh -NoProfile -File "$f" "$@" < /dev/null > "$OUT" 2>&1
        echo $? > "$TMP_ROOT/ps-$name.rc"
    }
    rm -f "$TMP_ROOT/ps-writer.calls"
    ps_run fresh "$P/mdm/deploy/deploy-harness.ps1" fresh
    check "ps1 fresh HOME (MDM, no bootstrap): exit 0, OK config.json n/a row, writer not called, files deployed" \
        "[ \"\$(rc_of ps-fresh)\" = 0 ] && row ps-fresh 'OK|config.json|n/a (no bootstrap)' && ! grep -q '^ERROR|' '$TMP_ROOT/ps-fresh.summary' && [ \"\$(ps_calls)\" = 0 ] && grep -qx 'user rule one' '$TMP_ROOT/ps-fresh/.aitools/rules/user1.md'"
    mkdir -p "$TMP_ROOT/ps-half/.aitools"
    printf '{\n  "version": 3,\n  "reposPath": "%s"\n}\n' "$TMP_ROOT" > "$TMP_ROOT/ps-half/.aitools/config.json"
    ps_run half "$P/mdm/deploy/deploy-harness.ps1" keep
    check "ps1 MDM, config.json without repoPath: n/a (no bootstrap), writer not called" \
        "[ \"\$(rc_of ps-half)\" = 0 ] && row ps-half 'OK|config.json|n/a (no bootstrap)' && [ \"\$(ps_calls)\" = 0 ]"
    ps_run skipd "$P/dev/scripts/deploy-harness.ps1" config -SkipConfig
    ps_run skipm "$P/mdm/deploy/deploy-harness.ps1" fresh -SkipConfig
    check "ps1 -SkipConfig (dev and MDM): exit 0, OK config.json n/a (written by installer), writer not called" \
        "[ \"\$(rc_of ps-skipd)\" = 0 ] && [ \"\$(rc_of ps-skipm)\" = 0 ] && row ps-skipd 'OK|config.json|n/a (written by installer)' && row ps-skipm 'OK|config.json|n/a (written by installer)' && [ \"\$(ps_calls)\" = 0 ]"
    ps_run helpd "$P/dev/scripts/deploy-harness.ps1" fresh -Help
    check "ps1 -Help (dev): documents -SkipConfig, no marker lines" \
        "[ \"\$(rc_of ps-helpd)\" = 0 ] && grep -q -- '-SkipConfig' '$TMP_ROOT/ps-helpd.out' && ! grep -q -- '--- BEGIN' '$TMP_ROOT/ps-helpd.out'"
    # CRLF payload still verifies
    perl -pi -e 's/\n/\r\n/' "$P/mdm/deploy/deploy-harness.payload"
    ps_run crlf "$P/mdm/deploy/deploy-harness.ps1" config
    check "ps1 CRLF payload: verified and deployed (exit 0)" \
        "[ \"\$(rc_of ps-crlf)\" = 0 ] && grep -qx 'user rule one' '$TMP_ROOT/ps-crlf/.aitools/rules/user1.md'"
    # Damaged payload: whole-file checksum, then one record with the sha updated
    cp -p "$TMP_ROOT/b1/deploy/deploy-harness.payload" "$P/mdm/deploy/deploy-harness.payload"
    corrupt_record "$P/mdm/deploy/deploy-harness.payload"
    ps_run bad "$P/mdm/deploy/deploy-harness.ps1" config
    check "ps1 damaged payload (checksum): exit 1, ERROR payload damaged, nothing deployed" \
        "[ \"\$(rc_of ps-bad)\" = 1 ] && row ps-bad 'ERROR|harness files|payload damaged' && [ ! -e '$TMP_ROOT/ps-bad/.aitools/rules' ]"
    NEWSHA=$(perl -MDigest::SHA=sha256_hex -0777 -ne 's/\r//g; print sha256_hex($_)' "$P/mdm/deploy/deploy-harness.payload")
    perl -i -pe "s/^\\\$mdmPayloadSha256 = \"[0-9a-f]+\"/\\\$mdmPayloadSha256 = \"$NEWSHA\"/" "$P/mdm/deploy/deploy-harness.ps1"
    mkdir -p "$TMP_ROOT/pstmp"
    PS_TMPDIR="$TMP_ROOT/pstmp/" ps_run rec "$P/mdm/deploy/deploy-harness.ps1" config
    check "ps1 damaged record: exit 1, ERROR row, that file not deployed" \
        "[ \"\$(rc_of ps-rec)\" = 1 ] && grep -q '^ERROR|harness files|1 embedded file(s) damaged' '$TMP_ROOT/ps-rec.summary' && [ ! -e '$TMP_ROOT/ps-rec/.aitools/rules/user1.md' ] && [ -f '$TMP_ROOT/ps-rec/.aitools/rules/user2.md' ]"
    check "ps1 exit 1 after unpacking: the stage directory was created there and removed (finally)" \
        "grep -q 'unpacked in $TMP_ROOT/pstmp/aitools-harness-' '$TMP_ROOT/ps-rec.out' && [ -z \"\$(ls -A '$TMP_ROOT/pstmp')\" ]"
    # A record line with a non-numeric size (sha updated): malformed, payload damaged
    cp -p "$TMP_ROOT/b1/deploy/deploy-harness.payload" "$P/mdm/deploy/deploy-harness.payload"
    perl -i -pe 's/^(dotprofile\/claude\/rules\/user1\.md\t0\t)\d+/${1}x/' "$P/mdm/deploy/deploy-harness.payload"
    NEWSHA=$(perl -MDigest::SHA=sha256_hex -0777 -ne 's/\r//g; print sha256_hex($_)' "$P/mdm/deploy/deploy-harness.payload")
    perl -i -pe "s/^\\\$mdmPayloadSha256 = \"[0-9a-f]+\"/\\\$mdmPayloadSha256 = \"$NEWSHA\"/" "$P/mdm/deploy/deploy-harness.ps1"
    ps_run malf "$P/mdm/deploy/deploy-harness.ps1" config
    check "ps1 malformed record (size not a number): exit 1, ERROR payload damaged, nothing deployed" \
        "[ \"\$(rc_of ps-malf)\" = 1 ] && row ps-malf 'ERROR|harness files|payload damaged' && [ ! -e '$TMP_ROOT/ps-malf/.aitools/rules' ]"
    rm -f "$P/mdm/deploy/deploy-harness.payload"
    ps_run nop "$P/mdm/deploy/deploy-harness.ps1" config
    check "ps1 missing payload: exit 1, ERROR payload missing, nothing deployed" \
        "[ \"\$(rc_of ps-nop)\" = 1 ] && row ps-nop 'ERROR|harness files|payload missing' && [ ! -e '$TMP_ROOT/ps-nop/.aitools/rules' ]"
else
    printf 'SKIP ps1 pair (pwsh not found)\n'; SKIP=$((SKIP + 1))
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
