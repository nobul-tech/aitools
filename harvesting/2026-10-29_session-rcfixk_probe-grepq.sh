#!/usr/bin/env bash
# probe-grepq.sh -- under pipefail, does `printf big | grep -q early-match`
# report "no match"? Also tests the here-string alternative.
set -euo pipefail
for n in 100 20000; do
    big="needle
$(perl -e "print qq(line\n) x $n")"
    if printf '%s\n' "$big" | grep -q needle; then r1=match; else r1="NO MATCH (rc ${PIPESTATUS[*]})"; fi
    if grep -q needle <<< "$big"; then r2=match; else r2="no match"; fi
    printf 'lines=%s pipe: %s | here-string: %s\n' "$n" "$r1" "$r2"
done
