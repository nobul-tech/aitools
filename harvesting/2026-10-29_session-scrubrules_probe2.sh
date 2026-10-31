#!/usr/bin/env bash
# probe2: more rule-claim verification (read-only)
set -uo pipefail
R=/Users/new-jose/repos/aitools
cd "$R"
sec() { printf '\n===== %s =====\n' "$1"; }

sec "pre-commit all step labels"
grep -nE -- '--- Step [0-9]+' scripts/check-pre-commit.sh
grep -nE 'Step [0-9]+' scripts/check-pre-commit.ps1 | grep -E -- '---' | head -40

sec "pre-push step labels"
grep -nE -- '--- |step [0-9]+|Step [0-9]+|^# [0-9]+\.' scripts/check-pre-push.sh | head -40

sec "post-push 26 deploy scripts list sync body"
sed -n '676,745p' scripts/check-post-push.sh

sec "post-push 7 deploy drift body"
sed -n '202,232p' scripts/check-post-push.sh

sec "deploy-state in lib"
grep -n 'deploy-state' scripts/aitools-lib.sh scripts/aitools-lib.ps1 scripts/check-post-push.sh | head

sec "adopt_claude_md / ADOPT_TRANSFORM"
grep -rn 'adopt_claude_md\|ADOPT_TRANSFORM\|AdoptTransform' scripts | head

sec "stat dispatch in hooks"
grep -n 'stat -f %m' shared/hooks/*.sh scripts/*.sh | head

sec "setup-user-claude rules fan-out"
grep -n 'aitools/rules\|no harness rules\|fan-out\|fanout' scripts/setup-user-claude.sh scripts/setup-user-cursor.sh | head -20

sec "deploy-harness add_source order + abort"
grep -n 'add_source\|aborted by user\|config.json not generated' scripts/deploy-harness.sh | head -20
grep -n 'aborted by user\|script failed (exit 2)\|deploy_configs()\|Step 8b' scripts/aitools scripts/aitools-install.sh scripts/aitools.ps1 scripts/aitools-install.ps1 | head -20

sec "bin step in aitools install"
grep -n 'read-session.py\|harness-db.py' scripts/aitools-install.sh scripts/aitools scripts/aitools-install.ps1 | head

sec "aitools user init / user sync"
grep -nE '"?user"?\)|user init|user sync|init\)' scripts/aitools | head -20

sec "AITOOLS_FORCE"
grep -n 'AITOOLS_FORCE' scripts/aitools scripts/aitools.ps1 scripts/aitools-install.sh scripts/aitools-install.ps1 | head

sec "relay prompt"
grep -nE 'RELAY_PROMPT_FORCE|AITOOLS_SKIP_RELAY_PROMPT|\[c\]|\[q\]|\[s\]|exit 2' scripts/relay-outbound-prompt.sh | head -20

sec "chrome-devtools args in setup-user-mcp"
grep -n 'chrome-devtools-mcp' scripts/setup-user-mcp.sh scripts/setup-user-mcp.ps1 | head

sec "hook command format in settings"
grep -nE 'bash \\"|"bash ' scripts/setup-user-hooks.sh | head -5

sec "hooks-manifest events"
python3 -c 'import json,sys;d=json.load(open("shared/hooks/hooks-manifest.json"));print(json.dumps(d,indent=1)[:4000])'

sec "invoke_ai models"
grep -nE 'haiku|sonnet|opus|--model auto|max_retries|retries=' scripts/aitools-lib.sh | head -20

sec "protected WARN on adopt"
grep -n 'protected' scripts/aitools-lib.sh | head

sec "auth checks"
grep -n 'modal.toml' scripts/setup-modal.sh | head -3
grep -n 'auth status' scripts/setup-datadog.sh | head -3
grep -n 'whoami' scripts/setup-vercelcli.sh | head -3

sec "cross-language: bash build-deploy from ps1"
grep -n 'build-deploy.sh' scripts/aitools.ps1 scripts/aitools-install.ps1 | head
grep -n 'bashExe' scripts/aitools.ps1 | head -5

sec "cursor-practices rule correspondence"
grep -n -A40 -i 'Rule Correspondence' reference/cursor-practices.md | head -60

sec "harvest SessionStart / aitools sync candidate prompt"
grep -n 'candidate' scripts/aitools scripts/aitools.ps1 | head
grep -rn 'prune' shared/hooks/*.sh | head -5

sec "OS guard presence in scripts"
for f in scripts/*.sh; do if ! grep -q 'MINGW\*|MSYS\*|CYGWIN\*' "$f"; then echo "no-guard: $f"; fi; done
for f in scripts/*.ps1; do if ! grep -q -- '-not \$IsWindows' "$f"; then echo "no-guard: $f"; fi; done

sec "glossary.json term count vs rule"
python3 - <<'PY'
import json,re
d=json.load(open("registries/glossary.json"))
terms=set()
def walk(x):
    if isinstance(x,dict):
        for k in ("term","name"):
            if k in x and isinstance(x[k],str): terms.add(x[k])
        for v in x.values(): walk(v)
    elif isinstance(x,list):
        for v in x: walk(v)
walk(d)
rule=open(".claude/rules/glossary.md").read()
lines=set(l.strip() for l in rule.splitlines() if l.strip() and not l.startswith(("#","*","-","`","Invoke","The skill","directly","Definitions","Composition","these arise","and scope","The word","NOT the","agent, every")))
print("in json not in rule:", sorted(t for t in terms if t not in lines)[:80])
print("in rule not in json:", sorted(t for t in lines if t not in terms and len(t)<40)[:80])
print("top keys:", list(d.keys())[:10])
PY
