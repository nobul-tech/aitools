#!/usr/bin/env bash
# apply-all.sh -- export the files each drafts file touches from a ref (git archive,
# touched files only) into a mktemp -d dir, apply the drafts with apply.pl, then
# bash -n every .sh and the pwsh parser on every .ps1 in the output.
# Usage: apply-all.sh REF EDITS_FILE...
set -uo pipefail
repo=/Users/new-jose/repos/aitools
applier="$repo/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile/S3-Reconcile-Code-drafts/apply.pl"
parser=/Users/new-jose/repos/aitools/.scratch/session-rcfixc/parse.ps1
ref="$1"; shift
T=$(mktemp -d /tmp/rcfixc-apply.XXXXXX)
echo "work dir: $T (ref $ref)"
fail=0
for edits in "$@"; do
    name=$(basename "$edits" .txt)
    files=$(perl -ne 'print "$1\n" if /^\@\@\@FILE (\S+)/' "$edits" | sort -u)
    mkdir -p "$T/$name/base" "$T/$name/out"
    # shellcheck disable=SC2086
    if ! git -C "$repo" archive "$ref" $files | tar -x -C "$T/$name/base"; then
        echo "FAIL export: $name"; fail=1; continue
    fi
    echo "== $name"
    if ! perl "$applier" "$edits" "$T/$name/base" "$T/$name/out"; then
        echo "FAIL apply: $name"; fail=1; continue
    fi
    for f in $files; do
        case "$f" in
            *.ps1) pwsh -NoProfile -File "$parser" "$T/$name/out/$f" || fail=1 ;;
            *.sh|scripts/aitools|scripts/build-deploy.sh)
                if bash -n "$T/$name/out/$f"; then echo "bash -n ok: $f"; else echo "BASH-N FAIL: $f"; fail=1; fi ;;
            *) echo "no syntax check: $f" ;;
        esac
    done
done
echo "overall: $([ "$fail" -eq 0 ] && echo PASS || echo FAIL)"
echo "T=$T"
