#!/usr/bin/env bash
set -euo pipefail
DIR="/Users/new-jose/repos/aitools-nobul-jose/sessions/aitools"
cd "$DIR"
for f in 2026-03-2[4-9]_*.jsonl 2026-03-3[01]_*.jsonl; do
  [ -f "$f" ] || continue
  tasks=$(grep -ci '"name":"Task"' "$f" || true)
  agents=$(grep -ci '"name":"Agent"' "$f" || true)
  mission=$(grep -oi 'Mission:' "$f" | wc -l | tr -d ' ')
  printf '%-28s task=%-4s agent=%-4s mission=%s\n' "$f" "$tasks" "$agents" "$mission"
done
