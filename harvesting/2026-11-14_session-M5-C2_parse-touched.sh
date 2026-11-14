#!/usr/bin/env bash
# Parse every touched script: bash -n for .sh, the pwsh parser for .ps1, perl -c for .pl
set -uo pipefail
WT=/c/Users/jdpal/repos/aitools/.claude/worktrees/m5-checks
rc=0
for f in "$@"; do
    p="$WT/$f"
    case "$f" in
        *.sh)
            if bash -n "$p"; then echo "OK   bash -n $f"; else echo "FAIL bash -n $f"; rc=1; fi ;;
        *.ps1)
            w=$(cygpath -w "$p")
            if pwsh -NoProfile -Command "\$e = \$null; \$null = [System.Management.Automation.Language.Parser]::ParseFile('$w', [ref]\$null, [ref]\$e); if (\$e) { \$e; exit 1 }"; then
                echo "OK   pwsh parser $f"
            else
                echo "FAIL pwsh parser $f"; rc=1
            fi ;;
        *.pl)
            if perl -c "$p" 2>&1; then echo "OK   perl -c $f"; else echo "FAIL perl -c $f"; rc=1; fi ;;
        *) echo "?    $f" ;;
    esac
done
exit $rc
