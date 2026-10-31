#!/usr/bin/env bash
# apply-and-test.sh -- export the files an edits file touches from origin/main
# into a mktemp dir, apply the edits with apply.pl, syntax-check the outputs.
# Usage: apply-and-test.sh <edits file>   (prints BASE and OUT dirs)
set -uo pipefail
REPO=/Users/new-jose/repos/aitools
D=$REPO/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile
EDITS="$1"
BASE="$(mktemp -d)"
OUT="$(mktemp -d)"
files=$(perl -ne 'print "$1\n" if /^\@\@\@FILE (\S+)/' "$EDITS" | sort -u)
for f in $files; do
    mkdir -p "$BASE/$(dirname "$f")"
    git -C "$REPO" show "origin/main:$f" > "$BASE/$f"
done
printf 'BASE=%s\nOUT=%s\n' "$BASE" "$OUT"
perl "$D/S3-Reconcile-Code-drafts/apply.pl" "$EDITS" "$BASE" "$OUT"
printf 'apply rc=%s\n' "$?"
for f in $files; do
    case "$f" in
        *.sh|scripts/aitools|scripts/githooks/*) bash -n "$OUT/$f"; printf 'bash -n %s rc=%s\n' "$f" "$?" ;;
        *.ps1) pwsh -NoProfile -Command "\$e=\$null; \$null=[System.Management.Automation.Language.Parser]::ParseFile('$OUT/$f',[ref]\$null,[ref]\$e); if (\$e) { \$e; exit 1 }"; printf 'pwsh parse %s rc=%s\n' "$f" "$?" ;;
        *.py) python3 -m py_compile "$OUT/$f"; printf 'py_compile %s rc=%s\n' "$f" "$?" ;;
        *.yml) python3 -c "import sys,yaml; yaml.safe_load(open(sys.argv[1]))" "$OUT/$f" 2>&1; printf 'yaml %s rc=%s\n' "$f" "$?" ;;
    esac
done
