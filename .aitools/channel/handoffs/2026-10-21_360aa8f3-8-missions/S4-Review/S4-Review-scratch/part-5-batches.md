## 5. Combined approval batch and implementation order

### 5.1 Protected files in the one approval batch

Path = repo path (S2-Split may move `.claude/skills/*` paths). "Draft" = where the review copy lives (S4 = `S4-Review-drafts/`, T = `S5-Tools-drafts/`, P = `S5-Profile-drafts/`).

| # | Path | New/edit | Mission | Intent status | Draft |
|---|---|---|---|---|---|
| 1 | `reference/tool-support-decision-tree.md` | new | M2 (+S4 rev 3) | new intent, DRAFT (S4 widened scope: exit-2 contract, /audit additions, hook, shape owner) | S4 |
| 2 | `.claude/rules/tool-lifecycle.md` | edit (rewrite) | M2 (+S4 fixes) | modified intent, DRAFT (S4 rewording per C-31) | S4 |
| 3 | `reference/framework-tool-lifecycle.md` | edit | M2 | modified intent, DRAFT | T (+ C-33 banner placement, C-09 channel row) |
| 4 | `.claude/skills/tool-adopt/SKILL.md` | new | M2 | new intent, DRAFT | T (+ fixes in section 2 / C-08, C-22, C-28) |
| 5 | `.claude/skills/tool-eval/SKILL.md` | edit | M2 | modified intent, DRAFT | T (+ C-08, C-22) |
| 6 | `.claude/skills/tool-registry/SKILL.md` | edit | M2 | modified intent, DRAFT | T (+ C-08) |
| 7 | `.claude/rules/interactive-menus.md` | edit | M2 + M3 (merged) | new intent (file had none), DRAFT | S4 |
| 8 | `.claude/rules/sources-of-truth.md` | edit | M2 + M3 (merged) | new intent (file had none), DRAFT | S4 |
| 9 | `.claude/rules/glossary.md` | edit (7 terms) | M2 + M3 (merged) | unchanged | S4 |
| 10 | `registries/glossary.json` | 7 terms added, `managed tool` modified | M2 + M3 (merged) | n/a | S4 `glossary.terms-draft.json` |
| 11 | `registries/tool-registry.json` | schema 1.1 (+ node/go illustrative entries) | M2 | modified `meta.intent`, DRAFT | T |
| 12 | `registries/framework-registry.json` | edit (Tool lifecycle entry) | M2 | n/a | T (write only once paths exist) |
| 13 | `.claude/rules/managed-file-deployment.md` | edit (2 changes) | M3 + M2 (merged) | none today (incident draft #104) | S4 `.edit.txt` |
| 14 | `.cursor/rules/managed-file-deployment.mdc`, `tool-lifecycle.mdc`, `interactive-menus.mdc` | mirror edits | M2 + M3 | n/a | not drafted (mirror of 2, 7, 13) |
| 15 | `.claude/rules/git-safety.md` | edit (`generated/` fully generated, tracked) | M2 companion | none | not drafted |
| 16 | `reference/script-standards-detail.md` | edit (SHADOWED severity line, `n/a (<platform>)`, `<ver> (kept)`, `under evaluation`) | M2 companion | none | not drafted |
| 17 | `shared/skills/aitool-eval/SKILL.md` | refresh derived card | M2 companion | existing | not drafted |
| 18 | `reference/user-repo.md` | edit (rewrite) | M3 (+S4) | new intent, DRAFT | S4 |
| 19 | `shared/claude-shared.md` + `<dotprofile>/claude/CLAUDE.md` | edit (Cross-Platform Awareness lines) | M3 | n/a | P `claude-shared.md.edit.txt` |
| 20 | `.claude/rules/deploy-paths.md` | edit (setup-user-claude row; aitools-profile.js auto-embedded) | M3 | none | P report §5 |
| 21 | `.claude/rules/config-file-safety.md` | edit (reference example) | M3 | none | P report §5 |
| 22 | code intents: `scripts/aitools-profile.js`, `scripts/setup-user-config.sh/.ps1`, lib section intents (both libs) | new | M3 | new intents, DRAFT | P |
| 23 | `meta.intent` of `~/.aitools/config.json` (in the writers) and dotprofile `profile.json` | new | M3 (+S4 audience) | new, DRAFT | P / S4 profile.json |
| 24 | `registries/incidents.json` | 27 new entries (#87-#113) + `affected` updates to #21, #55, #59, #76 | S4 | n/a | `S4-Review-incidents-draft.json` |
| 25 | Intents for each migrated setup script (M2 B5-B17) | new | M2 | drafted per batch, approved before delegation | not yet |

Pending-decision rows inside the batch: D-TS10/11/12 (marked "pending" in the S4 copy), N-Q1, N-Q3.

### 5.2 Implementation order (one sequence, both missions)

PR #50 (S3-Nine) merged 2026-10-21T02:33Z and PR #52 at 02:44Z (`gh pr list`), so "land after S3-Nine" is satisfied; what remains is re-verifying the plan's `old` blocks against origin/main c491c59 and resetting the local checkout (N-Q5).

| Step | Batch | Files | Depends on | Conflict notes |
|---|---|---|---|---|
| 0 | N-Q5 reset | local `scripts/build-deploy.sh`, `check-hook-parity.py`, `check-post-push.sh/.ps1` → origin/main | -- | commander action |
| 0b | M3 B0 | none | -- | **DONE** (config.json `machineAlias: nobul-mac`; dotprofile bce27bb) |
| G | approval gate | section 5.1 | 0 | one review page |
| 1 | M3 B1 | `aitools-profile.js` (new), `profile-check.js` | G | tests: update `new-mac` in 5 test scripts first (X15) |
| 2 | **X-B1 (new)** | `aitools-profile.js` (`exception-get`/`exception-set`, same temp→validate→backup→move as `register`) | 1 | M3 owns the file; tool semantics from tree §8 |
| 3 | M3 B2 | `aitools-lib.sh`, `aitools-lib.ps1` | 1 | before M2 B2/B3 (same files, X18) |
| 4 | M3 B3, B3b | `setup-user-config.sh/.ps1` (new), `aitools-install.sh`; `aitools-install.ps1` | 3 | before M2 B4a (same files, X19) |
| 5 | M3 B4 | `setup-user-claude.sh/.ps1` | 3 | -- |
| 6 | M3 B5 | `build-deploy.sh` | 1, 5 | re-verify old blocks vs c491c59; P-Q8..Q11 |
| 7 | **X-B2 (new)** | `check-pre-push.sh/.ps1` step 7: pass `AITOOLS_USER_REPO_PATH` explicitly, unset `AITOOLS_PROFILE_FILE`/`AITOOLS_MACHINE_ALIAS`, add `aitools-profile.js` to the trigger regex (S5-Profile-A H5, M7) | 6 | must land before step 8 (first export of the variable) |
| 8 | M3 B6, B7 | `scripts/aitools`, `scripts/aitools.ps1` | 4, 6, 7 | before M2 B4b (same files) |
| 9 | M3 B8a-c | settings/skills/cursor/check-lib/ait-harvest | 3 | -- |
| 10 | M2 B1 | registry 1.1 data (go, typst, vercel-cli) via `/tool-registry`; `scripts/gen-tool-specs.py`; `generated/tool-specs/` | G | needs git-safety.md edit (5.1 #15) |
| 11 | M2 B2, B3 | `aitools-lib.sh`; `aitools-lib.ps1` (tool helpers incl. `tool_exception_get/record` wrapping X-B1) | 2, 3, 10 | bash 3.2 rule |
| 12 | M2 B4a, B4b | installers exit 2; entry points exit 2 | 4, 8 | closes incident draft #87 |
| 13 | M2 conformance step | `check-pre-commit.sh/.ps1` "Tool support conformance" (WARN phase) | 10, 11 | not batched in the M2 report; added here |
| 14 | M2 B5..B17 | one tool script pair per batch, order as M2 (typst, vercelcli, pandoc, rust, go, datadog, uv, gh-cli, python, modal, perl, bash, google-chrome) | 11, 12 | each closes part of #89 (dry run) and #55 |
| 15 | **X-B3 (new)** | `check-post-push.sh/.ps1` step 29: menu parity for `tool_method_menu` and the user init registration menu | 8, 11 | both menus must exist |
| 16 | M3 B9 | protected docs written (approved at G) | G, 1-9 | user-repo.md, claude-shared.md + dotprofile template, rules, glossary |
| 17 | M3 B10 | dotprofile profile.json (re-derived from the live file, X17); each machine runs `aitools user init` once | 8 | commander |
| 18 | **X-B4 (new)** MDM | `build-deploy.sh`: embed `generated/tool-specs`, tool helpers, `deploy/setup-user-config.*` | 6, 9, 11 | P-Q7 + T-Q1; one build-deploy batch |
| 19 | M2 B18+ | setup-node (M4), setup-claude-code, setup-cursor-agent, setup-pwsh via `/tool-adopt` | 14 | also `shared/claude-shared.md` rows (after step 16, same file) |

Docs (step 16) can also land right after G if the commander prefers docs-first; the ordering above lands docs once the code they describe exists, which keeps `/audit` from flagging spec-without-code drift.
