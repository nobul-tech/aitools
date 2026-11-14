#!/usr/bin/env bash
# extract-m1.sh REF -- copy REF's aitools-lib.sh/.ps1 into prep/scripts (CRLF kept as in the blob)
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
W="$S/../.."
ref="$1"
for f in aitools-lib.sh aitools-lib.ps1; do
    git -C "$W" cat-file -p "$ref:scripts/$f" > "$S/prep/scripts/$f"
    git -C "$W" cat-file -p "$ref:scripts/$f" > "$S/prep/scripts/$f.base"
done
ls -l "$S/prep/scripts"
