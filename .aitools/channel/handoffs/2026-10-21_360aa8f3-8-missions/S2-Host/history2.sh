#!/usr/bin/env bash
set -uo pipefail
DP=/Users/new-jose/repos/aitools-nobul-jose
L=/Users/new-jose/.aitools/logs
echo '=== eb48c33 new-mac hunk'
git -C "$DP" show eb48c33 -- profile.json | grep -n -A12 '"new-mac"'
echo '=== eb48c33 stat'
git -C "$DP" show --stat --format='%H %ad %an <%ae>%n%B' --date=iso-strict eb48c33 | head -n 30
echo '=== Profile interpolation company over time (distinct, first/last)'
grep -hE 'Profile interpolation' $L/deploy.log* | perl -ne 'if(/^\[(\S+)\] \[(\S+)\].*company=(.*)$/){$k="$2 $3"; $f{$k}//=$1; $l{$k}=$1} END{for(sort keys %f){print "$_ first=$f{$_} last=$l{$_}\n"}}'
echo '=== host fields in checks/jsonl logs (distinct, first/last)'
ls $L
grep -rhoE '"host(name)?" *: *"[^"]*"' $L 2>/dev/null | sort | uniq -c
echo '=== host in session archives (ait-harvest socket.gethostname)'
grep -rlE '"host" *: *"' "$DP/sessions" 2>/dev/null | head -n 3
grep -rhoE '"host" *: *"[^"]*"' "$DP/sessions" 2>/dev/null | sort | uniq -c
echo '=== Machine-Specific lines in deployed / dotprofile CLAUDE.md history'
grep -n 'Machine: ' /Users/new-jose/.claude/CLAUDE.md
grep -hE 'Machine: Darwin' $L/deploy.log* | perl -ne 'if(/^\[(\S+)\].*\((\S+)\)/){$f{$2}//=$1;$l{$2}=$1} END{for(sort keys %f){print "$_ first=$f{$_} last=$l{$_}\n"}}'
