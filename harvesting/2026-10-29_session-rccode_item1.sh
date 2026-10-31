#!/usr/bin/env bash
# Item 1: rules source/target lines per consumer per ref
set -euo pipefail
R=/Users/new-jose/repos/aitools
show() { git -C "$R" show "$1:$2" | grep -n -E "$3" | tr -d '\r' || echo "  (no match)"; }
echo "######## setup-user-claude"
for ref in origin/main origin/fix/mf-dotprofile-adopt-push origin/fix/mf-audit-claude-build origin/fix/mf-lib-runner-result origin/fix/mf-lib-relay origin/fix/mf-installer-relay; do
  for f in scripts/setup-user-claude.sh scripts/setup-user-claude.ps1; do
    echo "== $ref $f"
    show "$ref" "$f" 'RULES_SRC=|rulesSrc = |candidateRules|RULES_DEST=|rulesDest = |aitools/rules|aitools\\rules|BEGIN rules|END rules|_rule_adopt_path=|ruleAdoptPath ='
  done
done
echo "######## setup-user-cursor"
for ref in origin/main origin/feature/harness-cursor-user-rules origin/fix/mf-audit-consumers; do
  for f in scripts/setup-user-cursor.sh scripts/setup-user-cursor.ps1; do
    echo "== $ref $f"
    show "$ref" "$f" 'HARNESS_RULES_DIR=|harnessRulesDir = |CURSOR_RULES_DIR=|cursorRulesDir = |RULES_DEST=|rulesDest = |manifest|user-level|userLevel|USER_LEVEL'
  done
done
echo "######## deploy-harness"
for ref in origin/main origin/feature/harness-rules-manifest origin/feature/harness-cursor-user-rules origin/feature/harness-mdm-followups; do
  for f in scripts/deploy-harness.sh scripts/deploy-harness.ps1; do
    echo "== $ref $f"
    show "$ref" "$f" 'add_source rules|Add-Source .*rules|Add-Source -Kind "rules"|first source wins|duplicate|retired|MANIFEST|manifest'
  done
done
