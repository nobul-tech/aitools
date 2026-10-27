#!/usr/bin/env bash
# test-rules-fanout.sh -- tests for the rules fan-out of scripts/setup-user-claude.sh
# and .ps1: ~/.aitools/rules -> ~/.claude/rules. Everything is fanned out except
# the rules the manifest retires; *.md only, names compared case-insensitively;
# *.bak.* and hidden files skipped; unmanaged files preserved; the copy of a
# retired rule removed only when it matches a harness copy; adopt target from
# the manifest source; the dotprofile's claude/rules is not read directly. Also
# the lib helpers (tracker "removed", unknown outcomes, rule_name_kind).
#
# Safe to re-run: every case runs a copy of scripts/ in a temp aitools checkout,
# under its own temp HOME, with a temp git dotprofile (all removed on exit); the
# real HOME, ~/.aitools and dotprofile are never touched. With pwsh on PATH every
# case also runs setup-user-claude.ps1 (a copy with its Windows OS guard off) and
# compares its ~/.claude/rules tree and summary rows with the .sh run (parity).
# Platform: macOS, Linux (perl, git; pwsh and python3 optional: their cases are
# skipped). Exit 1 if any case fails. Spec: plans/rules-fanout-claude.md.
#
# Usage: bash tests/rules-fanout/test-rules-fanout.sh [--bash-only] [--help]

set -uo pipefail

BASH_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --help|-h) perl -ne 'print if $. >= 2 && $. <= 18' "$0"; exit 0 ;;
        --bash-only) BASH_ONLY=true ;;
        *) printf 'Unknown option: %s (see --help)\n' "$arg"; exit 1 ;;
    esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PTY="$ROOT/tests/managed-files/pty-run.py"
TMP_ROOT="$(mktemp -d)"
cleanup() {
    # chmod 000 cases: restore so rm can remove them
    chmod -R u+rwx "$TMP_ROOT" 2>/dev/null || printf 'warn: chmod restore failed under %s\n' "$TMP_ROOT"
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT
TB="${AITOOLS_TEST_BASH:-bash}"   # CI also runs macOS /bin/bash 3.2

PASS=0
FAIL=0
SKIP=0
C=""

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "$C" ] && [ -f "$C/sh.out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/sh.out" | tail -n 25
        fi
    fi
}
skip() { printf 'SKIP %s\n' "$1"; SKIP=$((SKIP + 1)); }

for t in perl git; do
    if ! command -v "$t" >/dev/null 2>&1; then
        printf 'SKIP all cases (%s not found)\n' "$t"
        exit 0
    fi
done
HAVE_PWSH=false
if ! $BASH_ONLY && command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi
HAVE_PTY=false
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then HAVE_PTY=true; fi
CAN_CHMOD_READ=true   # chmod 000 blocks reads (not for root, not under Git Bash)
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) CAN_CHMOD_READ=false ;; esac
if [ "$(id -u)" = 0 ]; then CAN_CHMOD_READ=false; fi
CASE_SENSITIVE_FS=false
: > "$TMP_ROOT/cs-probe"
if [ ! -e "$TMP_ROOT/CS-PROBE" ]; then CASE_SENSITIVE_FS=true; fi

gitc() { git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# --- Temp aitools checkout: a copy of scripts/ (adopt targets of shared and
# aitools rules land here, never in this repo) ---
A="$TMP_ROOT/aitools"
mkdir -p "$A/scripts" "$A/shared/rules" "$A/.claude/rules"
for f in setup-user-claude.sh aitools-lib.sh aitools-lib.ps1 aitools-profile.sh aitools-profile.ps1 aitools-json.pl aitools-json.ps1; do
    cp "$ROOT/scripts/$f" "$A/scripts/$f"
done
perl -pe 's/-and -not \$IsWindows\)/-and \$false)/' "$ROOT/scripts/setup-user-claude.ps1" > "$A/scripts/setup-user-claude.ps1"
cp "$ROOT/shared/claude-shared.md" "$A/shared/claude-shared.md"
# A package payload (git archive) has the same files but no .git: adopt into it
# is never offered (BUILD-PKG BP-6). The fan-out counts only a git checkout.
PAYLOAD="$TMP_ROOT/payload"
mkdir -p "$PAYLOAD"
cp -R "$A/scripts" "$A/shared" "$A/.claude" "$PAYLOAD/"
git -C "$A" init -q
REPO="$A"   # the checkout run_one / run_pty run setup-user-claude from

# --- Fixture dotprofile (a git repo, no remote: an adopt commits, the push fails) ---
DP="$TMP_ROOT/aitools-tess"
mkdir -p "$DP/claude/rules"
printf '# Prefs for {{PROFILE_NAME}}\n\n## Code Style\n\n- keep it simple\n' > "$DP/claude/CLAUDE.md"
printf '{"version":2,"identity":{"git":{"name":"Tess","email":"t@example.com"}},"profiles":{"m1":{"name":"Tess","company":""}}}\n' > "$DP/profile.json"
printf '## dot d\n' > "$DP/claude/rules/d.md"
printf '## only in the dotprofile\n' > "$DP/claude/rules/only-dp.md"
git -C "$DP" init -q
gitc -C "$DP" add -A
gitc -C "$DP" commit -q -m fixture

# --- Case helpers ---
# H: the HOME of the run being seeded (set by case_run for each language)
harness() { mkdir -p "$H/.aitools/rules"; printf '%s\n' "$2" > "$H/.aitools/rules/$1"; }
deployed() { mkdir -p "$H/.claude/rules"; printf '%s\n' "$2" > "$H/.claude/rules/$1"; }
# manifest <line>...: ~/.aitools/rules/.aitools-rules-manifest (PR #100 v1);
# "|" stands for the TAB
manifest() {
    mkdir -p "$H/.aitools/rules"
    { printf '# aitools rules manifest v1\n'
      for l in "$@"; do printf '%s\n' "$l" | tr '|' '\t'; done
    } > "$H/.aitools/rules/.aitools-rules-manifest"
}

# run_one LANG [FLAG]: run setup-user-claude.<LANG> non-interactively under $C/<LANG>
run_one() {
    local lang="$1" flag="${2:-}" h="$C/$1"
    local e=(env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1
        HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$C/$lang.summary"
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1)
    : > "$C/$lang.summary"
    if [ "$lang" = sh ]; then
        "${e[@]}" "$TB" "$REPO/scripts/setup-user-claude.sh" ${flag:+"$flag"} < /dev/null > "$C/sh.out" 2>&1
    else
        "${e[@]}" pwsh -NoProfile -File "$REPO/scripts/setup-user-claude.ps1" ${flag:+"$flag"} < /dev/null > "$C/ps.out" 2>&1
    fi
    echo $? > "$C/$lang.rc"
}

# run_pty LANG INPUT: the same on a pty (review menu), keystrokes INPUT
run_pty() {
    local lang="$1" input="$2" h="$C/$1" cmd
    : > "$C/$lang.summary"
    if [ "$lang" = sh ]; then cmd=("$TB" "$REPO/scripts/setup-user-claude.sh"); else cmd=(pwsh -NoProfile -File "$REPO/scripts/setup-user-claude.ps1"); fi
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE \
        -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
        HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$h/logs" AITOOLS_SUMMARY_FILE="$C/$lang.summary" \
        AITOOLS_PROFILE_TEST_ANY_OS=1 GIT_CONFIG_GLOBAL="$h/.gitconfig" GIT_CONFIG_NOSYSTEM=1 \
        python3 "$PTY" --input "$input" --log "$C/$lang.out" -- "${cmd[@]}"
    echo $? > "$C/$lang.rc"
}

# case_run NAME SEED_FN [SH_FLAG PS_FLAG]: fresh HOMEs $C/sh and $C/ps (the
# latter only with pwsh), each with config.json -> the fixture dotprofile,
# seeded by SEED_FN, then one run per language
case_run() {
    C="$TMP_ROOT/$1"
    local seed="$2" shf="${3:-}" psf="${4:-}" lang
    mkdir -p "$C"
    for lang in sh ps; do
        if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
        H="$C/$lang"
        mkdir -p "$H/.aitools"
        printf '{"userRepoPath":"%s","machineAlias":"m1"}\n' "$DP" > "$H/.aitools/config.json"
        printf '[user]\n\tname = Test\n\temail = test@example.invalid\n[commit]\n\tgpgsign = false\n' > "$H/.gitconfig"
        "$seed"
        if [ "$lang" = sh ]; then run_one sh "$shf"; else run_one ps "$psf"; fi
    done
}
rerun() {  # rerun [SH_FLAG PS_FLAG]: run again in the same HOMEs
    run_one sh "${1:-}"
    if [ "$HAVE_PWSH" = "true" ]; then run_one ps "${2:-}"; fi
}

rc() { cat "$C/${1:-sh}.rc"; }
row() { grep -qxF "$1" "$C/${2:-sh}.summary"; }                  # exact summary row
nondetail() { grep -F '|claude rules|' "$C/${1:-sh}.summary" | grep -v '^DETAIL' | tail -n 1; }
R() { printf '%s' "$C/${1:-sh}/.claude/rules"; }                  # the deployed rules dir
logged() { cat "$C/${2:-sh}/logs/"*.log 2>/dev/null | grep -qF "$1"; }  # in the run's log files (none: no match)

# tree_sig DIR: "<path> <md5>" per file, backup time stamps normalized
tree_sig() {
    perl -MDigest::MD5=md5_hex -MFile::Find -e '
        my $root = shift; my @out;
        exit 0 unless -d $root;
        find({ no_chdir => 1, wanted => sub {
            return unless -f $_;
            open my $fh, "<:raw", $_ or die "cannot read $_: $!\n";
            local $/; my $c = <$fh>; close $fh;
            (my $rel = substr($_, length($root) + 1)) =~ s/\.bak\.[0-9TZ-]+\z/.bak.TS/;
            push @out, "$rel " . md5_hex(defined $c ? $c : "");
        } }, $root);
        print "$_\n" for sort @out;
    ' "$1"
}
rows() { grep -E '^(ACTION\||[A-Z]+\|claude rules\|)' "$1" | LC_ALL=C sort; }

# parity CASE: the .ps1 run of the case gave the .sh run's exit code, tree and rows
parity() {
    if [ "$HAVE_PWSH" != "true" ]; then skip "parity ps1: $1 (pwsh not on PATH or --bash-only)"; return; fi
    tree_sig "$(R sh)" > "$C/tree-sh"; tree_sig "$(R ps)" > "$C/tree-ps"
    rows "$C/sh.summary" > "$C/rows-sh"; rows "$C/ps.summary" > "$C/rows-ps"
    check "parity ps1: $1: exit code" "[ \"\$(rc ps)\" = \"\$(rc sh)\" ] || { tail -n 20 '$C/ps.out'; false; }"
    check "parity ps1: $1: ~/.claude/rules" "cmp -s '$C/tree-sh' '$C/tree-ps' || { diff '$C/tree-sh' '$C/tree-ps'; false; }"
    check "parity ps1: $1: summary rows" "cmp -s '$C/rows-sh' '$C/rows-ps' || { diff '$C/rows-sh' '$C/rows-ps'; false; }"
}

# ---------------------------------------------------------------------------
# Lib helpers: tracker "removed" and unknown outcomes, rule_name_kind
# ---------------------------------------------------------------------------
C="$TMP_ROOT/lib"; mkdir -p "$C"
env HOME="$C" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/sh.summary" "$TB" -c '
    source "$1/scripts/aitools-lib.sh"; logging_init "test-rules-fanout"
    deploy_tracker_init
    deploy_tracker_record removed "t" "x.md"
    deploy_tracker_record bogus "t" "y.md"
    deploy_tracker_summary "t"
    printf "TEXT=%s\n" "$DEPLOY_TRACKER_TEXT"
    for n in a.md A.MD b.Md x.md.bak.1 X.MD.BAK.2026 odd.bak.2026.md .hidden.md notes.txt; do printf "%s=%s\n" "$n" "$(rule_name_kind "$n")"; done
' _ "$A" > "$C/sh.out" 2>&1
check "lib sh: removed outcome: DETAIL row and count" "row 'DETAIL|t|removed: x.md' && grep -qx 'TEXT=1 removed, 1 failed' '$C/sh.out'"
check "lib sh: unknown outcome: logged, counted as failed, ERROR row" "row 'DETAIL|t|failed: y.md' && row 'ERROR|t|1 failed' && grep -q 'unknown outcome \"bogus\"' '$C/sh.out'"
check "lib sh: rule_name_kind is case-insensitive" "grep -qx 'A.MD=rule' '$C/sh.out' && grep -qx 'b.Md=rule' '$C/sh.out' && grep -qx 'X.MD.BAK.2026=backup' '$C/sh.out' && grep -qx 'odd.bak.2026.md=backup' '$C/sh.out' && grep -qx '.hidden.md=hidden' '$C/sh.out' && grep -qx 'notes.txt=other' '$C/sh.out'"
if [ "$HAVE_PWSH" = "true" ]; then
    cat > "$C/lib.ps1" <<'PS1'
param([string]$Repo)
. (Join-Path (Join-Path $Repo "scripts") "aitools-lib.ps1")
Initialize-Logging "test-rules-fanout"
Initialize-DeployTracker
Record-DeployOutcome -Outcome "removed" -ToolName "t" -ItemName "x.md"
Record-DeployOutcome -Outcome "bogus" -ToolName "t" -ItemName "y.md"
Write-DeployTrackerSummary -ToolName "t"
[Console]::WriteLine("TEXT=$($script:deployTrackerText)")
foreach ($n in @("a.md", "A.MD", "b.Md", "x.md.bak.1", "X.MD.BAK.2026", "odd.bak.2026.md", ".hidden.md", "notes.txt")) { [Console]::WriteLine("$n=$(Get-RuleNameKind $n)") }
PS1
    env HOME="$C" USERPROFILE="$C" AITOOLS_LOG_DIR="$C/logs-ps" AITOOLS_SUMMARY_FILE="$C/ps.summary" \
        pwsh -NoProfile -File "$C/lib.ps1" "$A" > "$C/ps.out" 2>&1
    check "lib parity: tracker rows" "cmp -s '$C/sh.summary' '$C/ps.summary' || { diff '$C/sh.summary' '$C/ps.summary'; false; }"
    check "lib parity: summary text and kinds" "diff <(grep -E '^(TEXT=|[^ ]+=(rule|backup|hidden|other)$)' '$C/sh.out') <(grep -E '^(TEXT=|[^ ]+=(rule|backup|hidden|other)$)' '$C/ps.out')"
else
    skip "lib parity (pwsh not on PATH or --bash-only)"
fi

# ---------------------------------------------------------------------------
# No harness rules: nothing deployed, ~/.claude/rules untouched, exit 0
# ---------------------------------------------------------------------------
seed_missing() { deployed mine.md 'mine'; }
case_run missing seed_missing
check "missing: exit 0, row n/a (no harness rules)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude rules|n/a (no harness rules)' ]"
check "missing: ~/.claude/rules untouched, no directory backup" "grep -qx mine '$(R)/mine.md' && [ \"\$(ls '$(R)')\" = mine.md ] && ! ls '$C/sh/.claude' | grep -q 'rules.bak'"
check "missing: the dotprofile's claude/rules is not deployed" "[ ! -e '$(R)/d.md' ] && [ ! -e '$(R)/only-dp.md' ]"
parity missing

seed_empty() { mkdir -p "$H/.aitools/rules"; }
case_run empty seed_empty
check "empty: row n/a (no harness rules)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude rules|n/a (no harness rules)' ]"
parity empty

# ---------------------------------------------------------------------------
# Fan-out: every source, filter, preserved, rerun, edit, --force
# ---------------------------------------------------------------------------
seed_fanout() {
    manifest 'd.md|dotprofile' 'p.md|aitools' 's.md|shared'
    harness s.md '## shared s'; harness p.md '## project p'; harness d.md '## dot d'
    harness UP.MD '## upper-case extension'
    harness s.md.bak.2026-10-22T010203Z 'old s'
    harness odd.bak.2026.md 'odd'; harness Up.MD.BAK.1 'upper backup'
    harness notes.txt 'not a rule'; harness .hidden.md 'hidden'
    mkdir -p "$H/.aitools/rules/subdir"; printf 'nested\n' > "$H/.aitools/rules/subdir/nested.md"
    deployed mine.md 'mine'
}
case_run fanout seed_fanout
check "fanout: exit 0, row 4 added" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude rules|4 added' ]"
check "fanout: shared, aitools, dotprofile and upper-case .MD rules deployed" "grep -qx '## shared s' '$(R)/s.md' && grep -qx '## project p' '$(R)/p.md' && grep -qx '## dot d' '$(R)/d.md' && [ -f '$(R)/UP.MD' ]"
check "fanout: *.bak.* (any case), hidden, non-.md and nested files skipped" "[ ! -e '$(R)/s.md.bak.2026-10-22T010203Z' ] && [ ! -e '$(R)/odd.bak.2026.md' ] && [ ! -e '$(R)/Up.MD.BAK.1' ] && [ ! -e '$(R)/.hidden.md' ] && [ ! -e '$(R)/notes.txt' ] && [ ! -e '$(R)/nested.md' ] && [ ! -e '$(R)/subdir' ]"
check "fanout: non-rule file logged, manifest and backups silent" "grep -q 'Ignoring non-rule file in harness rules: notes.txt' '$C/sh.out' && ! grep -q 'aitools-rules-manifest' '$C/sh.out' && ! grep -q 's.md.bak' '$C/sh.out'"
check "fanout: unmanaged rule preserved" "grep -qx mine '$(R)/mine.md' && grep -q 'Preserved unmanaged rule: mine.md' '$C/sh.out'"
check "fanout: dotprofile-only rule not deployed (not in ~/.aitools/rules)" "[ ! -e '$(R)/only-dp.md' ]"
parity fanout
rerun
check "fanout rerun: row 4 verified, nothing written" "[ \"\$(nondetail)\" = 'OK|claude rules|4 verified' ] && ! ls '$(R)' | grep -q '\.bak\.'"
parity fanout-rerun
printf '## shared s\nlocal edit\n' > "$(R sh)/s.md"
if [ "$HAVE_PWSH" = "true" ]; then printf '## shared s\nlocal edit\n' > "$(R ps)/s.md"; fi
rerun
check "fanout edited, non-interactive: overwritten, backup kept, WARN row" "[ \"\$(nondetail)\" = 'WARN|claude rules|1 updated, 3 verified' ] && grep -qx '## shared s' '$(R)/s.md' && ls '$(R)' | grep -q '^s\.md\.bak\.'"
parity fanout-edited
printf '## shared s\nlocal edit 2\n' > "$(R sh)/s.md"
if [ "$HAVE_PWSH" = "true" ]; then printf '## shared s\nlocal edit 2\n' > "$(R ps)/s.md"; fi
rerun --force -Force
check "fanout --force: overwritten" "[ \"\$(rc)\" = 0 ] && grep -qx '## shared s' '$(R)/s.md' && [ \"\$(nondetail)\" = 'WARN|claude rules|1 updated, 3 verified' ]"
parity fanout-force

# ---------------------------------------------------------------------------
# Retired rules: pruned only when the copy matches a harness copy
# ---------------------------------------------------------------------------
seed_retired() {
    manifest 'a.md|shared' 'gone.md|retired' 'mine2.md|retired' 'old.md|retired'
    harness a.md 'rule a'
    harness gone.md.bak.2026-10-25T000000Z 'gone rule'   # deploy-harness retired it (backup, removed)
    harness old.md 'old rule'                            # retired, but still in ~/.aitools/rules
    deployed gone.md 'gone rule'; deployed old.md 'old rule'; deployed mine2.md 'my own'
}
case_run retired seed_retired
check "retired: exit 0, row 1 added, 2 removed (WARN: a kept file still loads)" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude rules|1 added, 2 removed' ]"
check "retired: copies removed, backups kept" "[ ! -e '$(R)/gone.md' ] && [ ! -e '$(R)/old.md' ] && ls '$(R)' | grep -q '^gone\.md\.bak\.' && ls '$(R)' | grep -q '^old\.md\.bak\.'"
check "retired: removals in DETAIL rows" "row 'DETAIL|claude rules|removed: gone.md' && row 'DETAIL|claude rules|removed: old.md'"
check "retired: a retired rule still in ~/.aitools/rules is not fanned out" "grep -q 'Not fanned out: old.md (retired in the rules manifest)' '$C/sh.out' && ! row 'DETAIL|claude rules|added: old.md'"
check "retired: user file with a retired name kept, ACTION row" "grep -qx 'my own' '$(R)/mine2.md' && row 'ACTION||Claude Code still loads retired rules in ~/.claude/rules: mine2.md -- delete them unless you wrote them'"
parity retired
case_run retired-dry seed_retired --dry-run -DryRun
check "retired dry run: nothing written, row dry run, removal previewed" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude rules|dry run (no files written)' ] && [ -f '$(R)/gone.md' ] && [ -f '$(R)/old.md' ] && [ ! -e '$(R)/a.md' ] && grep -q 'DRY RUN\] Would back up and remove gone.md' '$C/sh.out'"
parity retired-dry

# A retired name holding [ ]: removed only with its backup (review RC-1: a
# wildcard-based backup step could report success without a copy)
seed_retired_bracket() {
    manifest 'a.md|shared' '[r].md|retired'
    harness a.md 'rule a'
    harness '[r].md.bak.2026-10-25T000000Z' 'r rule'
    deployed '[r].md' 'r rule'
}
case_run retired-bracket seed_retired_bracket
check "retired [r].md: removed, backup kept" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude rules|1 added, 1 removed' ] && [ ! -e '$(R)/[r].md' ] && ls '$(R)' | grep -q '^\[r\]\.md\.bak\.'"
parity retired-bracket

# A retired name whose copy differs only in case (Gone.md for gone.md)
seed_retired_case() {
    manifest 'a.md|shared' 'gone.md|retired'
    harness a.md 'rule a'
    harness gone.md.bak.2026-10-25T000000Z 'gone rule'
    deployed Gone.md 'gone rule'
}
case_run retired-case seed_retired_case
check "retired, case differs: the copy found and removed under its own name" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude rules|1 added, 1 removed' ] && [ ! -e '$(R)/Gone.md' ] && row 'DETAIL|claude rules|removed: Gone.md' && ls '$(R)' | grep -q '^Gone\.md\.bak\.'"
parity retired-case

# ---------------------------------------------------------------------------
# Manifest absent, bad header, invalid lines
# ---------------------------------------------------------------------------
seed_nomanifest() { harness a.md 'rule a'; harness b.md 'rule b'; }
case_run nomanifest seed_nomanifest
check "no manifest: everything fanned out, adopt not offered" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'OK|claude rules|2 added' ] && grep -q 'No rules manifest' '$C/sh.out' && logged 'claude rules: a.md source=unknown adopt=none'"
parity nomanifest

seed_badheader() {
    mkdir -p "$H/.aitools/rules"
    printf '# aitools rules manifest v2\nx.md\tretired\n' > "$H/.aitools/rules/.aitools-rules-manifest"
    harness a.md 'rule a'; harness x.md.bak.2026-10-25T000000Z 'x rule'; deployed x.md 'x rule'
}
case_run badheader seed_badheader
check "bad header: fanned out, nothing retired, WARN + ACTION" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude rules|1 added' ] && [ -f '$(R)/x.md' ] && row 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest'"
parity badheader

seed_invalid() { manifest 'bad.txt|shared' 'a.md|unknown' 'b.md|shared'; harness a.md 'rule a'; harness b.md 'rule b'; }
case_run invalid seed_invalid
check "invalid lines: warned, rules still fanned out" "[ \"\$(rc)\" = 0 ] && [ \"\$(nondetail)\" = 'WARN|claude rules|2 added' ] && grep -q 'line ignored: bad.txt<TAB>shared' '$C/sh.out' && logged 'claude rules: a.md source=unknown adopt=none'"
parity invalid

# ---------------------------------------------------------------------------
# Adopt target from the manifest source
# ---------------------------------------------------------------------------
seed_adoptmap() {
    manifest 'd.md|dotprofile' 'p.md|aitools' 's.md|shared' 'z.md|dotprofile'
    harness s.md '## shared s'; harness p.md '## project p'; harness d.md '## dot d'; harness z.md '## z'
    printf '## shared s\n' > "$A/shared/rules/s.md"; printf '## project p\n' > "$A/.claude/rules/p.md"
}
case_run adoptmap seed_adoptmap
for lang in sh ps; do
    if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
    check "adopt map $lang: shared -> aitools shared/rules" "logged 'claude rules: s.md source=shared adopt=' $lang && logged '/shared/rules/s.md' $lang"
    check "adopt map $lang: aitools -> aitools .claude/rules" "logged 'claude rules: p.md source=aitools adopt=' $lang && logged '/.claude/rules/p.md' $lang"
    check "adopt map $lang: dotprofile -> dotprofile claude/rules" "logged 'claude rules: d.md source=dotprofile adopt=$DP/claude/rules/d.md' $lang"
    check "adopt map $lang: no repo file -> none" "logged 'claude rules: z.md source=dotprofile adopt=none' $lang"
done

if $HAVE_PTY; then
    for lang in sh ps; do
        if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
        printf '## dot d\nmy edit %s\n' "$lang" > "$C/$lang/.claude/rules/d.md"
        printf '## project p\nmy edit %s\n' "$lang" > "$C/$lang/.claude/rules/p.md"
        run_pty "$lang" 'a\na\n'
        check "adopt $lang: dotprofile rule written to the dotprofile and committed" "grep -qx 'my edit $lang' '$DP/claude/rules/d.md' && git -C '$DP' log -1 --format=%s | grep -q 'd.md'"
        check "adopt $lang: aitools rule written to the aitools working tree" "grep -qx 'my edit $lang' '$A/.claude/rules/p.md'"
        check "adopt $lang: DETAIL rows" "row 'DETAIL|claude rules|accept & adopt: d.md' $lang && row 'DETAIL|claude rules|accept & adopt: p.md' $lang"
        # abort: exit 2 from the library, no claude rules row, the local file kept
        printf '## shared s\nlocal %s\n' "$lang" > "$C/$lang/.claude/rules/s.md"
        run_pty "$lang" 'x\n'
        check "abort $lang: exit 2, no claude rules row, local file kept" "[ \"\$(rc $lang)\" = 2 ] && [ -z \"\$(nondetail $lang)\" ] && grep -qx 'local $lang' '$C/$lang/.claude/rules/s.md'"
    done
else
    skip "adopt and abort on a pty (python3 not found)"
fi
printf '## project p\n' > "$A/.claude/rules/p.md"

# Run from a package payload (no .git): no adopt into it, dotprofile adopt kept
seed_payload() {
    manifest 'd.md|dotprofile' 'p.md|aitools' 's.md|shared'
    harness s.md '## shared s'; harness p.md '## project p'; harness d.md '## dot d'
    printf '## shared s\n' > "$PAYLOAD/shared/rules/s.md"; printf '## project p\n' > "$PAYLOAD/.claude/rules/p.md"
}
REPO="$PAYLOAD"
case_run payload seed_payload
REPO="$A"
for lang in sh ps; do
    if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
    check "payload $lang: no adopt into a checkout without .git" "logged 'claude rules: s.md source=shared adopt=none' $lang && logged 'claude rules: p.md source=aitools adopt=none' $lang && logged 'claude rules: d.md source=dotprofile adopt=$DP/claude/rules/d.md' $lang"
done
parity payload

# ---------------------------------------------------------------------------
# Names: [ ] in a name, case-only duplicates, dangling symlink, unreadable dir
# ---------------------------------------------------------------------------
seed_bracket() { manifest '[x].md|shared'; harness '[x].md' 'bracket'; }
case_run bracket seed_bracket
check "bracket name: deployed" "[ \"\$(nondetail)\" = 'OK|claude rules|1 added' ] && grep -qx bracket '$(R)/[x].md'"
rerun
check "bracket name: rerun verified" "[ \"\$(nondetail)\" = 'OK|claude rules|1 verified' ]"
parity bracket

if $CASE_SENSITIVE_FS; then
    seed_dupcase() { harness a.md 'lower'; harness A.md 'upper'; }
    case_run dupcase seed_dupcase
    check "case-only duplicate: the first wins, the second failed" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude rules|1 failed' ]"
    parity dupcase
else
    skip "case-only duplicate (case-insensitive file system)"
fi

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) skip "dangling symlink (Git Bash)" ;;
    *)
        seed_broken() { harness a.md 'rule a'; ln -s "$H/nowhere.md" "$H/.aitools/rules/broken.md"; }
        case_run broken seed_broken
        check "dangling symlink: failed, others deployed" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude rules|1 failed' ] && [ -f '$(R)/a.md' ]"
        parity broken ;;
esac

if $CAN_CHMOD_READ; then
    seed_unreadable() { harness a.md 'rule a'; chmod 000 "$H/.aitools/rules"; }
    case_run unreadable seed_unreadable
    check "unreadable harness dir: ERROR row, exit 1" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude rules|cannot read harness rules' ]"
    parity unreadable
    chmod 755 "$C/sh/.aitools/rules"
    if [ -d "$C/ps/.aitools/rules" ]; then chmod 755 "$C/ps/.aitools/rules"; fi

    # Unreadable manifest (review RC-2): the fan-out still runs, the final row is ERROR
    seed_manifest_unreadable() { manifest 'a.md|shared'; harness a.md 'rule a'; chmod 000 "$H/.aitools/rules/.aitools-rules-manifest"; }
    case_run manifest-unreadable seed_manifest_unreadable
    check "unreadable manifest: rules fanned out, ERROR rows, final row ERROR, exit 1" "[ \"\$(rc)\" = 1 ] && [ -f '$(R)/a.md' ] && row 'ERROR|claude rules|cannot read rules manifest' && row 'DETAIL|claude rules|failed: .aitools-rules-manifest' && [ \"\$(nondetail)\" = 'ERROR|claude rules|1 failed' ]"
    parity manifest-unreadable
else
    skip "unreadable harness dir and manifest (root or Git Bash)"
fi

# ~/.claude/rules cannot be created (a file is in the way): ERROR row, exit 1,
# the script still reaches its exit footer
seed_nocreate() { harness a.md 'rule a'; mkdir -p "$H/.claude"; printf 'not a dir\n' > "$H/.claude/rules"; }
case_run nocreate seed_nocreate
check "cannot create rules dir: ERROR row, exit 1, file untouched" "[ \"\$(rc)\" = 1 ] && [ \"\$(nondetail)\" = 'ERROR|claude rules|cannot create rules dir' ] && grep -qx 'not a dir' '$C/sh/.claude/rules' && grep -q 'FAILED with' '$C/sh.out'"
parity nocreate

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
