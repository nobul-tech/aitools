#!/usr/bin/env bash
set -uo pipefail
L=/Users/new-jose/.aitools/logs
echo '=== Profile interpolation after 2026-06-22T04'
grep -hE 'Profile interpolation' $L/deploy.log | perl -ne 'print if /^\[(2026-0[6-9]-2[3-9]|2026-0[7-9]|2026-1)/ || /^\[2026-06-22T(0[4-9]|1|2)/'
echo '=== deploy.log hours with activity after June 22 (distinct days)'
perl -ne 'if(/^\[(\d{4}-\d\d-\d\d)T/){print "$1\n" unless $s{$1}++}' $L/deploy.log | tail -n 30
echo '=== deploy.jsonl distinct days'
perl -ne 'if(/"ts":"(\d{4}-\d\d-\d\d)T/){print "$1\n" unless $s{$1}++}' $L/deploy.jsonl
echo '=== checks.jsonl distinct days'
perl -ne 'if(/"ts":"(\d{4}-\d\d-\d\d)T/){print "$1\n" unless $s{$1}++}' $L/checks.jsonl
echo '=== deploy.log lines with nobul-mac or (Mac)'
grep -nE 'nobul-mac|\(Mac\)|new-mac' $L/deploy.log | head -n 20
echo '=== dotprofile status'
git -C /Users/new-jose/repos/aitools-nobul-jose status --short | head -n 20
echo '=== dotprofile CLAUDE.md Machine footer in git'
git -C /Users/new-jose/repos/aitools-nobul-jose log --format='%h %ad' --date=iso-strict -S'nobul-mac' | head
