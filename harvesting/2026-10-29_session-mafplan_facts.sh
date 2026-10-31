#!/usr/bin/env bash
# facts.sh -- spot-check facts the friction plan cites (read-only)
set -euo pipefail
R=/Users/new-jose/repos/aitools
cd "$R"
echo "== HEAD"; git log -1 --format='%h %s'
echo "== check.yml triggers"; grep -n -A6 '^on:' .github/workflows/check.yml
echo "== check.yml jobs"; grep -n -E '^  [a-z][a-z0-9_-]*:$' .github/workflows/check.yml
echo "== check.yml tests refs"; grep -n -o -E 'tests/[a-zA-Z0-9_/.-]+' .github/workflows/check.yml | sort -u -t: -k2
echo "== check.yml line count"; wc -l < .github/workflows/check.yml
echo "== test entry files"; find tests -name 'test-*' -type f | sort
echo "== pre-push line 70"; sed -n '68,72p' scripts/check-pre-push.sh
echo "== pre-commit .sh step ids"; grep -o -E 'step_(start|pass|fail|warn|skip|header|begin) +"?[0-9]+' scripts/check-pre-commit.sh | grep -o -E '[0-9]+$' | sort -n -u | tr '\n' ' '; echo
echo "== pre-commit .ps1 step ids"; grep -o -E 'Step(Start|Pass|Fail|Warn|Skip|Header|Begin) +"?[0-9]+' scripts/check-pre-commit.ps1 | grep -o -E '[0-9]+$' | sort -n -u | tr '\n' ' '; echo
echo "== pre-push .sh step ids"; grep -o -E 'step_(start|pass|fail|warn|skip|header|begin) +"?[0-9]+' scripts/check-pre-push.sh | grep -o -E '[0-9]+$' | sort -n -u | tr '\n' ' '; echo
echo "== post-push .sh step ids"; grep -o -E 'step_(start|pass|fail|warn|skip|header|begin) +"?[0-9]+' scripts/check-post-push.sh | grep -o -E '[0-9]+$' | sort -n -u | tr '\n' ' '; echo
echo "== step function names in check-lib.sh"; grep -n -E '^(step_[a-z]+|print_summary|check_log_init)\(\)' scripts/check-lib.sh
echo "== harvesting mode"; git ls-files -s harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh
echo "== tracked .bak"; git ls-files | grep -E '\.bak\.[0-9]{4}-' || echo none
echo "== DRAFT in aitools-json"; grep -n -c DRAFT scripts/aitools-json.pl scripts/aitools-json.ps1 || echo none
echo "== githooks"; ls scripts/githooks
echo "== harvested merge tools"; ls harvesting | grep -E 'merge-check|pr-status|watch-runs|stack-compare' || echo none
echo "== sources-of-truth rule lines"; grep -n -E 'Draft the change|Present for review|Wait for approval' .claude/rules/sources-of-truth.md
echo "== delegate skill draft lines"; grep -n -i 'draft' shared/skills/delegate/SKILL.md | head -20
echo "== dotprofile delegation rule"; grep -n -i -E 'draft|D-DEL' /Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md | head -20
echo "== incidents next id"; python3 -c "import json;d=json.load(open('registries/incidents.json'));ids=[i['id'] for k in ('incidents','closed') for i in d.get(k,[]) if isinstance(i.get('id'),int)];print('max',max(ids),'count',len(ids))"
echo "== plans referencing merge-friction"; ls plans | grep -i friction || echo none
