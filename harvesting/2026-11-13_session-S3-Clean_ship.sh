#!/usr/bin/env bash
# ship.sh MSGFILE PATH... -- fetch, require not behind origin/main (ff-only pull if behind),
# stage exactly PATHs, show the staged stat, commit with MSGFILE, push to origin main.
set -euo pipefail
cd /Users/new-jose/repos/aitools
msg="$1"; shift
git fetch -q origin main
counts=$(git rev-list --left-right --count HEAD...origin/main)
behind=${counts##*[[:space:]]}
ahead=${counts%%[[:space:]]*}
if [ "$ahead" != "0" ]; then
    printf 'ERROR: HEAD is %s commit(s) ahead of origin/main before staging (another session'"'"'s unpushed work?); refusing\n' "$ahead" >&2
    git log --oneline origin/main..HEAD >&2
    exit 1
fi
if [ "$behind" != "0" ]; then
    printf 'behind origin/main by %s: pulling --ff-only\n' "$behind"
    git pull --ff-only origin main
fi
if [ -n "$(git diff --cached --name-only)" ]; then
    printf 'ERROR: index already has staged changes; refusing\n' >&2
    git diff --cached --name-only >&2
    exit 1
fi
git add -- "$@"
git diff --cached --stat
git commit -q -F "$msg"
git log --oneline -1
git push origin main
