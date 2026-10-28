#!/usr/bin/env bash
# test-rules-fanout-cursor.sh -- tests for step 4 of scripts/setup-user-cursor.sh:
# the harness rules fan-out ~/.aitools/rules/*.md -> ~/.cursor/rules/*.mdc
# (convert, skip *.bak.* and non-.md, preserve unmanaged files, review on diff),
# driven by the rules manifest: every rule except the retired ones is fanned out
# (shared, aitools and dotprofile alike; commander decision 2026-10-26), and the
# .mdc of a retired rule is removed when the fan-out created it. No manifest:
# everything fanned out, nothing removed. The review menu prompts on a pty (the
# deploy list is read on fd 3) and [x]abort exits 2.
#
# Safe to re-run: every case runs the real script in its own temp HOME (removed
# on exit) with stub rg/agent on PATH, so no installer runs and the real
# ~/.cursor is never touched. With pwsh on PATH, ConvertTo-CursorRule in
# setup-user-cursor.ps1 is checked against the bash converter, and the manifest
# cases run step 4 of the .ps1 (step4-driver.ps1, isolated USERPROFILE) and
# compare its ~/.cursor/rules tree and summary rows with the .sh run (parity).
# The pty cases need python3 (tests/managed-files/pty-run.py).
# Platform: macOS, Linux (not Git Bash: setup-user-cursor.sh's OS guard exits
# there, so the Windows CI job does not run this suite). Exit 1 if any case fails.
# Spec: .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H-Cursor/
# S3-H-Cursor-research.md; .claude/rules/managed-file-deployment.md.
#
# Usage: bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh [--bash-only] [--help]
#   --bash-only  skip the PowerShell runs (parity cases are reported SKIP)
#   AITOOLS_TEST_BASH=/bin/bash runs the script under that bash (CI: macOS 3.2)

set -uo pipefail

BASH_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --help|-h) perl -ne 'print if $. >= 2 && $. <= 25' "$0"; exit 0 ;;
        --bash-only) BASH_ONLY=true ;;
        *) printf 'Unknown option: %s (see --help)\n' "$arg"; exit 1 ;;
    esac
done
TB="${AITOOLS_TEST_BASH:-bash}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/setup-user-cursor.sh"
SCRIPT_PS1="$ROOT/scripts/setup-user-cursor.ps1"
HELPER_PS1="$ROOT/tests/rules-fanout-cursor/convert-rule.ps1"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

PASS=0
FAIL=0
SKIP=0

check() {  # name, condition (eval'd)
    if eval "$2"; then
        printf 'PASS %s\n' "$1"; PASS=$((PASS + 1))
    else
        printf 'FAIL %s\n' "$1"; FAIL=$((FAIL + 1))
        if [ -n "${C:-}" ] && [ -f "$C/out" ]; then
            perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$C/out" | tail -n 25
        fi
    fi
}

# setup_case <name>: fresh HOME and stub bin (rg, agent: version only)
setup_case() {
    C="$TMP_ROOT/$1"
    H="$C/home"
    mkdir -p "$H" "$C/bin"
    printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$C/bin/rg"
    printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$C/bin/agent"
    chmod +x "$C/bin/rg" "$C/bin/agent"
    : > "$C/summary"
}

# manifest <line>...: write ~/.aitools/rules/.aitools-rules-manifest (PR #100
# contract: v1 header, then "<name><TAB><source>" lines); each argument is one
# line with "|" standing for the TAB
manifest() {
    mkdir -p "$H/.aitools/rules"
    { printf '# aitools rules manifest v1\n'
      for l in "$@"; do printf '%s\n' "$l" | tr '|' '\t'; done
    } > "$H/.aitools/rules/.aitools-rules-manifest"
}

# seed_rules: a harness rules directory covering every source shape
seed_rules() {
    manifest "plain.md|shared" "scoped.md|dotprofile"
    mkdir -p "$H/.aitools/rules/subdir"
    printf '## Plain rule\n\nAlways loaded.\n' > "$H/.aitools/rules/plain.md"
    printf -- '---\npaths:\n  - scripts/**\n  - "shared/**"\n---\n\n## Scoped rule\n\nBody with a table:\n\n| a | b |\n|---|---|\n' > "$H/.aitools/rules/scoped.md"
    printf -- '---\ndescription: native cursor rule\nalwaysApply: false\n---\nNative body.\n' > "$H/.aitools/rules/native.mdc"
    printf 'not a rule\n' > "$H/.aitools/rules/notes.txt"
    # backups deploy-harness's deploy_managed_file leaves next to updated files
    printf 'old plain\n' > "$H/.aitools/rules/plain.md.bak.2026-10-22T010203Z"
    printf 'old odd\n' > "$H/.aitools/rules/odd.bak.2026.md"
    printf 'hidden\n' > "$H/.aitools/rules/.hidden.md"
    printf 'nested\n' > "$H/.aitools/rules/subdir/nested.md"
}

# run_script [args...]: run setup-user-cursor.sh non-interactively under the case HOME
run_script() {
    env HOME="$C/home" AITOOLS_LOG_DIR="$C/logs" AITOOLS_SUMMARY_FILE="$C/summary" \
        PATH="$C/bin:$PATH" "$TB" "$SCRIPT" "$@" < /dev/null > "$C/out" 2>&1
    echo $? > "$C/rc"
}

rc() { cat "$C/rc"; }
row() { grep -F "|cursor rules|" "$C/summary" | grep -v '^DETAIL' | tail -n 1; }
R="$TMP_ROOT/r"  # shorthand for the deployed rules dir, set per case

# --- converter golden cases (via the script's own function) ------------------
# Extract cursor_rule_from_md from the script and run it on sample inputs.
CONV="$TMP_ROOT/conv.sh"
perl -ne 'print if /^CURSOR_FANOUT_MARKER=/ || (/^cursor_rule_from_md\(\) \{/ .. /^\}/)' "$SCRIPT" > "$CONV"
GOLD="$TMP_ROOT/gold"
mkdir -p "$GOLD"
conv() { bash -c "source '$CONV'; cursor_rule_from_md '$1' '${2:-}'"; }

printf 'Body line\n' > "$GOLD/nofm.md"
printf -- '---\nalwaysApply: true\n---\nBody line\n' > "$GOLD/nofm.want"
printf -- '---\npaths:\n  - a/**\n  - b/**\n---\nBody\n' > "$GOLD/paths.md"
printf -- '---\nglobs:\n  - **/a/**\n  - **/b/**\nalwaysApply: false\n---\nBody\n' > "$GOLD/paths.want"
printf -- '---\npaths: src/**/*.ts\ndescription: x\n---\nB\n' > "$GOLD/inline.md"
printf -- '---\nglobs:\n  - **/src/**/*.ts\ndescription: x\nalwaysApply: false\n---\nB\n' > "$GOLD/inline.want"
printf -- '---\ndescription: keep\nalwaysApply: true\n---\nB\n' > "$GOLD/native.md"
printf -- '---\ndescription: keep\nalwaysApply: true\n---\nB\n' > "$GOLD/native.want"
printf -- '---\n---\nB\n' > "$GOLD/emptyfm.md"
printf -- '---\nalwaysApply: true\n---\nB\n' > "$GOLD/emptyfm.want"
printf '\xEF\xBB\xBF---\r\npaths:\r\n  - x/**\r\n---\r\nB\r\n' > "$GOLD/crlf.md"
printf -- '---\nglobs:\n  - **/x/**\nalwaysApply: false\n---\nB\n' > "$GOLD/crlf.want"
# N1: a YAML list at column 0 becomes indented items
printf -- '---\npaths:\n- scripts/**\n---\nB\n' > "$GOLD/col0.md"
printf -- '---\nglobs:\n  - **/scripts/**\nalwaysApply: false\n---\nB\n' > "$GOLD/col0.want"
# N2: a flow list and a brace pattern become block items (Cursor splits inline values on commas)
printf -- "---\npaths: [\"a/**\", 'b/**', src/**/*.{ts,tsx}]\n---\nB\n" > "$GOLD/flow.md"
printf -- '---\nglobs:\n  - **/a/**\n  - **/b/**\n  - **/src/**/*.{ts,tsx}\nalwaysApply: false\n---\nB\n' > "$GOLD/flow.want"
printf -- '---\npaths: src/**/*.{ts,tsx}\n---\nB\n' > "$GOLD/brace.md"
printf -- '---\nglobs:\n  - **/src/**/*.{ts,tsx}\nalwaysApply: false\n---\nB\n' > "$GOLD/brace.want"
# Already anchored, absolute, and ./ patterns
printf -- '---\npaths:\n  - "**/x"\n  - /abs/y\n  - ./rel/z\n---\nB\n' > "$GOLD/keep.md"
printf -- '---\nglobs:\n  - **/x\n  - /abs/y\n  - **/rel/z\nalwaysApply: false\n---\nB\n' > "$GOLD/keep.want"
# A YAML comment inside the paths: list does not end it
printf -- '---\npaths:\n  - a/**\n  # note\n  - b/**\n---\nB\n' > "$GOLD/comment.md"
printf -- '---\nglobs:\n  - **/a/**\n  - **/b/**\nalwaysApply: false\n---\nB\n' > "$GOLD/comment.want"
GOLDEN="nofm paths inline native emptyfm crlf col0 flow brace keep comment"

for g in $GOLDEN; do
    conv "$GOLD/$g.md" > "$GOLD/$g.got"
    check "convert: $g" "cmp -s '$GOLD/$g.got' '$GOLD/$g.want'"
done
# With a rule name the aitools-fanout marker is the line after the frontmatter
MARK='<!-- aitools-fanout: generated by setup-user-cursor from ~/.aitools/rules/'
conv "$GOLD/paths.md" "paths.md" > "$GOLD/paths.named.got"
printf -- '---\nglobs:\n  - **/a/**\n  - **/b/**\nalwaysApply: false\n---\n%spaths.md; edit that rule, not this file -->\nBody\n' "$MARK" > "$GOLD/paths.named.want"
check "convert: marker after frontmatter" "cmp -s '$GOLD/paths.named.got' '$GOLD/paths.named.want'"
conv "$GOLD/nofm.md" "nofm.md" > "$GOLD/nofm.named.got"
printf -- '---\nalwaysApply: true\n---\n%snofm.md; edit that rule, not this file -->\nBody line\n' "$MARK" > "$GOLD/nofm.named.want"
check "convert: marker without source frontmatter" "cmp -s '$GOLD/nofm.named.got' '$GOLD/nofm.named.want'"

# --- resolution: converted globs match a repo file as Cursor resolves them ----
# Model of the IDE matcher (Cursor 3.13.10 cursor-agent-exec main.js, aL/rL): a
# relative glob of ~/.cursor/rules/x.mdc is matched against the file path
# relative to the directory owning .cursor/rules, i.e. $HOME. Glob subset:
# **/, **, *, ?, {a,b}. The un-anchored form is checked too, to show the model
# reproduces the defect the anchoring fixes.
glob_match() {  # glob, path-relative-to-HOME -> exit 0 match, 1 no match, other = model error
    perl -e '
        my ($g, $p) = @ARGV; my $r = "";
        while (length $g) {
            if ($g =~ s#\A\*\*/##) { $r .= "(?:.*/)?" }
            elsif ($g =~ s#\A\*\*##) { $r .= ".*" }
            elsif ($g =~ s#\A\*##) { $r .= "[^/]*" }
            elsif ($g =~ s#\A\?##) { $r .= "[^/]" }
            elsif ($g =~ s#\A\{([^\}]*)\}##) { $r .= "(?:" . join("|", map { quotemeta } split /,/, $1) . ")" }
            else { $g =~ s#\A(.)##s; $r .= quotemeta($1) }
        }
        exit($p =~ /\A$r\z/ ? 0 : 1);
    ' "$1" "$2"
}
no_match() { glob_match "$1" "$2"; [ "$?" -eq 1 ]; }  # exactly "no match", not a model crash
check "resolve: **/scripts/** matches repos/aitools/scripts/a.sh" "glob_match '**/scripts/**' 'repos/aitools/scripts/a.sh'"
check "resolve: un-anchored scripts/** does not (the defect)" "no_match 'scripts/**' 'repos/aitools/scripts/a.sh'"
check "resolve: un-anchored scripts/** matches only ~/scripts (model sanity)" "glob_match 'scripts/**' 'scripts/a.sh'"
check "resolve: **/src/**/*.{ts,tsx} matches repos/x/src/a/b.tsx" "glob_match '**/src/**/*.{ts,tsx}' 'repos/x/src/a/b.tsx'"
check "resolve: **/CLAUDE.md matches repos/aitools/CLAUDE.md" "glob_match '**/CLAUDE.md' 'repos/aitools/CLAUDE.md'"
# Every glob the converter emits for the repo's own path-scoped rules resolves
for rf in "$ROOT"/.claude/rules/*.md; do
    grep -q '^paths:' "$rf" || continue
    conv "$rf" > "$GOLD/repo-$(basename "$rf").mdc"
done
# Frontmatter only (between the first two --- lines): bodies have bullet lists too
RESOLVE_BAD=$(perl -ne 'if ($. == 1) { $in = /^---/ ? 1 : 0; next } if ($in && /^---/) { $in = 0 } if ($in && /^  - (.*)$/) { print "$ARGV: $1\n" unless $1 =~ m{\A(?:\*\*/|/)} } close ARGV if eof' "$GOLD"/repo-*.mdc)
RESOLVE_COUNT=$(perl -ne 'if ($. == 1) { $in = /^---/ ? 1 : 0; next } if ($in && /^---/) { $in = 0 } print "x\n" if $in && /^  - /; close ARGV if eof' "$GOLD"/repo-*.mdc | wc -l | tr -d ' ')
check "resolve: the repo's path-scoped rules produce globs (count $RESOLVE_COUNT)" "[ \"$RESOLVE_COUNT\" -gt 0 ]"
check "resolve: every repo paths: glob is anchored (**/ or absolute)" "[ -z \"\$RESOLVE_BAD\" ]"
check "resolve: config-file-safety scripts/** resolves in a repo under HOME" "grep -qxF '  - **/scripts/**' '$GOLD/repo-config-file-safety.md.mdc' && glob_match '**/scripts/**' 'repos/aitools/scripts/setup-x.sh'"

# --- PS1 parity: ConvertTo-CursorRule gives the same bytes --------------------
if ! $BASH_ONLY && command -v pwsh >/dev/null 2>&1; then
    for g in $GOLDEN; do
        pwsh -NoProfile -File "$HELPER_PS1" "$SCRIPT_PS1" "$GOLD/$g.md" "$GOLD/$g.ps1.got" > "$GOLD/$g.ps1.log" 2>&1
        check "parity ps1: $g" "cmp -s '$GOLD/$g.ps1.got' '$GOLD/$g.got'"
    done
    for g in paths nofm; do
        pwsh -NoProfile -File "$HELPER_PS1" "$SCRIPT_PS1" "$GOLD/$g.md" "$GOLD/$g.named.ps1.got" "$g.md" > "$GOLD/$g.named.ps1.log" 2>&1
        check "parity ps1: $g with marker" "cmp -s '$GOLD/$g.named.ps1.got' '$GOLD/$g.named.got'"
    done
else
    printf 'SKIP parity ps1 (pwsh not on PATH or --bash-only)\n'; SKIP=$((SKIP + 1))
fi

# --- case: missing ~/.aitools/rules -> info + OK n/a, nothing created ----------
setup_case missing
run_script
check "missing: exit 0" "[ \"\$(rc)\" = 0 ]"
check "missing: OK n/a row" "grep -qxF 'OK|cursor rules|n/a (no harness rules)' '$C/summary'"
check "missing: no ~/.cursor/rules" "[ ! -e '$H/.cursor/rules' ]"
check "missing: info log" "grep -q 'No harness rules at' '$C/out'"

# --- case: ~/.aitools/rules with only an empty manifest -> OK n/a --------------
setup_case empty
manifest
run_script
check "empty: exit 0" "[ \"\$(rc)\" = 0 ]"
check "empty: OK n/a row" "grep -qxF 'OK|cursor rules|n/a (no harness rules)' '$C/summary'"
check "empty: manifest not logged" "! grep -q 'aitools-rules-manifest' '$C/out'"

# --- case: first run, rerun, edited target, --force ----------------------------
setup_case fanout
seed_rules
mkdir -p "$H/.cursor/rules"
printf -- '---\nalwaysApply: true\n---\nmine\n' > "$H/.cursor/rules/mine.mdc"
R="$H/.cursor/rules"
run_script
check "first: exit 0" "[ \"\$(rc)\" = 0 ]"
check "first: plain.md -> plain.mdc (alwaysApply true)" "[ \"\$(head -n 3 '$R/plain.mdc')\" = \"\$(printf -- '---\nalwaysApply: true\n---')\" ]"
check "first: scoped.md -> anchored globs list, alwaysApply false" "grep -qx 'globs:' '$R/scoped.mdc' && grep -qxF '  - **/scripts/**' '$R/scoped.mdc' && grep -qxF '  - **/shared/**' '$R/scoped.mdc' && grep -qx 'alwaysApply: false' '$R/scoped.mdc' && ! grep -q '^paths:' '$R/scoped.mdc'"
check "first: scoped body kept (table ---)" "grep -qxF '|---|---|' '$R/scoped.mdc'"
check "first: native.mdc source not fanned out (contract: *.md only)" "[ ! -e '$R/native.mdc' ] && grep -q 'Ignoring non-rule file in harness rules: native.mdc' '$C/out'"
check "first: notes.txt not fanned out" "[ ! -e '$R/notes.txt' ] && grep -q 'Ignoring non-rule file in harness rules: notes.txt' '$C/out'"
check "first: *.bak.* backups skipped" "! ls '$R' | grep -q '^plain\.md\.bak\.' && [ ! -e '$R/odd.bak.2026.mdc' ] && ! grep -q 'odd.bak' '$C/out'"
check "first: no .md left in target" "[ ! -e '$R/plain.md' ] && [ ! -e '$R/scoped.md' ]"
check "first: hidden file not deployed" "[ ! -e '$R/.hidden.mdc' ] && [ ! -e '$R/.hidden.md' ]"
check "first: subdirectory not deployed" "[ ! -e '$R/subdir' ] && grep -q 'Ignoring non-rule file in harness rules: subdir' '$C/out'"
check "first: user rule preserved" "[ \"\$(cat '$R/mine.mdc')\" = \"\$(printf -- '---\nalwaysApply: true\n---\nmine')\" ] && grep -q 'Preserved unmanaged rule: mine.mdc' '$C/out'"
check "first: OK row 2 added" "grep -qxF 'OK|cursor rules|2 added' '$C/summary'"

run_script
check "rerun: exit 0" "[ \"\$(rc)\" = 0 ]"
check "rerun: OK row 2 verified" "grep -qxF 'OK|cursor rules|2 verified' '$C/summary'"
check "rerun: no backups (nothing written)" "! ls '$R' | grep -q '\.bak\.'"

printf 'local edit\n' >> "$R/plain.mdc"
run_script
check "edited: exit 0" "[ \"\$(rc)\" = 0 ]"
check "edited: non-interactive overwrite" "grep -q 'plain.mdc -- overwriting (non-interactive)' '$C/out'"
check "edited: source content restored" "! grep -q 'local edit' '$R/plain.mdc'"
check "edited: backup kept, not loadable by Cursor" "ls '$R' | grep -q '^plain\.mdc\.bak\.' && ! ls '$R' | grep '\.bak\.' | grep -q '\.mdc$'"
check "edited: row reports 1 updated" "row | grep -q '|cursor rules|1 updated, 1 verified'"
check "edited: backup not reported as preserved" "! grep -q 'Preserved unmanaged rule: plain.mdc.bak' '$C/out'"

printf 'local edit 2\n' >> "$R/scoped.mdc"
run_script --force
check "force: exit 0" "[ \"\$(rc)\" = 0 ]"
check "force: overwrite (--force)" "grep -q 'scoped.mdc -- overwriting (--force)' '$C/out'"
check "force: source content restored" "! grep -q 'local edit 2' '$R/scoped.mdc'"

# --- case: an x.mdc next to x.md is not a second source (contract: *.md only) -
setup_case mdcnext
manifest "dup.md|shared"
printf 'from md\n' > "$H/.aitools/rules/dup.md"
printf -- '---\nalwaysApply: true\n---\nfrom mdc\n' > "$H/.aitools/rules/dup.mdc"
run_script
check "mdcnext: exit 0" "[ \"\$(rc)\" = 0 ]"
check "mdcnext: dup.mdc deployed from dup.md" "grep -q 'from md' '$H/.cursor/rules/dup.mdc'"
check "mdcnext: OK row 1 added" "grep -qxF 'OK|cursor rules|1 added' '$C/summary'"

# --- case: names differing only in case (Foo.md, foo.md) are one target -------
# Possible only on a case-sensitive file system (Linux); APFS/NTFS hold one file.
setup_case dupcase
manifest "Foo.md|shared"
printf 'upper\n' > "$H/.aitools/rules/Foo.md"
printf 'lower\n' > "$H/.aitools/rules/foo.md"
if [ "$(ls "$H/.aitools/rules" | wc -l | tr -d ' ')" -lt 2 ]; then
    printf 'SKIP dupcase (case-insensitive file system holds one file)\n'; SKIP=$((SKIP + 1))
else
    run_script
    check "dupcase: exit 1" "[ \"\$(rc)\" = 1 ]"
    # Ordinal (byte) order on every locale: Foo.md (0x46) is deployed, foo.md
    # (0x66) is the duplicate (until the fix the glob's LC_COLLATE order decided)
    check "dupcase: duplicate reported" "grep -q 'Skipped duplicate: foo\.md -> foo\.mdc' '$C/out'"
    check "dupcase: Foo.md deployed (ordinal order)" "[ -f '$H/.cursor/rules/Foo.mdc' ] && [ ! -e '$H/.cursor/rules/foo.mdc' ]"
    check "dupcase: ERROR row" "grep -qxF 'ERROR|cursor rules|1 failed' '$C/summary'"
fi

# --- case: dangling symlink in the source -> error, not a silent skip ---------
setup_case broken
manifest "broken.md|shared" "good.md|shared"
printf 'ok\n' > "$H/.aitools/rules/good.md"
ln -s "$H/nowhere.md" "$H/.aitools/rules/broken.md"
run_script
check "broken: exit 1" "[ \"\$(rc)\" = 1 ]"
check "broken: dangling symlink logged" "grep -q 'Failed: broken.md: dangling symlink' '$C/out'"
check "broken: good rule still deployed" "[ -f '$H/.cursor/rules/good.mdc' ]"
check "broken: ERROR row" "grep -qxF 'ERROR|cursor rules|1 failed' '$C/summary'"

# --- case: unreadable harness rules dir -> ERROR row (PS1 parity) -------------
setup_case unreadable
manifest "x.md|shared"
printf 'x\n' > "$H/.aitools/rules/x.md"
chmod 000 "$H/.aitools/rules"
if [ -r "$H/.aitools/rules" ]; then
    # root or Git Bash: chmod 000 does not block reads here
    printf 'SKIP unreadable (chmod 000 does not block reads in this environment)\n'; SKIP=$((SKIP + 1))
else
    run_script
    check "unreadable: exit 1" "[ \"\$(rc)\" = 1 ]"
    check "unreadable: ERROR row" "grep -qxF 'ERROR|cursor rules|cannot read harness rules' '$C/summary'"
fi
chmod 755 "$H/.aitools/rules"

# --- case: --- inside a frontmatter value -> warning (Cursor would misparse) ---
setup_case descdash
manifest "dd.md|shared"
printf -- '---\ndescription: before --- after\npaths:\n  - x/**\n---\nBody\n' > "$H/.aitools/rules/dd.md"
run_script
check "descdash: exit 0 (warning only)" "[ \"\$(rc)\" = 0 ]"
check "descdash: misparse warned" "grep -q 'dd.mdc: Cursor would not see alwaysApply' '$C/out'"
check "descdash: row promoted to WARN" "grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"

# --- case: dry run -> nothing written ------------------------------------------
setup_case dry
seed_rules
run_script --dry-run
check "dry: exit 0" "[ \"\$(rc)\" = 0 ]"
check "dry: no ~/.cursor/rules files" "[ ! -e '$H/.cursor/rules/plain.mdc' ]"
check "dry: would-create logged" "grep -q 'Would create: plain.mdc' '$C/out'"
check "dry: dry-run row" "grep -q '|cursor rules|dry run (no files written)' '$C/summary'"

# --- case: dry run with a failure -> ERROR row, not OK ------------------------
setup_case drydup
manifest "d.md|shared" "gone.md|shared"
printf 'a\n' > "$H/.aitools/rules/d.md"
ln -s "$H/nowhere.md" "$H/.aitools/rules/gone.md"
run_script --dry-run
check "drydup: exit 1" "[ \"\$(rc)\" = 1 ]"
check "drydup: ERROR row" "grep -qxF 'ERROR|cursor rules|1 failed (dry run)' '$C/summary'"

# --- manifest cases: run by the .sh, then (pwsh on PATH) by the .ps1's step 4 --
# Commander decision 2026-10-26 (RECONCILE Q3, reverses PR #110's filter):
# Cursor gets every rule the manifest does not retire; the .mdc of a retired
# rule is removed when the fan-out created it. Each case seeds $H twice: $C/home for
# the .sh, $C/home-ps for step4-driver.ps1; the parity check compares the
# resulting ~/.cursor/rules trees and the "cursor rules" / ACTION summary rows.
DRIVER_PS1="$ROOT/tests/rules-fanout-cursor/step4-driver.ps1"
HAVE_PWSH=false
if ! $BASH_ONLY && command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi

# tree_sig DIR: one line per file under DIR, "<path> <md5>", backup time stamps
# normalized (.bak.TS) so two runs compare
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
rows() { grep -E '^(ACTION\||[A-Z]+\|cursor rules\|)' "$1" | grep -v '^DETAIL|cursor rules|verified'; }

run_ps1() {  # [args]: step 4 of setup-user-cursor.ps1 under $C/home-ps
    env HOME="$C/home-ps" USERPROFILE="$C/home-ps" AITOOLS_LOG_DIR="$C/logs-ps" \
        AITOOLS_SUMMARY_FILE="$C/summary-ps" pwsh -NoProfile -File "$DRIVER_PS1" "$SCRIPT_PS1" "$@" \
        < /dev/null > "$C/out-ps" 2>&1
    echo $? > "$C/rc-ps"
}

# parity <case> <seed function> [ps1 args]: reseed under $C/home-ps, run the
# .ps1, compare with the .sh run already in $C/home
parity() {
    if [ "$HAVE_PWSH" != "true" ]; then
        printf 'SKIP parity ps1: %s (pwsh not on PATH)\n' "$1"; SKIP=$((SKIP + 1)); return
    fi
    local case_name="$1" seed="$2" saved_h="$H"
    shift 2
    H="$C/home-ps"; mkdir -p "$H"; : > "$C/summary-ps"
    "$seed"
    run_ps1 "$@"
    H="$saved_h"
    tree_sig "$C/home/.cursor/rules" > "$C/tree-sh"
    tree_sig "$C/home-ps/.cursor/rules" > "$C/tree-ps"
    rows "$C/summary" > "$C/rows-sh"
    rows "$C/summary-ps" > "$C/rows-ps"
    check "parity ps1: $case_name: exit code" "[ \"\$(cat '$C/rc-ps')\" = \"\$(rc)\" ] || { tail -n 20 '$C/out-ps'; false; }"
    check "parity ps1: $case_name: ~/.cursor/rules" "cmp -s '$C/tree-sh' '$C/tree-ps' || { diff '$C/tree-sh' '$C/tree-ps'; false; }"
    check "parity ps1: $case_name: summary rows" "cmp -s '$C/rows-sh' '$C/rows-ps' || { diff '$C/rows-sh' '$C/rows-ps'; false; }"
}

# A: every source fanned out (aitools too), retired pruned, user files kept
seed_users() {
    manifest "d.md|dotprofile" "gone.md|retired" "old.md|retired" "p.md|aitools" "q.md|aitools" "s.md|shared" "u.md|aitools"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Dotprofile rule\n' > "$H/.aitools/rules/d.md"
    printf -- '---\npaths:\n  - scripts/**\n---\n## Project rule\n' > "$H/.aitools/rules/p.md"
    printf '## Project rule q\n' > "$H/.aitools/rules/q.md"
    printf '## Project rule u\n' > "$H/.aitools/rules/u.md"
    printf 'old shared\n' > "$H/.aitools/rules/s.md.bak.2026-10-22T010203Z"
    mkdir -p "$H/.cursor/rules"
    # p.mdc as PR #110 left it: removed (an aitools rule), its backup kept
    conv "$H/.aitools/rules/p.md" > "$H/.cursor/rules/p.mdc.bak.2026-10-23T010203Z"
    # q.mdc as this fan-out deploys it (with the marker): verified
    conv "$H/.aitools/rules/q.md" "q.md" > "$H/.cursor/rules/q.mdc"
    # gone.mdc as this fan-out deploys it: with the marker (its source is gone)
    printf '## Gone rule\n' > "$C/gone-src.md"
    conv "$C/gone-src.md" "gone.md" > "$H/.cursor/rules/gone.mdc"
    printf -- '---\nalwaysApply: true\n---\nmy own u\n' > "$H/.cursor/rules/u.mdc"
    printf -- '---\nalwaysApply: true\n---\nmy own old\n' > "$H/.cursor/rules/old.mdc"
    printf -- '---\nalwaysApply: true\n---\nmine\n' > "$H/.cursor/rules/mine.mdc"
}
setup_case users
seed_users
R="$H/.cursor/rules"
run_script
check "users: exit 0" "[ \"\$(rc)\" = 0 ]"
check "users: shared, dotprofile and aitools rules fanned out with the marker" "grep -qF '${MARK}s.md;' '$R/s.mdc' && grep -qF '${MARK}d.md;' '$R/d.mdc' && grep -qF '${MARK}p.md;' '$R/p.mdc' && grep -qF '${MARK}u.md;' '$R/u.mdc'"
check "users: aitools rule PR #110 pruned is re-added" "grep -qxF 'DETAIL|cursor rules|added: p.mdc' '$C/summary' && grep -qxF '  - **/scripts/**' '$R/p.mdc'"
check "users: aitools rule already fanned out is verified" "! grep -q '|cursor rules|.*: q.mdc' '$C/summary' && grep -qF '${MARK}q.md;' '$R/q.mdc'"
check "users: row 3 added, 1 updated, 1 removed, 1 verified (WARN: a kept file still loads)" "grep -qxF 'WARN|cursor rules|3 added, 1 updated, 1 removed, 1 verified' '$C/summary'"
check "users: ACTION row lists the kept retired file" "grep -qxF 'ACTION||Cursor still loads retired rules in ~/.cursor/rules: old.mdc -- delete them unless you wrote them' '$C/summary'"
check "users: retired rule with the marker removed, backup kept" "[ ! -e '$R/gone.mdc' ] && ls '$R' | grep -q '^gone\.mdc\.bak\.' && grep -q 'Removed gone.mdc (retired rule; aitools-fanout marker' '$C/out'"
check "users: removal is a tracker DETAIL row" "grep -qxF 'DETAIL|cursor rules|removed: gone.mdc' '$C/summary'"
check "users: user file at an aitools rule's name now the fan-out's (backup kept)" "grep -qF '${MARK}u.md;' '$R/u.mdc' && ls '$R' | grep -q '^u\.mdc\.bak\.' && grep -qxF 'DETAIL|cursor rules|updated: u.mdc' '$C/summary'"
check "users: user file with a retired rule's name kept" "grep -q 'my own old' '$R/old.mdc' && grep -q 'Kept old.mdc: the rules manifest retires old.md' '$C/out'"
check "users: unrelated user rule kept" "grep -q 'mine' '$R/mine.mdc' && grep -q 'Preserved unmanaged rule: mine.mdc' '$C/out'"
check "users: retired names logged as not fanned out only when present" "! grep -q 'Not fanned out: gone.md' '$C/out'"
check "users: *.bak.* source skipped silently" "! ls '$R' | grep -q '^s\.md\.bak' && ! grep -q 's.md.bak' '$C/out'"
check "users: manifest ignored silently" "! grep -q 'aitools-rules-manifest' '$C/out' && [ ! -e '$R/.aitools-rules-manifest' ]"
parity users seed_users
if [ "$HAVE_PWSH" = "true" ]; then
    check "users: .ps1 ignores the manifest silently" "[ -s '$C/out-ps' ] && ! grep -q 'aitools-rules-manifest' '$C/out-ps'"
fi
BAKS=$(ls "$R" | grep -c '\.bak\.')
run_script
check "users rerun: row 5 verified" "grep -qxF 'WARN|cursor rules|5 verified' '$C/summary'"
check "users rerun: nothing removed, no new backups" "! grep -q '^Removed\|] Removed' '$C/out' && [ \"\$(ls '$R' | grep -c '\.bak\.')\" = '$BAKS' ]"

# B: no manifest -> every rule fanned out, none removed, info log (Claude parity)
seed_nomanifest() {
    mkdir -p "$H/.aitools/rules" "$H/.cursor/rules"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md"
    # p.mdc as PR #87 deployed it (no marker): updated to the marker form
    conv "$H/.aitools/rules/p.md" > "$H/.cursor/rules/p.mdc"
}
setup_case nomanifest
seed_nomanifest
run_script
check "nomanifest: exit 0" "[ \"\$(rc)\" = 0 ]"
check "nomanifest: info log" "grep -q '\[info\] No rules manifest at .* -- every rule fanned out, none removed' '$C/out'"
# The row is WARN only because p.mdc was overwritten non-interactively (a warn)
check "nomanifest: no manifest WARN, no ACTION; row 1 added, 1 updated" "! grep -q '\[warn\] No rules manifest' '$C/out' && ! grep -q '^ACTION' '$C/summary' && grep -qxF 'WARN|cursor rules|1 added, 1 updated' '$C/summary' && grep -q 'p.mdc -- overwriting (non-interactive)' '$C/out'"
check "nomanifest: both rules fanned out with the marker" "grep -qF '${MARK}s.md;' '$H/.cursor/rules/s.mdc' && grep -qF '${MARK}p.md;' '$H/.cursor/rules/p.mdc'"
parity nomanifest seed_nomanifest

# C: another first line -> every rule fanned out + WARN log + ACTION
seed_badheader() {
    mkdir -p "$H/.aitools/rules"
    printf '# aitools rules manifest v2\ns.md\tretired\n' > "$H/.aitools/rules/.aitools-rules-manifest"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
}
setup_case badheader
seed_badheader
run_script
check "badheader: exit 0" "[ \"\$(rc)\" = 0 ]"
check "badheader: warned, with the ACTION's instruction" "grep -q '\[warn\] Rules manifest .*the first line is not.* -- Run aitools to rebuild ~/.aitools/rules and its manifest' '$C/out'"
check "badheader: ACTION row" "grep -qxF 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest' '$C/summary'"
check "badheader: fanned out (its retired line not read), row WARN 1 added" "[ -f '$H/.cursor/rules/s.mdc' ] && grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"
parity badheader seed_badheader

# C2: an unreadable manifest (a directory at its path) -> ERROR row, the
# fan-out continues, the manifest counted as a failed item
seed_badmanifest() {
    mkdir -p "$H/.aitools/rules/.aitools-rules-manifest"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
}
setup_case badmanifest
seed_badmanifest
run_script
check "badmanifest: exit 1" "[ \"\$(rc)\" = 1 ]"
check "badmanifest: ERROR row cannot read rules manifest" "grep -qxF 'ERROR|cursor rules|cannot read rules manifest' '$C/summary'"
check "badmanifest: fan-out continued" "[ -f '$H/.cursor/rules/s.mdc' ] && grep -qxF 'DETAIL|cursor rules|added: s.mdc' '$C/summary'"
check "badmanifest: manifest counted failed, final row ERROR 1 failed" "grep -qxF 'DETAIL|cursor rules|failed: .aitools-rules-manifest' '$C/summary' && [ \"\$(row)\" = 'ERROR|cursor rules|1 failed' ]"
parity badmanifest seed_badmanifest

# D: invalid lines ignored with a warning; case-insensitive names
seed_invalid() {
    manifest "Lower.md|shared" "LOWER.md|aitools" "../x.md|shared" "y.txt|shared" "z.md|bogus" "w.bak.1.md|shared" "nosource.md"
    printf '## Lower\n' > "$H/.aitools/rules/lower.md"
}
setup_case invalid
seed_invalid
run_script
check "invalid: exit 0" "[ \"\$(rc)\" = 0 ]"
check "invalid: 6 lines ignored with a warning" "[ \"\$(grep -c 'line ignored' '$C/out')\" = 6 ] && grep -q 'line ignored: ../x.md<TAB>shared' '$C/out'"
check "invalid: name matched case-insensitively" "[ -f '$H/.cursor/rules/lower.mdc' ] && ! grep -q 'Not fanned out: Lower.md is in the rules manifest' '$C/out'"
check "invalid: WARN row" "grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"
check "invalid: one ACTION row to rebuild the manifest" "[ \"\$(grep -cxF 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest' '$C/summary')\" = 1 ]"
parity invalid seed_invalid

# D2: an upper-case .MD extension is a rule (rule_name_kind is case-insensitive).
# No manifest here: the lib's manifest reader takes *.md names case-sensitively
# (a "Up.MD" line is ignored as invalid), so a listed Up.MD would add a warning.
seed_upper() {
    mkdir -p "$H/.aitools/rules"
    printf '## Upper ext\n' > "$H/.aitools/rules/Up.MD"
}
setup_case upper
seed_upper
run_script
check "upper: exit 0" "[ \"\$(rc)\" = 0 ]"
check "upper: Up.MD -> Up.mdc" "[ -f '$H/.cursor/rules/Up.mdc' ] && grep -qF '${MARK}Up.MD;' '$H/.cursor/rules/Up.mdc' && grep -qxF 'OK|cursor rules|1 added' '$C/summary'"
parity upper seed_upper

# E: only a retired rule -> row reports the removal (#87 file, matched through
# the backup deploy-harness left when it retired the rule)
seed_onlyremove() {
    manifest "p.md|retired"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md.bak.2026-10-22T010203Z"
    mkdir -p "$H/.cursor/rules"
    conv "$H/.aitools/rules/p.md.bak.2026-10-22T010203Z" > "$H/.cursor/rules/p.mdc"
}
setup_case onlyremove
seed_onlyremove
run_script
check "onlyremove: exit 0" "[ \"\$(rc)\" = 0 ]"
check "onlyremove: OK row 1 removed" "grep -qxF 'OK|cursor rules|1 removed' '$C/summary'"
check "onlyremove: p.mdc removed, backup with the same text kept" "[ ! -e '$H/.cursor/rules/p.mdc' ] && ls '$H/.cursor/rules' | grep -q '^p\.mdc\.bak\.' && grep -q 'Removed p.mdc (retired rule; same content as the conversion of p.md.bak.2026-10-22T010203Z; backup kept)' '$C/out'"
parity onlyremove seed_onlyremove

# E1: an aitools rule is no longer pruned (PR #110 removed it; FD-2)
seed_aitools() {
    manifest "p.md|aitools"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md"
    mkdir -p "$H/.cursor/rules"
    conv "$H/.aitools/rules/p.md" "p.md" > "$H/.cursor/rules/p.mdc"
}
setup_case aitools
seed_aitools
run_script
check "aitools: exit 0" "[ \"\$(rc)\" = 0 ]"
check "aitools: p.mdc kept and verified, nothing removed" "[ -f '$H/.cursor/rules/p.mdc' ] && grep -qxF 'OK|cursor rules|1 verified' '$C/summary' && ! ls '$H/.cursor/rules' | grep -q '\.bak\.'"
parity aitools seed_aitools

# E2: a name with [ ] is backed up before removal (Backup-File -LiteralPath)
seed_bracket() {
    manifest "br[1].md|retired"
    mkdir -p "$H/.cursor/rules"
    printf '## Bracket rule\n' > "$C/br-src.md"
    conv "$C/br-src.md" "br[1].md" > "$H/.cursor/rules/br[1].mdc"
}
setup_case bracket
seed_bracket
run_script
check "bracket: exit 0" "[ \"\$(rc)\" = 0 ]"
check "bracket: removed with a backup" "[ ! -e '$H/.cursor/rules/br[1].mdc' ] && ls '$H/.cursor/rules' | grep -qF 'br[1].mdc.bak.' && grep -qxF 'OK|cursor rules|1 removed' '$C/summary'"
parity bracket seed_bracket

# E3 (review finding 1): #87 files of rules edited before they were retired
# are recognised through the backups deploy-harness left beside the harness copy
seed_edited() {
    manifest "e.md|retired" "r.md|retired"
    mkdir -p "$H/.cursor/rules"
    printf '## Edited rule, old text\n' > "$H/.aitools/rules/e.md.bak.2026-10-21T010203Z"
    printf '## Edited rule, new text\n' > "$H/.aitools/rules/e.md.bak.2026-10-22T010203Z"
    printf '## Retired rule\n' > "$H/.aitools/rules/r.md.bak.2026-10-22T010203Z"
    conv "$H/.aitools/rules/e.md.bak.2026-10-21T010203Z" > "$H/.cursor/rules/e.mdc"
    conv "$H/.aitools/rules/r.md.bak.2026-10-22T010203Z" > "$H/.cursor/rules/r.mdc"
}
setup_case edited
seed_edited
run_script
check "edited: exit 0" "[ \"\$(rc)\" = 0 ]"
check "edited: old copy of an edited retired rule removed" "[ ! -e '$H/.cursor/rules/e.mdc' ] && grep -q 'Removed e.mdc (retired rule.*e.md.bak.2026-10-21T010203Z' '$C/out'"
check "edited: old copy of a retired rule removed" "[ ! -e '$H/.cursor/rules/r.mdc' ]"
check "edited: OK row 2 removed" "grep -qxF 'OK|cursor rules|2 removed' '$C/summary'"
parity edited seed_edited

# E4 (review finding 3): marker text after a body --- line is not the marker
seed_bodymark() {
    manifest "p.md|retired"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md"
    mkdir -p "$H/.cursor/rules"
    printf -- '---\nalwaysApply: true\n---\nmine\n---\n%sp.md; edit that rule, not this file -->\n' "$MARK" > "$H/.cursor/rules/p.mdc"
}
setup_case bodymark
seed_bodymark
run_script
check "bodymark: exit 0" "[ \"\$(rc)\" = 0 ]"
check "bodymark: retired harness copy not fanned out" "grep -q 'Not fanned out: p.md (retired in the rules manifest)' '$C/out'"
check "bodymark: user file kept" "grep -q '^mine' '$H/.cursor/rules/p.mdc' && grep -q 'Kept p.mdc' '$C/out'"
check "bodymark: WARN row (nothing to deploy) and ACTION" "grep -qxF 'WARN|cursor rules|n/a (nothing to deploy)' '$C/summary' && grep -qxF 'ACTION||Cursor still loads retired rules in ~/.cursor/rules: p.mdc -- delete them unless you wrote them' '$C/summary'"
parity bodymark seed_bodymark

# E5 (review finding 4): a manifest ending in a lone CR -- both scripts reject
# the line; the rule is still fanned out (only retired names are withheld)
seed_lonecr() {
    mkdir -p "$H/.aitools/rules"
    printf '# aitools rules manifest v1\na.md\tshared\nb.md\tretired\r' > "$H/.aitools/rules/.aitools-rules-manifest"
    printf '## a\n' > "$H/.aitools/rules/a.md"
    printf '## b\n' > "$H/.aitools/rules/b.md"
}
setup_case lonecr
seed_lonecr
run_script
check "lonecr: last line ignored with a warning (b.md not retired)" "grep -q 'line ignored: b.md<TAB>retired' '$C/out' && [ -f '$H/.cursor/rules/b.mdc' ]"
check "lonecr: WARN row 2 added" "grep -qxF 'WARN|cursor rules|2 added' '$C/summary'"
parity lonecr seed_lonecr

# F: dry run -> removal only logged
setup_case dryprune
seed_onlyremove
run_script --dry-run
check "dryprune: exit 0" "[ \"\$(rc)\" = 0 ]"
check "dryprune: would-remove logged" "grep -q 'Would back up and remove p.mdc (retired rule' '$C/out'"
check "dryprune: p.mdc still there, no backup" "[ \"\$(ls '$H/.cursor/rules')\" = 'p.mdc' ]"
parity dryprune seed_onlyremove -DryRun

# G: a listed rule with no file -> warning
seed_missing() {
    manifest "s.md|shared" "t.md|aitools"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
}
setup_case missingsrc
seed_missing
run_script
check "missingsrc: exit 0" "[ \"\$(rc)\" = 0 ]"
check "missingsrc: warned" "grep -q 'Not fanned out: t.md is in the rules manifest but not in' '$C/out'"
check "missingsrc: WARN row 1 added" "grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"
check "missingsrc: ACTION row to rebuild the manifest" "grep -qxF 'ACTION||Run aitools to rebuild ~/.aitools/rules and its manifest' '$C/summary'"
parity missingsrc seed_missing

# G2: a rule the manifest does not list is fanned out too (Claude parity, FAN-PLAN D1)
seed_unlisted() {
    manifest "s.md|shared"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## A rule the manifest does not list\n' > "$H/.aitools/rules/extra.md"
}
setup_case unlisted
seed_unlisted
run_script
check "unlisted: exit 0, both fanned out" "[ \"\$(rc)\" = 0 ] && [ -f '$H/.cursor/rules/extra.mdc' ] && grep -qxF 'OK|cursor rules|2 added' '$C/summary'"
parity unlisted seed_unlisted

# H: something that is not a directory at ~/.cursor/rules -> ERROR row
seed_nocreate() {
    manifest "s.md|shared"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    mkdir -p "$H/.cursor"
    printf 'a file\n' > "$H/.cursor/rules"
}
setup_case nocreate
seed_nocreate
run_script
check "nocreate: exit 1, ERROR row" "[ \"\$(rc)\" = 1 ] && [ \"\$(row)\" = 'ERROR|cursor rules|cannot create rules dir' ]"
check "nocreate: the file in the way kept" "grep -qx 'a file' '$H/.cursor/rules'"
parity nocreate seed_nocreate

# errors COUNT: the number of [error] log lines a run printed (sh: $C/out, ps: $C/out-ps)
errcount() { perl -ne '$n++ if /\[error\]/; END { print $n + 0 }' "$1"; }

# H1 (audit B1): a dangling symlink at a target name -- the deploy fails once,
# and validation does not report it a second time (.ps1 Test-Path -PathType Leaf
# is true for a dangling link); same error count in both shells
seed_dangtarget() {
    manifest "s.md|shared" "t.md|shared"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Shared rule t\n' > "$H/.aitools/rules/t.md"
    mkdir -p "$H/.cursor/rules"
    ln -s "$H/nowhere.mdc" "$H/.cursor/rules/s.mdc"
}
setup_case dangtarget
seed_dangtarget
run_script
check "dangtarget: exit 1, ERROR 1 failed, t.mdc deployed" "[ \"\$(rc)\" = 1 ] && [ \"\$(row)\" = 'ERROR|cursor rules|1 failed' ] && [ -f '$H/.cursor/rules/t.mdc' ]"
check "dangtarget: no second Validation error" "! grep -q 'Validation failed' '$C/out'"
parity dangtarget seed_dangtarget
if [ "$HAVE_PWSH" = "true" ]; then
    check "parity ps1: dangtarget: same number of error lines ($(errcount "$C/out"))" "[ \"\$(errcount '$C/out')\" = \"\$(errcount '$C/out-ps')\" ] && ! grep -q 'Validation failed' '$C/out-ps'"
fi

# H2 (review 3): a retired name is looked up case-insensitively in ~/.cursor/rules
# and reported under its on-disk name (Gone.md in the manifest, gone.mdc on disk)
seed_caseretired() {
    manifest "Gone.md|retired"
    mkdir -p "$H/.cursor/rules"
    printf '## Gone rule\n' > "$C/gone-src.md"
    conv "$C/gone-src.md" "gone.md" > "$H/.cursor/rules/gone.mdc"
}
setup_case caseretired
seed_caseretired
run_script
check "caseretired: removed under its on-disk name" "[ \"\$(rc)\" = 0 ] && [ ! -e '$H/.cursor/rules/gone.mdc' ] && grep -qxF 'DETAIL|cursor rules|removed: gone.mdc' '$C/summary' && grep -qxF 'OK|cursor rules|1 removed' '$C/summary'"
parity caseretired seed_caseretired

# H3 (audit B3): an unreadable source rule -- the reason is in the log line
seed_unreadsrc() {
    manifest "s.md|shared" "t.md|shared"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Shared rule t\n' > "$H/.aitools/rules/t.md"
    chmod 000 "$H/.aitools/rules/s.md"
}
setup_case unreadsrc
seed_unreadsrc
if [ -r "$H/.aitools/rules/s.md" ]; then
    printf 'SKIP unreadsrc (chmod 000 does not block reads in this environment)\n'; SKIP=$((SKIP + 1))
else
    run_script
    check "unreadsrc: exit 1, ERROR 1 failed, the other rule deployed" "[ \"\$(rc)\" = 1 ] && [ \"\$(row)\" = 'ERROR|cursor rules|1 failed' ] && [ -f '$H/.cursor/rules/t.mdc' ]"
    check "unreadsrc: the reason is in the log line, no raw shell error" "grep -q '\[error\] Failed: s.md: cannot read .* -- permission denied' '$C/out' && ! perl -pe 's/\e\[[0-9;]*m//g' '$C/out' | grep -v '^\[' | grep -qi 'permission denied'"
    parity unreadsrc seed_unreadsrc
    chmod 644 "$C/home/.aitools/rules/s.md"
    if [ -f "$C/home-ps/.aitools/rules/s.md" ]; then chmod 644 "$C/home-ps/.aitools/rules/s.md"; fi
fi

# --- pty: the review menu prompts (deploy list on fd 3) and [x]abort exits 2 --
# Before the fd-3 fix the bash loop read its list from a here-string on stdin,
# so tty_interactive ([ -t 0 ]) was false and a changed .mdc was overwritten
# without a prompt even on a terminal.
PTY="$ROOT/tests/managed-files/pty-run.py"
HAVE_PTY=false
if command -v python3 >/dev/null 2>&1 && [ -f "$PTY" ]; then HAVE_PTY=true; fi

# run_pty LANG INPUT: LANG sh runs the script, ps runs step4-driver.ps1, on a
# pty under $C/home (sh) or $C/home-ps (ps); keystrokes INPUT
run_pty() {
    local lang="$1" input="$2" h
    if [ "$lang" = sh ]; then h="$C/home"; else h="$C/home-ps"; fi
    : > "$C/summary-$lang"
    if [ "$lang" = sh ]; then
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$C/logs-$lang" \
            AITOOLS_SUMMARY_FILE="$C/summary-$lang" PATH="$C/bin:$PATH" \
            python3 "$PTY" --input "$input" --log "$C/pty-$lang.out" -- "$TB" "$SCRIPT" > /dev/null 2>&1
    else
        env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$C/logs-$lang" \
            AITOOLS_SUMMARY_FILE="$C/summary-$lang" \
            python3 "$PTY" --input "$input" --log "$C/pty-$lang.out" -- pwsh -NoProfile -File "$DRIVER_PS1" "$SCRIPT_PS1" > /dev/null 2>&1
    fi
    echo $? > "$C/rc-$lang"
}
seed_pty() {
    manifest "s.md|shared" "t.md|aitools"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Project rule\n' > "$H/.aitools/rules/t.md"
    mkdir -p "$H/.cursor/rules"
    conv "$H/.aitools/rules/s.md" "s.md" > "$H/.cursor/rules/s.mdc"
    printf 'my edit\n' >> "$H/.cursor/rules/s.mdc"
    conv "$H/.aitools/rules/t.md" "t.md" > "$H/.cursor/rules/t.mdc"
}
if $HAVE_PTY; then
    setup_case pty
    seed_pty
    if [ "$HAVE_PWSH" = "true" ]; then saved_h="$H"; H="$C/home-ps"; mkdir -p "$H"; seed_pty; H="$saved_h"; fi
    for lang in sh ps; do
        if [ "$lang" = ps ] && [ "$HAVE_PWSH" != "true" ]; then continue; fi
        if [ "$lang" = sh ]; then PR="$C/home/.cursor/rules"; else PR="$C/home-ps/.cursor/rules"; fi
        run_pty "$lang" 's\n'
        check "pty $lang: the review menu prompted" "grep -q '\[s\]kip' '$C/pty-$lang.out'"
        check "pty $lang: [s]kip keeps the local edit, row WARN 1 skipped" "grep -qx 'my edit' '$PR/s.mdc' && [ \"\$(grep -F '|cursor rules|' '$C/summary-$lang' | grep -v '^DETAIL' | tail -n 1)\" = 'WARN|cursor rules|1 skipped (user review)' ]"
        run_pty "$lang" 'x\n'
        check "pty $lang: [x]abort exits 2, no cursor rules row, local file kept" "[ \"\$(cat '$C/rc-$lang')\" = 2 ] && ! grep -F '|cursor rules|' '$C/summary-$lang' | grep -qv '^DETAIL' && grep -qx 'my edit' '$PR/s.mdc'"
    done
    if [ "$HAVE_PWSH" != "true" ]; then printf 'SKIP pty ps (pwsh not on PATH)\n'; SKIP=$((SKIP + 1)); fi
else
    printf 'SKIP pty review menu and abort (python3 not found)\n'; SKIP=$((SKIP + 1))
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
