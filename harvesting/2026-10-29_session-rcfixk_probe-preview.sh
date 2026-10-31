#!/usr/bin/env bash
# probe-preview.sh -- the SP-1/SP-2 here-string preview loop under
# set -euo pipefail with small and large input (stdout instead of /dev/tty).
set -euo pipefail
for n in 5 200000; do
    merged=$(perl -e "print qq(line \$_\n) for 1..$n")
    _pv_n=0
    while IFS= read -r _pv_line; do
        _pv_n=$((_pv_n + 1))
        if [ "$_pv_n" -gt 30 ]; then break; fi
        printf '  | %s\n' "$_pv_line"
    done <<< "$merged" | tail -1
    printf 'n=%s reached end, rc ok\n' "$n"
done
