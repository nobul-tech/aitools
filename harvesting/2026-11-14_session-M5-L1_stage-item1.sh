#!/usr/bin/env bash
# stage-item1.sh -- stage only the item-1 (spinner) changes: the spinner hunks of
# scripts/aitools-lib.sh, plus the whole files that belong to item 1.
set -euo pipefail
WT="C:/Users/jdpal/repos/aitools/.claude/worktrees/m5-lib"
S="$WT/.scratch/session-M5-L1"
cd "$WT"
git diff -U3 -- scripts/aitools-lib.sh > "$S/lib-sh-full.tmp"
# Keep the file header and every hunk that mentions the spinner
perl -e '
    local $/; my $d = <STDIN>;
    my ($head, @rest) = split /(?=^@@ )/m, $d;
    my @keep = grep { /spinner/i } @rest;
    print $head, @keep;
    printf STDERR "hunks: %d total, %d kept\n", scalar(@rest), scalar(@keep);
' < "$S/lib-sh-full.tmp" > "$S/lib-sh-item1.tmp"
git apply --cached --check "$S/lib-sh-item1.tmp"
git apply --cached "$S/lib-sh-item1.tmp"
git add tests/menus/test-menu-choice.sh reference/cross-platform-detail.md RELEASE_NOTES.md
git diff --cached --stat
