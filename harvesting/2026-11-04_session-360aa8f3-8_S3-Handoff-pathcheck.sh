#!/usr/bin/env bash
# S3-Handoff-pathcheck.sh -- verify every path the handoff references exists. Scratch.
set -euo pipefail
R=/Users/new-jose/repos/aitools
M=$R/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions
missing=0
check() {
    if [ -e "$1" ]; then printf 'ok      %s\n' "$1"; else printf 'MISSING %s\n' "$1"; missing=$((missing+1)); fi
}
for p in \
  "$M/S4-Review/S4-Review-report.md" "$M/S4-Review/S4-Review-C-review.md" \
  "$M/S4-Review/S4-Review-incidents-draft.json" \
  "$M/S4-Review/S4-Review-drafts/reference/tool-support-decision-tree.md" \
  "$M/S4-Review/S4-Review-drafts/reference/user-repo.md" \
  "$M/S4-Review/S4-Review-drafts/dotprofile/profile.json" \
  "$M/S2-Layout/S2-Layout-report.md" "$M/S2-Layout/S2-Layout-evidence.md" \
  "$M/S2-Layout/S2-Layout-A-deploy-map.md" "$M/S2-Layout/S2-Layout-B-registry-consumers.md" \
  "$M/S2-Layout/S2-Layout-C-review.md" "$M/S2-Layout/s2b-scan.sh" \
  "$M/S2-Split/S2-Split-report.md" "$M/S2-Host/S2-Host-rca.md" \
  "$M/S5-Tools/S5-Tools-report.md" "$M/S5-Tools/S5-Tools-A-review.md" \
  "$M/S5-Tools/S5-Tools-drafts/dot-claude/skills/tool-adopt/SKILL.md" \
  "$M/S5-Tools/S5-Tools-drafts/dot-claude/rules" "$M/S4-Review/S4-Review-drafts/dot-claude/rules" \
  "$M/S4-Review/S4-Review-drafts/registries/glossary.terms-draft.json" \
  "$R/shared/skills/delegate/SKILL.md" "$R/ROADMAP.md" \
  "$R/plans/tooling-resolution-and-artifact-registry.md" \
  "$M/S5-Profile/S5-Profile-report.md" "$M/S5-Profile/S5-Profile-plan.md" \
  "$M/S5-Profile/S5-Profile-A-review.md" "$M/S5-Profile/S5-Profile-drafts/scripts/aitools-profile.js" \
  "$M/S5-Profile/tests" "$M/S3-Nine/EMPTY.txt" "$M/incidents-draft-74-86.json" \
  "$M/recon/local-issue9.patch" "$M/recon/manifest-remote.json" \
  "$R/.claude/rules/sources-of-truth.md" "$R/.claude/rules/plan-execution.md" \
  "$R/reference/plan-execution-detail.md" "$R/registries/incidents.json" \
  "$R/.aitools/channel/handoffs/handoff-46ee1c2b-1.md" \
  "/Users/new-jose/repos/aitools-nobul-jose/claude/rules/delegation.md" \
  "$R/scripts/build-deploy.sh" ; do
    check "$p"
done
printf 'missing=%s\n' "$missing"
