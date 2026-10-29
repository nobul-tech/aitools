#!/usr/bin/env bash
# check-sources.sh -- expected skill/rule names from git-tracked sources (union, case-insensitive)
set -uo pipefail
A=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx/aitools
D=/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-ps/fx/dotprofile
echo "== skill names (union of shared/skills, .claude/skills, dotprofile claude/skills)"
{ git -C "$A" ls-files shared/skills .claude/skills | perl -ne 'print "$1\n" if m{^(?:shared|\.claude)/skills/([^/]+)/}'
  git -C "$D" ls-files claude/skills | perl -ne 'print "$1\n" if m{^claude/skills/([^/]+)/}'; } | sort -u | tee /dev/stderr | wc -l
echo "== rule names (union, top-level *.md, any case)"
{ git -C "$A" ls-files shared/rules .claude/rules | perl -ne 'print "$1\n" if m{^(?:shared|\.claude)/rules/([^/]+\.md)$}i'
  git -C "$D" ls-files claude/rules | perl -ne 'print "$1\n" if m{^claude/rules/([^/]+\.md)$}i'; } | sort -u | wc -l
