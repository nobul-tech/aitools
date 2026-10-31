#!/usr/bin/env bash
# Wait (max ~9 min) until each named file exists in the S3-Reconcile folder; print which exist.
set -euo pipefail
d=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Reconcile
n=0
while [ "$n" -lt 108 ]; do
  all=1
  for f in "$@"; do
    if [ ! -f "$d/$f" ]; then all=0; fi
  done
  if [ "$all" -eq 1 ]; then break; fi
  sleep 5
  n=$((n+1))
done
for f in "$@"; do
  if [ -f "$d/$f" ]; then echo "present: $f"; else echo "missing: $f"; fi
done
