#!/usr/bin/env bash
# probe5: last follow-ups (read-only)
set -uo pipefail
R=/Users/new-jose/repos/aitools
cd "$R"
sec() { printf '\n===== %s =====\n' "$1"; }
sec "script failed (exit"
grep -rn 'script failed (exit' scripts/aitools scripts/aitools.ps1 scripts/aitools-install.sh scripts/aitools-install.ps1 scripts/aitools-lib.sh | head -5
sec "install_via_"
grep -rn 'install_via_\(brew\|apt\)\|Install-Via' scripts/aitools-lib.sh scripts/aitools-lib.ps1 | head -5
sec "~/.claude/rules"
ls "$HOME/.claude/rules"
sec "~/.aitools/rules"
ls "$HOME/.aitools/rules" 2>&1 | head -40
sec "deploy_managed_file return values in lib"
grep -n 'MANAGED_FILE_RESULT=' scripts/aitools-lib.sh | perl -ne 'print "$1\n" if /MANAGED_FILE_RESULT="([^"]*)"/' | sort -u
sec "Deploy-ManagedFile return values ps1"
grep -n 'return "' scripts/aitools-lib.ps1 | perl -ne 'print "$1\n" if /return "([^"]*)"/' | sort -u | head -20
sec "cross-language calls (perl/python from sh, ps1->bash)"
grep -ln 'aitools-json.pl' scripts/*.sh | head
grep -ln 'aitools-json.ps1' scripts/*.ps1 | head
grep -n '& \$bash\|bash.exe' scripts/*.ps1 | head
sec "check-post-push step 7 vs dotprofile"
grep -n 'DEPLOY_DIR_FINAL=\|_urp=' scripts/build-deploy.sh | head
sec "pre-commit step 3 --fix hazard: HOME isolation"
grep -n 'HOME\|AITOOLS_USER_REPO_PATH' scripts/check-pre-commit.sh | head
sec "web-sources firecrawl mention anywhere in rules"
grep -rln -i firecrawl .claude/rules .cursor/rules shared/claude-shared.md
sec "tool-lifecycle md mentions tool-adopt?"
grep -n 'tool-adopt' .claude/rules/*.md .cursor/rules/*.mdc
sec "smoke-test reference mentions linux"
grep -n -i 'linux' reference/smoke-test-pattern-detail.md | head -3
sec "plan-execution-detail exists block"
grep -n -i 'error-handling rules block\|## ' reference/plan-execution-detail.md | head
sec "docs standards: rules exceeding 100 lines"
for f in .claude/rules/*.md; do n=$(wc -l < "$f"); if [ "$n" -gt 100 ]; then echo "$n $f"; fi; done
sec "rules using plain (non-@) paths to reference/"
grep -n '`reference/[a-z-]*\.md`' .claude/rules/*.md | grep -v '@reference' | head -20
sec "mdc counterpart missing"
for f in .claude/rules/*.md; do b=$(basename "$f" .md); [ -f ".cursor/rules/$b.mdc" ] || echo "no mdc: $b"; done
for f in .cursor/rules/*.mdc; do b=$(basename "$f" .mdc); [ -f ".claude/rules/$b.md" ] || echo "no md: $b"; done
sec "tool-lifecycle mdc 6 lifecycle fields vs registry"
python3 -c 'import json;d=json.load(open("registries/tool-registry.json"));t=d["tools"];k=next(iter(t));print(k, sorted((t[k].get("lifecycle") or {}).keys()))'
sec "check-post-push hook verification step 17 body head"
sed -n '359,372p' scripts/check-post-push.sh
