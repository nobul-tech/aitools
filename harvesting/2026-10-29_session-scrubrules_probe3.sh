#!/usr/bin/env bash
# probe3: follow-ups (read-only)
set -uo pipefail
R=/Users/new-jose/repos/aitools
cd "$R"
sec() { printf '\n===== %s =====\n' "$1"; }

sec "glossary.json structure"
python3 -c 'import json;d=json.load(open("registries/glossary.json"));t=d["terms"];print(type(t).__name__,len(t));print(list(t)[:5] if isinstance(t,dict) else [list(x.keys()) for x in t[:2]])'
python3 - <<'PY'
import json
d=json.load(open("registries/glossary.json"))
t=d["terms"]
names=set(t.keys()) if isinstance(t,dict) else set(x.get("term") or x.get("name") for x in t)
rule=[l.strip() for l in open(".claude/rules/glossary.md").read().split("### When to invoke")[0].splitlines()]
rule=set(l for l in rule if l and not l.startswith(("#","**","`","NOT","and scope","The word","agent, every","`@")) and len(l)<40)
print("json-only:",sorted(names-rule))
print("rule-only:",sorted(rule-names))
PY

sec "adopt transform name"
grep -rn -i 'adopt.*transform\|transform.*adopt' scripts/aitools-lib.sh scripts/setup-user-claude.sh | head -10

sec "pre-commit step numbering (all)"
grep -nE 'step_(pass|fail|warn|skip) "[0-9]+"|Step[ _]?[0-9]+' scripts/check-pre-commit.sh | perl -ne 'print if /"(\d+)"/ or /Step ?(\d+)/' | perl -ne 'm/"(\d+)" "([^"]+)"/ and print "$1 $2\n"' | sort -un | head -40

sec "pre-commit step 13 / 3 / 10 text"
grep -nE '"(3|10|13)" "' scripts/check-pre-commit.sh | head

sec "hooks referencing harvesting/ prune at SessionStart"
grep -ln 'harvesting' shared/hooks/*.sh scripts/ait-harvest.py
grep -n 'def .*prune\|def .*audit\|def .*catchup\|def .*catch_up' scripts/ait-harvest.py | head

sec "aitools harvest candidates"
grep -n -i 'harvest' scripts/aitools | head -10

sec "project .claude settings + hooks"
ls .claude
python3 -c 'import json;d=json.load(open(".claude/settings.json"));print(json.dumps(d.get("hooks",{}),indent=1)[:3000])' 2>&1

sec "SubagentStart / incidents hook anywhere"
grep -rln 'SubagentStart\|incidents.json' shared/hooks .claude/hooks scripts/setup-user-hooks.sh 2>/dev/null

sec "intelligence-stop surfacing"
grep -n -i 'incident\|surfacing' shared/hooks/intelligence-stop.sh shared/hooks/intelligence-stop.py | head

sec "setup-user-mcp targets (mcp.json vs claude mcp add)"
grep -n 'mcp.json\|claude mcp add\|\.claude\.json' scripts/setup-user-mcp.sh | head -10

sec "setup-user-claude rules source"
grep -n 'claude/rules\|\.aitools/rules\|RULES_SRC\|rules_dir' scripts/setup-user-claude.sh | head -20

sec "ROADMAP I6"
grep -n 'I6\|duplicat' ROADMAP.md | head

sec "scratch location used by scratch-init"
grep -n 'scratch' shared/hooks/scratch-init.sh | head -10

sec "harvest-manifest path in ait-harvest"
grep -n 'harvest-manifest\|HARVEST_DIR\|harvesting' scripts/ait-harvest.py | head -10

sec "reference/harness.md components"
grep -n -i 'five\|components' reference/harness.md | head -5

sec "skill frontmatter disable-model-invocation for audit"
grep -n 'disable-model-invocation' .claude/skills/audit/SKILL.md

sec "incidents.json closed array"
python3 -c 'import json;d=json.load(open("registries/incidents.json"));print(list(d.keys()));print(len(d.get("incidents",[])),len(d.get("closed",[])))'

sec "check-pre-push step 5 release notes"
sed -n '88,112p' scripts/check-pre-push.sh

sec "build-deploy skills embed + output dir"
grep -n 'shared/skills\|SKILLS_DIR\|DEPLOY_DIR=' scripts/build-deploy.sh | head -10

sec "VERSION file"
ls VERSION 2>&1
git describe --tags --abbrev=0

sec "post-push step 12 CLAUDE.md limits"
sed -n '283,293p' scripts/check-post-push.sh

sec "hh.sh header"
sed -n '1,15p' scripts/hh.sh
sec "bootstrap.sh header"
sed -n '1,20p' scripts/bootstrap.sh
sec "build-package.sh header"
sed -n '1,25p' scripts/build-package.sh
