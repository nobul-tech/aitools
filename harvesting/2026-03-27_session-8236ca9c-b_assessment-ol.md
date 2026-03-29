# Operational Learning: Assessment Synthesis (Session 8236ca9c)

**Mission Commander**: assessment-lead
**Date**: 2026-03-26
**Missions**: blast-radius, tool-ops-verify, work-product-inventory

## New OL from this assessment

OL-50: The Agent/Task tool for launching subagents was not available to assessment-lead. Three-MC delegation plan had to be executed sequentially by the parent. This consumed parent context but produced complete results. Future delegation planning should verify tool availability before designing parallel execution.

OL-51: The failure mode's blast radius is narrow -- concentrated in Stop hook pipeline registration. Code written during failure mode is structurally sound but incompletely integrated. This is consistent with OL-40 (multiple symptoms share the same shape) -- the shape is "committed without registering."

OL-52: The governance layer (.claude/rules/) survived failure mode untouched. All 25 rules files have pre-failure modification dates. Rules are a reliable anchor for recovery because the failure mode affected execution, not governance.

OL-53: harness.db is NOT empty (contradicts handoff F-2). It has 98304 bytes, 9 tables, and populated data including provenance seed data. SQLite WAL-mode behavior can make files appear empty (0 bytes main file with data in WAL journal) to naive file-size checks. Agent observations about SQLite file sizes are unreliable without querying the database.

OL-54: Commit 40951fc appears to be pushed to origin/main despite handoff saying "NOT PUSHED." The discrepancy is unresolved. Either it was pushed between sessions, or the handoff was wrong. This affects whether the dangling cross-refs (F-3) are in public history.

OL-55: All 12 deployed hooks match source exactly (zero drift). The deployment pipeline correctly deploys existing hooks. The gap is exclusively in ADDING new hooks to the pipeline. This means `aitools` (setup-user-hooks.sh) is doing its job for known hooks but has no mechanism for discovering new hooks in shared/hooks/.

OL-56: tool-ops.json is severely stale (last updated 2026-03-15). It documents 1 hook and 1 deny rule when the actual deployed state has 12 hooks and 3 deny rules. Governance mode audits based on this data are working with incomplete information.

OL-57: Neither scratch-init.sh nor harvest-session.sh deletes work product. Both explicitly document the 30-file-loss fix. No work product was lost during failure mode. All scratch directories and session databases are intact.

OL-58: Three releases shipped during failure mode (v0.66.1, v0.67.0, v0.67.1). Code quality within commits appears sound. The failure mode manifested as incomplete pipeline integration across commits, not as bugs within commits. Individual commits are correct; the cross-cutting concern (Stop hook registration) was dropped.

OL-59: The standing-order-guard hook correctly enforces ||, ;, and backticks in the running session (confirmed via mock testing and live hook blocks during this assessment). The hook-rollout.md rule is stale. This is a pre-failure documentation debt (promotion was Mar 24), not a failure-mode artifact.

OL-60: Mission Control at nobulai.tools is live and operational, showing session 2d439e32 data with all tabs functional. The two-pipeline problem (JSON vs SQLite) persists. The export-mission-control.py is in scratch, not promoted.

## Carried forward OL (from all sources)

OL-1 through OL-49: See running-estimate-v1.md.
OL-VP1 through OL-VP10: See verify-and-propose-ol.md.
OL-HD1 through OL-HD10: See hook-design-ol.md.
OL-BR1 through OL-BR8: See blast-radius-ol.md.
OL-TV1 through OL-TV7: See tool-ops-verify-ol.md.
OL-WP1 through OL-WP8: See work-product-inventory-ol.md.

## Total OL count: 60 (OL-1 through OL-49 from running estimate, OL-50 through OL-60 from this assessment)
Plus ~35 mission-specific OL items across 5 mission reports.
