#!/usr/bin/env bash
# test-postpush-regex.sh -- run the step 30/31 extractions (old and patched)
# from check-post-push on origin/main's aitools-lib.sh/.ps1, and the patched
# step 30 loop against setup-user-claude.sh. Usage: test-postpush-regex.sh
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
T="$(mktemp -d)"
git -C "$REPO" show origin/main:scripts/aitools-lib.sh > "$T/lib.sh"
git -C "$REPO" show origin/main:scripts/aitools-lib.ps1 > "$T/lib.ps1"
git -C "$REPO" show origin/main:scripts/setup-user-claude.sh > "$T/suc.sh"
sh_lib="$T/lib.sh"
ps1_lib="$T/lib.ps1"
j() { sort -u | paste -s -d , -; }
echo "== step 30 sh_returns"
printf ' old: %s\n' "$(perl -ne 'print "$1\n" if /MANAGED_FILE_RESULT="(\w[\w-]*)"/' "$sh_lib" | j)"
sh_returns_lines=$(perl -ne 'print "$1\n" if /MANAGED_FILE_RESULT="([^"]+)"/' "$sh_lib" | sort -u)
printf ' new: %s\n' "$(printf '%s\n' "$sh_returns_lines" | paste -s -d , -)"
missing=""
while IFS= read -r val; do
    [ -n "$val" ] || continue
    if ! grep -qF -- "$val" "$T/suc.sh"; then missing="${missing}${missing:+; }missing $val"; fi
done <<< "$sh_returns_lines"
printf ' new loop vs setup-user-claude.sh: %s\n' "${missing:-all handled}"
# negative: drop "accept & adopt" from a caller copy, loop must report it
perl -pe 's/accept & adopt/accept-and-adopt/g' "$T/suc.sh" > "$T/suc-neg.sh"
missing=""
while IFS= read -r val; do
    [ -n "$val" ] || continue
    if ! grep -qF -- "$val" "$T/suc-neg.sh"; then missing="${missing}${missing:+; }missing $val"; fi
done <<< "$sh_returns_lines"
printf ' new loop vs caller without it (want: missing accept & adopt): %s\n' "${missing:-all handled}"
echo "== step 31 results"
printf ' old sh : %s\n' "$(perl -ne 'if (/^deploy_managed_file\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_managed_file/)) { print "$1\n" if /MANAGED_FILE_RESULT="(\w[\w-]*)"/ }' "$sh_lib" | j)"
printf ' old ps1: %s\n' "$(perl -ne 'if (/^function Deploy-ManagedFile\b/ .. (/^function / && !/Deploy-ManagedFile/)) { print "$1\n" if /return\s+"([\w-]+)"/ }' "$ps1_lib" | j)"
printf ' new sh : %s\n' "$(perl -ne 'if (/^deploy_managed_file\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_managed_file/)) { print "$1\n" if /MANAGED_FILE_RESULT="([^"]+)"/ }' "$sh_lib" | j)"
printf ' new ps1: %s\n' "$(perl -ne 'if (/^function Deploy-ManagedFile\b/ .. (/^function / && !/Deploy-ManagedFile/)) { print "$1\n" if /return\s+"([^"]+)"/ }' "$ps1_lib" | j)"
echo "== step 31 tracker"
printf ' old sh : %s\n' "$(perl -ne 'if (/^deploy_tracker_record\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_tracker_record/)) { if (/^\s+([\w|.-]+)\)\s/) { for (split /\|/, $1) { print "$_\n" } } }' "$sh_lib" | j)"
printf ' old ps1: %s\n' "$(perl -ne 'if (/^function Record-DeployOutcome\b/ .. (/^function / && !/Record-DeployOutcome/)) { while (/-eq\s+"([\w-]+)"|"([\w-]+)"\s*\{/g) { print(($1 // $2) . "\n") } }' "$ps1_lib" | j)"
printf ' new sh : %s\n' "$(perl -ne 'if (/^deploy_tracker_record\b/ .. (/^\w+.*\(\)\s*\{/ && !/deploy_tracker_record/)) { if (/^\s+((?:"[^"]+"|[\w.-]+)(?:\|(?:"[^"]+"|[\w.-]+))*)\)\s/) { for (split /\|/, $1) { s/"//g; print "$_\n" } } }' "$sh_lib" | j)"
printf ' new ps1: %s\n' "$(perl -ne 'if (/^function Record-DeployOutcome\b/ .. (/^function / && !/Record-DeployOutcome/)) { while (/-eq\s+"([^"]+)"|"([^"]+)"\s*\{/g) { print(($1 // $2) . "\n") } }' "$ps1_lib" | j)"
