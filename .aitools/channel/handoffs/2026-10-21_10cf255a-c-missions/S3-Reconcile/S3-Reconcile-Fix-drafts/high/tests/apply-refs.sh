#!/usr/bin/env bash
# apply-refs.sh EDITS TMP REF... -- export the files EDITS touches at each REF, apply
# EDITS with apply.pl, then bash -n / pwsh-parse every output file.
set -euo pipefail
edits="$1"; tmp="$2"; shift 2
apply=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts/apply.pl
files=$(perl -ne 'print "$1\n" if /^\@\@\@FILE (\S+)/' "$edits" | sort -u)
for ref in "$@"; do
    tag=$(printf '%s' "$ref" | tr '/' '_')
    base="$tmp/base-$tag"; out="$tmp/out-$tag"
    rm -rf "$base" "$out"
    mkdir -p "$base" "$out"
    # shellcheck disable=SC2086
    git -C /Users/new-jose/repos/aitools archive "$ref" -- $files | tar -xf - -C "$base"
    echo "== $ref"
    if ! perl "$apply" "$edits" "$base" "$out"; then
        echo "APPLY FAILED on $ref"
        continue
    fi
    for f in $files; do
        case "$f" in
            *.ps1)
                if pwsh -NoProfile -File /Users/new-jose/repos/aitools/.scratch/session-rcfix/parse.ps1 "$out/$f"; then echo "parse ok: $f"; else echo "PARSE FAIL: $f"; fi ;;
            *.md|*.mdc|*.yml|*.txt) ;;
            *)
                if bash -n "$out/$f"; then echo "bash -n ok: $f"; else echo "BASH -n FAIL: $f"; fi ;;
        esac
    done
done
