#!/usr/bin/env bash
# hh — honest harness: show git status for harness paths, then run aitools
#
# Resolves the aitools repo (walk up from cwd, then ~/.aitools/config.json repoPath).
# Usage:
#   hh                  # status + aitools (pull, rebuild deploy, deploy user, relay→AGENTS)
#   hh -n               # status only (no aitools)
#   hh --status-only    # same as -n
#
# Env: AITOOLS_REPO — override repo root if set.

set -euo pipefail

STATUS_ONLY=false
for a in "$@"; do
  case "$a" in
    -n|--status-only) STATUS_ONLY=true ;;
    -h|--help)
      echo "Usage: hh [-n|--status-only]  (status only; no aitools)"
      exit 0
      ;;
  esac
done

find_aitools_repo() {
  if [ -n "${AITOOLS_REPO:-}" ] && [ -f "${AITOOLS_REPO}/scripts/build-deploy.sh" ]; then
    echo "${AITOOLS_REPO}"
    return 0
  fi
  local cur="$PWD"
  while true; do
    if [ -f "$cur/scripts/build-deploy.sh" ] && [ -d "$cur/.git" ]; then
      echo "$cur"
      return 0
    fi
    case "$cur" in
      /|.) break ;;
    esac
    local parent
    parent="$(dirname "$cur")"
    if [ "$parent" = "$cur" ]; then break; fi
    cur="$parent"
  done
  local cfg="${HOME}/.aitools/config.json"
  if [ -f "$cfg" ] && command -v node >/dev/null 2>&1; then
    local rp
    rp="$(node -e "
const fs = require('fs');
const path = require('path');
const home = process.env.HOME || process.env.USERPROFILE || '';
try {
  const j = JSON.parse(fs.readFileSync(path.join(home, '.aitools', 'config.json'), 'utf8'));
  const r = j.repoPath || j.aiToolingRepoPath || '';
  process.stdout.write(r);
} catch (e) {}
" 2>/dev/null | tr -d '\r\n')"
    if [ -n "$rp" ] && [ -f "$rp/scripts/build-deploy.sh" ]; then
      echo "$rp"
      return 0
    fi
  fi
  return 1
}

REPO_ROOT="$(find_aitools_repo)" || {
  echo "hh: cannot find aitools repo (cd into clone, set repoPath in ~/.aitools/config.json, or export AITOOLS_REPO)" >&2
  exit 1
}

cd "$REPO_ROOT"

echo "== hh (honest harness) @ $(pwd) =="
echo ""

echo "-- Branch --"
git status -sb
echo ""

echo "-- Harness paths (relay, shared, deploy, build script, .cursorignore) --"
git status --short -- \
  .aitools/channel/relay.md \
  shared/ \
  deploy/ \
  scripts/build-deploy.sh \
  .cursorignore \
  2>/dev/null || true

echo ""
echo "Reminder: commit/push relay + shared when ready; aitools syncs relay → ~/.cursor/AGENTS.md."
echo ""

if $STATUS_ONLY; then
  exit 0
fi

if ! command -v aitools >/dev/null 2>&1; then
  echo "hh: aitools not on PATH — install via aitools-install, or run: bash scripts/aitools" >&2
  exit 1
fi

exec aitools
