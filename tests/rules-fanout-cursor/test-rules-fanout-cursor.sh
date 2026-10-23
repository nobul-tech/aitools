#!/usr/bin/env bash
# test-rules-fanout-cursor.sh -- tests for step 4 of scripts/setup-user-cursor.sh:
# the harness rules fan-out ~/.aitools/rules/*.md -> ~/.cursor/rules/*.mdc
# (convert, skip *.bak.* and non-.md, preserve unmanaged files, review on diff),
# driven by the rules manifest: only shared/dotprofile rules are fanned out, and
# the .mdc of an aitools or retired rule is removed when the fan-out created it.
#
# Safe to re-run: every case runs the real script in its own temp HOME (removed
# on exit) with stub rg/agent on PATH, so no installer runs and the real
# ~/.cursor is never touched. With pwsh on PATH, ConvertTo-CursorRule in
# setup-user-cursor.ps1 is checked against the bash converter, and the manifest
# cases run step 4 of the .ps1 (step4-driver.ps1, isolated USERPROFILE) and
# compare its ~/.cursor/rules tree and summary rows with the .sh run (parity).
# Platform: macOS, Linux, Git Bash. Exit 1 if any case fails.
# Spec: .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H-Cursor/
# S3-H-Cursor-research.md; .claude/rules/managed-file-deployment.md.
#
# Usage: bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh [--help]

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 14' "$0"
    exit 0
fi

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
        PATH="$C/bin:$PATH" bash "$SCRIPT" "$@" < /dev/null > "$C/out" 2>&1
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
if command -v pwsh >/dev/null 2>&1; then
    for g in $GOLDEN; do
        pwsh -NoProfile -File "$HELPER_PS1" "$SCRIPT_PS1" "$GOLD/$g.md" "$GOLD/$g.ps1.got" > "$GOLD/$g.ps1.log" 2>&1
        check "parity ps1: $g" "cmp -s '$GOLD/$g.ps1.got' '$GOLD/$g.got'"
    done
    for g in paths nofm; do
        pwsh -NoProfile -File "$HELPER_PS1" "$SCRIPT_PS1" "$GOLD/$g.md" "$GOLD/$g.named.ps1.got" "$g.md" > "$GOLD/$g.named.ps1.log" 2>&1
        check "parity ps1: $g with marker" "cmp -s '$GOLD/$g.named.ps1.got' '$GOLD/$g.named.got'"
    done
else
    printf 'SKIP parity ps1 (pwsh not on PATH)\n'; SKIP=$((SKIP + 1))
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
check "empty: OK n/a row" "grep -qxF 'OK|cursor rules|n/a (no user-level rules)' '$C/summary'"
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
    check "dupcase: duplicate reported" "grep -Eq 'Skipped duplicate: (foo\.md -> foo\.mdc|Foo\.md -> Foo\.mdc)' '$C/out'"
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
# Commander decision 2026-10-22: Cursor gets user-level rules only (manifest
# source shared or dotprofile); the .mdc of an aitools or retired rule is
# removed when the fan-out created it. Each case seeds $H twice: $C/home for
# the .sh, $C/home-ps for step4-driver.ps1; the parity check compares the
# resulting ~/.cursor/rules trees and the "cursor rules" / ACTION summary rows.
DRIVER_PS1="$ROOT/tests/rules-fanout-cursor/step4-driver.ps1"
HAVE_PWSH=false
if command -v pwsh >/dev/null 2>&1; then HAVE_PWSH=true; fi

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

# A: user-level only, pruning, user files kept, manifest silent
seed_users() {
    manifest "d.md|dotprofile" "gone.md|retired" "old.md|retired" "p.md|aitools" "s.md|shared" "u.md|aitools"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Dotprofile rule\n' > "$H/.aitools/rules/d.md"
    printf -- '---\npaths:\n  - scripts/**\n---\n## Project rule\n' > "$H/.aitools/rules/p.md"
    printf '## Project rule u\n' > "$H/.aitools/rules/u.md"
    printf 'old shared\n' > "$H/.aitools/rules/s.md.bak.2026-10-22T010203Z"
    mkdir -p "$H/.cursor/rules"
    # p.mdc as PR #87 deployed it: the conversion, no marker
    conv "$H/.aitools/rules/p.md" > "$H/.cursor/rules/p.mdc"
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
check "users: shared and dotprofile rules fanned out with the marker" "grep -qF '${MARK}s.md;' '$R/s.mdc' && grep -qF '${MARK}d.md;' '$R/d.mdc'"
check "users: row 2 added (WARN: kept files still load)" "grep -qxF 'WARN|cursor rules|2 added' '$C/summary'"
check "users: ACTION row lists the kept files" "grep -qxF 'ACTION||Cursor still loads project/retired rules in ~/.cursor/rules: old.mdc, u.mdc -- delete them unless you wrote them' '$C/summary'"
check "users: aitools rule from PR #87 (no marker) removed" "[ ! -e '$R/p.mdc' ] && grep -q 'Removed p.mdc (aitools rule' '$C/out'"
check "users: its backup kept" "ls '$R' | grep -q '^p\.mdc\.bak\.'"
check "users: retired rule with the marker removed" "[ ! -e '$R/gone.mdc' ] && ls '$R' | grep -q '^gone\.mdc\.bak\.'"
check "users: removals in DETAIL rows" "grep -qxF 'DETAIL|cursor rules|removed: p.mdc' '$C/summary' && grep -qxF 'DETAIL|cursor rules|removed: gone.mdc' '$C/summary'"
check "users: user file with an aitools rule's name kept" "grep -q 'my own u' '$R/u.mdc' && grep -q 'Kept u.mdc' '$C/out'"
check "users: user file with a retired rule's name kept" "grep -q 'my own old' '$R/old.mdc' && grep -q 'Kept old.mdc' '$C/out'"
check "users: unrelated user rule kept" "grep -q 'mine' '$R/mine.mdc'"
check "users: no project rule fanned out" "[ ! -e '$R/u.mdc.bak' ] && ! grep -q 'aitools-fanout' '$R/u.mdc' && ! grep -q 'added: p.mdc' '$C/summary'"
check "users: *.bak.* source skipped silently" "! ls '$R' | grep -q '^s\.md\.bak' && ! grep -q 's.md.bak' '$C/out'"
check "users: manifest ignored silently" "! grep -q 'aitools-rules-manifest' '$C/out' && [ ! -e '$R/.aitools-rules-manifest' ]"
parity users seed_users
if [ "$HAVE_PWSH" = "true" ]; then
    check "users: .ps1 ignores the manifest silently" "[ -s '$C/out-ps' ] && ! grep -q 'aitools-rules-manifest' '$C/out-ps'"
fi
BAKS=$(ls "$R" | grep -c '\.bak\.')
run_script
check "users rerun: row 2 verified" "grep -qxF 'WARN|cursor rules|2 verified' '$C/summary'"
check "users rerun: nothing removed, no new backups" "! grep -q '^Removed\|] Removed' '$C/out' && [ \"\$(ls '$R' | grep -c '\.bak\.')\" = '$BAKS' ]"

# B: no manifest -> nothing fanned out, nothing removed, WARN + ACTION
seed_nomanifest() {
    mkdir -p "$H/.aitools/rules" "$H/.cursor/rules"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md"
    conv "$H/.aitools/rules/p.md" > "$H/.cursor/rules/p.mdc"
}
setup_case nomanifest
seed_nomanifest
run_script
check "nomanifest: exit 0" "[ \"\$(rc)\" = 0 ]"
check "nomanifest: WARN row" "grep -qxF 'WARN|cursor rules|no rules manifest' '$C/summary'"
check "nomanifest: ACTION row" "grep -q '^ACTION||Run aitools' '$C/summary'"
check "nomanifest: nothing fanned out, nothing removed" "[ \"\$(ls '$H/.cursor/rules')\" = 'p.mdc' ]"
parity nomanifest seed_nomanifest

# C: another first line -> same safe behaviour
seed_badheader() {
    mkdir -p "$H/.aitools/rules"
    printf '# aitools rules manifest v2\ns.md\tshared\n' > "$H/.aitools/rules/.aitools-rules-manifest"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
}
setup_case badheader
seed_badheader
run_script
check "badheader: exit 0" "[ \"\$(rc)\" = 0 ]"
check "badheader: WARN row" "grep -qxF 'WARN|cursor rules|rules manifest not v1' '$C/summary'"
check "badheader: nothing fanned out" "[ ! -e '$H/.cursor/rules' ]"
parity badheader seed_badheader

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
check "invalid: name matched case-insensitively" "[ -f '$H/.cursor/rules/lower.mdc' ]"
check "invalid: WARN row" "grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"
parity invalid seed_invalid

# E: only a project rule -> row reports the removal
seed_onlyremove() {
    manifest "p.md|aitools"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md"
    mkdir -p "$H/.cursor/rules"
    conv "$H/.aitools/rules/p.md" > "$H/.cursor/rules/p.mdc"
}
setup_case onlyremove
seed_onlyremove
run_script
check "onlyremove: exit 0" "[ \"\$(rc)\" = 0 ]"
check "onlyremove: OK row 1 removed" "grep -qxF 'OK|cursor rules|1 removed' '$C/summary'"
check "onlyremove: p.mdc removed, backup kept" "[ ! -e '$H/.cursor/rules/p.mdc' ] && ls '$H/.cursor/rules' | grep -q '^p\.mdc\.bak\.'"
parity onlyremove seed_onlyremove

# E2: a name with [ ] is backed up before removal (PS1 Backup-File is wildcard-based)
seed_bracket() {
    manifest "br[1].md|aitools"
    printf '## Bracket rule\n' > "$H/.aitools/rules/br[1].md"
    mkdir -p "$H/.cursor/rules"
    conv "$H/.aitools/rules/br[1].md" "br[1].md" > "$H/.cursor/rules/br[1].mdc"
}
setup_case bracket
seed_bracket
run_script
check "bracket: exit 0" "[ \"\$(rc)\" = 0 ]"
check "bracket: removed with a backup" "[ ! -e '$H/.cursor/rules/br[1].mdc' ] && ls '$H/.cursor/rules' | grep -qF 'br[1].mdc.bak.'"
parity bracket seed_bracket

# E3 (review finding 1): #87 files of rules edited or retired since that run
# are recognised through the backups deploy-harness left beside the harness copy
seed_edited() {
    manifest "e.md|aitools" "r.md|retired"
    mkdir -p "$H/.cursor/rules"
    printf '## Edited rule, old text\n' > "$H/.aitools/rules/e.md.bak.2026-10-21T010203Z"
    printf '## Edited rule, new text\n' > "$H/.aitools/rules/e.md"
    printf '## Retired rule\n' > "$H/.aitools/rules/r.md.bak.2026-10-22T010203Z"
    conv "$H/.aitools/rules/e.md.bak.2026-10-21T010203Z" > "$H/.cursor/rules/e.mdc"
    conv "$H/.aitools/rules/r.md.bak.2026-10-22T010203Z" > "$H/.cursor/rules/r.mdc"
}
setup_case edited
seed_edited
run_script
check "edited: exit 0" "[ \"\$(rc)\" = 0 ]"
check "edited: old copy of an edited aitools rule removed" "[ ! -e '$H/.cursor/rules/e.mdc' ] && grep -q 'Removed e.mdc (aitools rule.*e.md.bak.2026-10-21T010203Z' '$C/out'"
check "edited: old copy of a retired rule removed" "[ ! -e '$H/.cursor/rules/r.mdc' ]"
check "edited: OK row 2 removed" "grep -qxF 'OK|cursor rules|2 removed' '$C/summary'"
parity edited seed_edited

# E4 (review finding 3): marker text after a body --- line is not the marker
seed_bodymark() {
    manifest "p.md|aitools"
    printf '## Project rule\n' > "$H/.aitools/rules/p.md"
    mkdir -p "$H/.cursor/rules"
    printf -- '---\nalwaysApply: true\n---\nmine\n---\n%sp.md; edit that rule, not this file -->\n' "$MARK" > "$H/.cursor/rules/p.mdc"
}
setup_case bodymark
seed_bodymark
run_script
check "bodymark: exit 0" "[ \"\$(rc)\" = 0 ]"
check "bodymark: user file kept" "grep -q '^mine' '$H/.cursor/rules/p.mdc' && grep -q 'Kept p.mdc' '$C/out'"
check "bodymark: WARN row and ACTION" "grep -qxF 'WARN|cursor rules|n/a (no user-level rules)' '$C/summary' && grep -q '^ACTION||Cursor still loads project/retired rules in ~/.cursor/rules: p.mdc' '$C/summary'"
parity bodymark seed_bodymark

# E5 (review finding 4): a manifest ending in a lone CR -- both scripts reject the line
seed_lonecr() {
    mkdir -p "$H/.aitools/rules"
    printf '# aitools rules manifest v1\na.md\tshared\nb.md\tshared\r' > "$H/.aitools/rules/.aitools-rules-manifest"
    printf '## a\n' > "$H/.aitools/rules/a.md"
    printf '## b\n' > "$H/.aitools/rules/b.md"
}
setup_case lonecr
seed_lonecr
run_script
check "lonecr: last line ignored with a warning" "grep -q 'line ignored: b.md<TAB>shared' '$C/out' && [ ! -e '$H/.cursor/rules/b.mdc' ]"
check "lonecr: WARN row 1 added" "grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"
parity lonecr seed_lonecr

# F: dry run -> removal only logged
setup_case dryprune
seed_onlyremove
run_script --dry-run
check "dryprune: exit 0" "[ \"\$(rc)\" = 0 ]"
check "dryprune: would-remove logged" "grep -q 'Would back up and remove p.mdc (aitools rule' '$C/out'"
check "dryprune: p.mdc still there, no backup" "[ \"\$(ls '$H/.cursor/rules')\" = 'p.mdc' ]"
parity dryprune seed_onlyremove -DryRun

# G: a user-level name in the manifest with no file -> warning
seed_missing() {
    manifest "s.md|shared" "t.md|shared"
    printf '## Shared rule\n' > "$H/.aitools/rules/s.md"
}
setup_case missingsrc
seed_missing
run_script
check "missingsrc: exit 0" "[ \"\$(rc)\" = 0 ]"
check "missingsrc: warned" "grep -q 'Not fanned out: t.md is in the rules manifest but not in' '$C/out'"
check "missingsrc: WARN row 1 added" "grep -qxF 'WARN|cursor rules|1 added' '$C/summary'"
parity missingsrc seed_missing

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
