#!/usr/bin/env bash
set -euo pipefail

files=(
  session-state-audit.md
  findings-index.md
  schwerpunkt-assessment.md
  rule-effectiveness-audit.md
  governed-data-investigation.md
  q4-lifecycle-investigation.md
  q10-artifact-roles-investigation.md
  q4-q10-ambiguity-audit.md
  carry-forward-provenance.md
  carry-forward-frameworks.md
  carry-forward-barrier-C.md
  s2-post-push-aar.md
  post-push-fix-briefing.md
  briefing-cluster-analysis.md
  harness-cicd-investigation.md
  cicd-feasibility.md
  aitools-in-tool-ops-investigation.md
  scratch-deletion-rca.md
  verification-lifecycle-gap-audit.md
  session-transition-testing.md
  provenance-deep-research.md
  briefings-location-decision.md
  promotion-definition-draft.md
  promotion-definition-audit.md
  repo-project-definition-draft.md
  carry-forward-barrier-A.md
  carry-forward-barrier-B.md
  artifact-roles-tension-investigation.md
  intent-heuristic-findings.md
  intent-audit-findings.md
)

BASE="/Users/pepe/repos/aitools"

for f in "${files[@]}"; do
  scratch="$BASE/.scratch/session-Z1IhGrcgGO/$f"
  harvest="$BASE/harvesting/2026-03-19_$f"
  s="NOT_FOUND"; h="NOT_FOUND"
  [ -f "$scratch" ] && s="FOUND"
  [ -f "$harvest" ] && h="FOUND"
  printf "%-50s scratch:%-10s harvest:%s\n" "$f" "$s" "$h"
done
