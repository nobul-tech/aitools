# S2-Layout report: user level vs project level in aitools

## Summary (5 lines)
1. Today the level of an artifact is set by an unwritten convention: `shared/` is user level, `.claude/` is project level, and `registries/` and `reference/` carry no level at all. The vocabulary mixes "where the file is authored" with "where it is deployed". The text that explained this was deleted in b504c43, and nothing checks it.
2. **Recommendation:** make the folder decide the level, keep the existing folder names, and enforce the rule with checks. Move 7 skills (L1's 4 plus incident, glossary, frameworks) into `shared/skills/`. Move registries to `shared/registries/`. Add `shared/rules/`. Reach registries through one small deployed resolver (`aitools-registry.py`), with a read-only snapshot in `~/.aitools/registries/`.
3. **Not recommended:** renaming `shared/` to `user/`. It breaks every bash/zsh startup (the installer never rewrites the `source` line), touches about 89 files, and "user" already has two other meanings.
4. **Q-A:** `git mv`, never two copies. **Q-B:** you approve the protected spec in this report up front, and the delegate then ships 3 small atomic PRs.
5. **Urgent:** do not run `aitools` until the 9 untracked `shared/skills/` copies are deleted. They would deploy as same-name user skills with stale paths. 18 INCIDENT findings are in section 7.

Baseline: aitools HEAD 04cbdf0 (it moved from 51a34d8 during this mission). Evidence: S2-Layout-evidence.md. Sub-reports: S2-Layout-A-deploy-map.md (deploy), S2-Layout-B-registry-consumers.md (registry paths), S2-Layout-C-review.md (adversarial review).

## 1. Today's flow

```
AUTHORED IN GIT                              DEPLOYED BY                        LANDS IN / LOADED BY
aitools repo
  .claude/skills/  (9, project)   -- nothing (auto-discovered) ---------> aitools sessions only (+ cloud clone)
  .claude/rules/   (25, project)  -- nothing -----------------------------> aitools sessions only (Claude Code)
  .cursor/rules/   (19 .mdc)      -- nothing -----------------------------> aitools sessions only (Cursor)
  shared/skills/   (14 + 9 untracked) setup-user-skills  ---------------> ~/.claude/skills, ~/.cursor/skills (all repos)
                                   build-deploy (embeds SKILL.md) -----> dotprofile deploy/ (MDM)
  shared/hooks/ + scripts/ait-harvest.py  setup-user-hooks -------------> ~/.claude/hooks + settings.json
  shared/claude-shared.md          setup-user-claude (fallback) / MDM --> ~/.claude/CLAUDE.md
  scripts/harness-db.py, read-session*.py  aitools install step 6 -----> ~/.aitools/bin
  registries/*.json (6)            -- NOTHING --------------------------> read by cwd-relative paths = aitools cwd only
  reference/*.md                   -- NOTHING --------------------------> same
dotprofile repo
  claude/CLAUDE.md                 setup-user-claude (wins) ------------> ~/.claude/CLAUDE.md   (MDM uses shared/ instead!)
  claude/rules/ (2)                setup-user-claude + MDM ------------> ~/.claude/rules
  claude/skills/ (30 firecrawl)    setup-user-skills (wins; not MDM) --> ~/.claude/skills (through symlinks), ~/.cursor/skills
Bridges for other repos: user-level "reference cards" aitool-ops / aitool-eval = snapshot copies of
/tool-ops and /tool-eval knowledge; their trigger rules are project rules, so they never load outside aitools.
```
Sources: S2-Layout-A §1-8, evidence E1.

## 2. Current state

| Artifact class | Authored | Level today | Reads repo-only paths? | Who needs it | Drift / defects |
|---|---|---|---|---|---|
| Governance skills (tool-ops, tool-eval, tool-registry, harvest, incident, glossary, frameworks) | `.claude/skills/` | project | yes, cwd-relative registries/reference (B) | every repo (dotprofile CLAUDE.md:8; harvest runs everywhere; /investigate and the glossary hook route to them) | 4 of 7 cite the dead `reference/*.json` paths; untracked byte-identical copies sit in `shared/skills/` |
| audit, governed-data | `.claude/skills/` | project | yes (`.claude/rules`, registries) | aitools developers only | /audit has stale paths |
| Process skills (planning, handoff, delegate, investigate, scratch, ...) | `shared/skills/` | user | intent-audit and optimize-plan cite dead `reference/*.json` | every repo | ~/.claude/skills is months stale (5 DIFF, `delegate` ABSENT) |
| Reference cards (aitool-ops, aitool-eval) | `shared/skills/` | user | no (embedded snapshot) | other repos | duplicate knowledge; trigger rules never load outside aitools |
| Personal skills (firecrawl x30) | dotprofile `claude/skills/` (untracked) | user | no | Jose | deployed through symlinks into ~/.agents; rules/ subdir dropped; not in MDM |
| Project rules | `.claude/rules/` | project | n/a | aitools sessions | aitool-ops.md / aitool-eval.md hold cross-repo triggers |
| Cursor rules | `.cursor/rules/` (+ `shared/cursor-rules/` templates) | project / manual | n/a | aitools Cursor sessions | user-rules.md:7 describes a clipboard copy that does not exist |
| User rules | dotprofile `claude/rules/` | user | n/a | every repo | `delegation.md` not deployed on this Mac; no harness-owned (shared) rule source |
| Hooks | `shared/hooks/` | user | 4 hooks hardcode `$HOME/repos/aitools` | every repo | tool-ops-session-audit dead since 2026-06-15 (#70); 3 hooks DIFF from deploy |
| Registries (6, 262 KB) | `registries/` | none (repo-only) | consumers use cwd paths | user-level skills and hooks + checks | 52 stale `reference/*.json` refs; PS1 post-push still on the old path |
| Reference docs | `reference/` | none | — | skills cite them | — |
| Deployed helpers | `scripts/*.py` | user (~/.aitools/bin, ~/.claude/hooks) | — | hooks | only `install` refreshes them; `~/.aitools/bin/aitools` and `hh.sh` are orphans |
| CLAUDE.md template | dotprofile / `shared/claude-shared.md` | user | — | every repo | dev path and MDM path deploy different templates |

**Why the split became confusing (light RCA; full version in evidence E5):**
- Folder names don't say where things deploy. `.claude/skills` is both the project folder and the name of the user target.
- The scope-modifier vocabulary mixes source location with deployment target.
- The prefix convention is inverted: the plan says project counterparts use `aitools-`, but the user-level cards use `aitool-`.
- The CLAUDE.md explanation was deleted, and requirements moved (harvesting in every repo, the cross-repo CLAUDE.md order) while placement stayed put.
- Nothing detects a same-name skill or a dead path.
- **Root cause:** no framework governs artifact placement. I checked the registry with /frameworks: 13 adopted plus 2 pending, and none covers placement.

## 3. Recommended structure

### Alternatives considered

| Option | Verdict | Why |
|---|---|---|
| **A. Folder = level, keep names, enforce with checks (chosen)** | pick | Makes the level obvious from one rule. About 5% of the churn of a rename, and every move it makes is one we need anyway |
| B. Rename `shared/` to `user/` (my first draft) | reject for now | 1. Breaks shell startup: `aitools-install.sh:614-628` writes the absolute `source .../shared/shell/aliases.sh` once and never rewrites it. 2. About 89 live files plus CI and deployed `~/.aitools/bin` copies. 3. "user" already means "deployed to ~/" and "user repo" = dotprofile, so a third meaning works against L4 (S2-Layout-C E2-E4). Could be a later standalone PR with a different name (e.g. `home/`) |
| C. Package as a plugin (`/aitools:incident`) | reject | Plugins don't load in cloud sessions (Claude Code docs, skills page). Adds marketplace machinery, and namespaced names break muscle memory (governance plan decision 19) |

### The rule (three lines; goes in shared/README.md, CLAUDE.md, documentation-standards.md)
1. `shared/**` deploys to user level (`~/.claude`, `~/.cursor`, `~/.aitools`, shell rc) and works in every repo.
2. `.claude/**` and `.cursor/**` are project level: they load only in sessions on aitools and are never deployed.
3. Everything else (`scripts/`, `reference/`, `plans/`, `generated/`, `deploy/`) is aitools source or docs. It reaches a user only through a deploy script, and the resolver is how user-level skills read it.

### Before → after tree (only the parts that change)

**Before:**
```
aitools/
  .claude/skills/   audit frameworks glossary governed-data harvest
                    incident tool-eval tool-ops tool-registry
  .claude/rules/    aitool-ops.md aitool-eval.md ... (25)
  registries/       6 x .json
  shared/skills/    14 tracked + 9 untracked copies
                    (incl. aitool-ops, aitool-eval)
  shared/hooks/     ...
  scripts/          harness-db.py read-session*.py ait-harvest.py ...
```

**After:**
```
aitools/
  .claude/skills/   audit governed-data (+ tool-adopt from S5-Tools)
                    → project level: these edit or audit aitools source
  .claude/rules/    aitools-development rules only (aitool-*.md deleted)
  shared/README.md  NEW: folder → target map + one-name rule
  shared/skills/    14 + harvest incident glossary frameworks
                    tool-eval tool-ops tool-registry
                    (aitool-ops and aitool-eval retired in PR-c)
  shared/rules/     NEW → ~/.claude/rules
                    harness-skills.md (trigger directives)
  shared/registries/  6 x .json → ~/.aitools/registries (read-only snapshot)
  shared/bin/       NEW: aitools-registry.py → ~/.aitools/bin
  shared/hooks/     fallbacks use the resolver, not $HOME/repos/aitools
  scripts/          unchanged
                    (deployed .py helpers: later PR-d → shared/bin)
  generated/        committed derived files (S5-Tools tool-specs); never deployed
```

### Naming rules
- **N1. The folder shows the level, never a prefix.** No `aitool-`/`aitools-` level prefixes in new names. The existing `aitool-continue` keeps its name.
- **N2. One name, one place.** A skill or rule name exists in exactly one of `shared/`, `.claude/`, or dotprofile `claude/`. A pre-commit check fails otherwise. This replaces the silent "dotprofile wins" (`setup-user-skills.sh:93`), which is the incident #80 shadowing pattern.
- **N3. Skill level test.** If the skill is useful in a session on any repo, even read-only, it is user level. If it is meaningful only inside the aitools working tree, it is project level. `<name>-dev` is used only for real two-persona splits (the existing rule).
- **N4. No governed-data paths in prose.** User-level skills reach registries and aitools docs through `aitools-registry` (`path|get|next-id|validate|mode`). Rules cite skills, not JSON paths (#50).
- **N5. Generated files have two homes.** `deploy/` is ephemeral MDM output. `generated/` holds committed derived files. Never hand-edit either.

### Registries (L2)
- **Authored:** in git at `shared/registries/`. The review gate is unchanged; only the path in `sources-of-truth.md` changes.
- **Resolver:** code, not prose. A stdlib Python CLI deployed like `harness-db.py`, so it is cross-platform and Windows already runs Python hooks (`ait-harvest.py`). It resolves in this order:
  1. **Live clone:** `AITOOLS_REPO_PATH`, then config.json `repoPath`. Read-write only when cwd is a worktree of that clone (git common-dir check), so PR worktrees work.
  2. **Snapshot:** `~/.aitools/registries/` plus `.source.json` {commit, builtAt}. Written by setup-user-skills as the sole owner, and embedded by build-deploy for MDM. Read-only; writes become a `gh issue` on nobul-tech/aitools (RFC 0001).
  3. **None:** say "unavailable" and stop.
- **`next-id`** fixes the duplicate-ID risk: incidents.json is 2,027 lines, longer than Read's 2,000-line default.

## 4. Deferred questions

**Q-A. Delete the project original (`git mv`) or keep both?** I recommend `git mv` with no copies, for four reasons:
- Claude Code resolves a shared name as "personal over project" (docs). With both copies, the deployed one wins, and it is often stale: this Mac's deploy is months behind (evidence E3). That makes the project copy dead code that still drifts.
- documentation-standards.md already forbids same-name skills at both levels.
- Symlinks are no fix. Windows git defaults to `core.symlinks=false`, and a symlink still produces a same-name pair.
- The cost: Claude Code web sessions on aitools lose project-level loading of the 7 skills. Test it before PR-b merges (section 5, step V5). The fix is environment setup or claude.ai account skills, not a second copy.
- Do the 9 untracked copies now: delete them (byte-identical, so nothing is lost). PR-b re-creates them properly with `git mv` and fixed paths.

**Q-B. Draft PR with the protected edits, or drafts first?** Neither as stated. I recommend approving the spec up front, then shipping 3 small atomic PRs:
- You approve the protected content in evidence E6 (path map) and E7 (drafts D1-D6) now. That counts as the review step, the same as user-dictated content in sources-of-truth.md.
- The delegate ships each PR with exactly that content. Anything beyond the approved spec comes back as a draft (D-DEL4 limit).
- Not split by protection: an "unprotected-only" PR would leave rules pointing at moved files. That is the same one-pass failure that left 52 stale paths after v0.69.0.
- Not one big PR: that goes against smaller batches and plan-execution.md.
- The PR review is a second check, not the approval.

## 5. Migration plan (for the follow-up delegate)

**Step 0. Session commander, now.** Delete the 9 untracked `shared/skills/*` copies. Do not run `aitools` before then.

**PR-a `fix/registry-paths`: detection first, closes #84 and the stale paths.**
1. **Batch 1.** New pre-commit step "path references" in check-pre-commit.sh/.ps1. Every backticked repo path in skills, rules, reference, hooks and .cursor must exist. Fix step 16 at the same time: the PS1 pattern misses `registries/`, add tool-ops and tool-versions, and add the new `shared/rules` scope.
2. **Batch 2.** Fix the 52 stale references listed in S2-Layout-B tables 1-2. Include check-post-push.ps1:268,520 and tool-ops-session-audit.sh:23-26 (#70).
3. **Verify:** the new check fails on a seeded bad path and passes after the fixes, on bash and PS1.

**PR-b `feature/user-level-governance`: L1, L2, rules, resolver.** Each batch is at most 3 logic files.
1. **Batch 1.** `shared/bin/aitools-registry.py` plus unit tests in `tests/`. Deploy it to `~/.aitools/bin` from **both** `aitools` update and install. Today only install step 6 writes there.
2. **Batch 2.** `git mv registries shared/registries`. Snapshot write and `.source.json` in setup-user-skills.sh/.ps1. Embed in build-deploy.sh. Add the snapshot deployment-type row (P).
3. **Batch 3.** `git mv` the 7 skills into `shared/skills/`, then rewrite their data paths to resolver calls. Add a prune of retired skill names in setup-user-skills, which has no prune today.
4. **Batch 4.** `shared/rules/harness-skills.md` (D3). Add `shared/rules` as a rule source in setup-user-claude.sh/.ps1 and build-deploy.sh. Add the N2 same-name check across shared, `.claude` and dotprofile.
5. **Batch 5.** Hooks: replace the `$HOME/repos/aitools` fallbacks with the resolver (tool-ops-session-audit, session-archive:67, scratch-init:103, dashboard-serve:58).
6. **Batch 6 (docs, P, approved spec).** Every path in evidence E6:
   - CLAUDE.md, documentation-standards (D2), glossary (D1)
   - framework-governed-vocabulary, user-repo.md, harness.md, deploy-paths, managed-file-deployment (rule and reference)
   - governed-data-access, sources-of-truth (cite skills; closes #50)
   - .cursor mirrors, claude-shared.md, dotprofile CLAUDE.md:8 (dotprofile repo PR)
   - CI `check.yml`
   - Delete `.claude/rules/aitool-ops.md` and `aitool-eval.md`
   - Add a "Placement" section to the Managed file deployment framework entry (`/frameworks`, P)
7. **Verify:**
   - **V1.** Isolated HOME install, then: `~/.claude/skills` has the 7 skills, `~/.aitools/registries/.source.json` matches HEAD, and `~/.claude/rules/harness-skills.md` exists.
   - **V2.** From a non-aitools repo, a fresh session: `/glossary` resolves a term in live mode, and with `repoPath` unset it resolves from the snapshot in read-only mode.
   - **V3.** A write attempted from outside the clone produces a `gh issue` draft, not a file edit.
   - **V4.** build-deploy under an isolated HOME: the MDM `setup-user-skills.sh` embeds the 7 skills, the snapshot and the shared rules.
   - **V5.** Claude Code web: after `aitools install`, does a new session list the 7 skills? If not, add the claude.ai account-skills route, or an environment setup script that installs before session start.
   - **V6.** All check scripts pass on macOS, and on Windows PS1 (or note it as untested).

**PR-c `refactor/retire-reference-cards`.**
- Fold aitool-eval's unique sections (gotcha catalog, quick checks, sandbox protocol, Perl exemplar) into `/tool-eval` and `reference/tool-evaluation-playbook.md`.
- Fold aitool-ops's into `/tool-ops`. Delete both cards and add them to the prune list.
- Repoint the citers: delegate/SKILL.md:143,163,217 and aitool-continue:557-558.
- Dotprofile `delegation.md:10,132` is a protected, commander-owned file, so it gets a separate dotprofile PR with approved text.

**PR-d (optional, later):** move the deployed `.py` helpers from `scripts/` to `shared/bin`. Decide the `shared/` rename on its own merits, with an installer that rewrites the rc `source` line.

**PR body outline** for each PR: the commits; the approved-spec reference (this report §E6/E7); the V-results that were run and the ones that were not; and any `(tested: macOS)` notes.

**Sibling-mission impacts (do not edit their work):**
- **S5-Tools:** `/tool-adopt` stays in `.claude/skills/` under N3. Its `/tool-eval` and `/tool-registry` edits and schema 1.1 must target `shared/` paths once PR-b lands, so sequence them.
- **S4-Review:** its sources-of-truth draft re-lists `registries/*.json` and needs the new path and the skill citations.
- **S5-Profile:** unaffected, except that config `repoPath` gains a real consumer (the resolver).

## 6. Open questions for the commander

| # | Question | Recommended answer |
|---|---|---|
| 1 | Should audit and governed-data stay project-level? Your copies (L3) suggest moving all 9 | Keep them project-level. They only make sense inside the aitools tree (N3), and S5-Tools' /tool-adopt joins them. Say "move all 9" and the plan adds 2 skills to PR-b batch 3 |
| 2 | Do you approve the protected spec (evidence E6 path map, E7 D1-D6) as the review step under Q-B? | Yes. Anything beyond it comes back as a draft |
| 3 | Should we delete the 9 untracked `shared/skills` copies now, before any `aitools` run? | Yes. They are byte-identical, and PR-b re-creates them properly |
| 4 | How should Claude Code web get the user-level skills if V5 fails? | claude.ai account skills for the 7. Do not keep project copies |
| 5 | Rename `shared/` at all? | Not now. Revisit after PR-b with an rc-rewrite fix. A name like `home/` avoids the "user" collision |
| 6 | Does `tool-versions.json` (no skill, hand-edited) move with the registries? | Yes, into `shared/registries/` so all governed data lives in one place. Give it a governing skill later |

## 7. INCIDENT findings (not filed; for the session commander)

| # | Sev | Finding | Source |
|---|---|---|---|
| 1 | high | The 9 untracked `shared/skills` copies would deploy on the next `aitools`/build as same-name user skills with stale paths | setup-user-skills.sh:60-67, build-deploy.sh:1105-1116 (A, B) |
| 2 | high | Windows post-push step 10 always FAILs and step 21 always SKIPs: PS1 is still on `reference/tool-versions.json` | check-post-push.ps1:268,520 vs .sh:233,448 [verified] |
| 3 | high | No check verifies repo path references exist. The registries move left 52 dead refs and a dead hook for 4 months (#70, #84 are symptoms) | B; b2641c0 |
| 4 | medium | Pre-commit step 16: the PS1 pattern misses `registries/`, neither version covers tool-ops or tool-versions, and the claimed "@-referenced files" scope is not implemented | check-pre-commit.ps1:336, .sh:339-341 (B) |
| 5 | medium | Hooks hardcode `$HOME/repos/aitools` instead of config `repoPath`, which is wrong in Claude Code web and on any custom path | tool-ops-session-audit.sh:25, session-archive.sh:67, scratch-init.sh:103 [verified], dashboard-serve.sh:58 |
| 6 | medium | MDM parity gaps: build-deploy never embeds dotprofile skills, and deploys hooks with `cat >` (no backup or review, dotprofile hooks ignored) | build-deploy.sh:1105-1125, 1302-1321 (A) |
| 7 | medium | setup-user-skills has no prune, so renamed or retired skills persist in `~/.claude/skills` and `~/.cursor/skills` forever | A §1 |
| 8 | medium | setup-user-skills writes through `~/.claude/skills/firecrawl*` symlinks into `~/.agents` (a third-party installer's directory). The dotprofile firecrawl copies are untracked, and their `rules/` subdir is dropped | A §1 |
| 9 | medium | The installer never rewrites the shell rc `source` path once the marker exists, so any move of `shared/shell` breaks shell startup (latent) | aitools-install.sh:614-628 [verified] |
| 10 | medium | `/incident` "read and note highest ID": incidents.json is 2,027 lines, over Read's 2,000-line default, so the duplicate-ID risk is real | `wc -l` [verified] (C E8) |
| 11 | medium | The trigger rules for cross-repo skills (`aitool-ops.md`, `aitool-eval.md`) are project rules that never load outside aitools | .claude/rules/aitool-ops.md:30, aitool-eval.md:33 |
| 12 | medium | No framework governs artifact placement (governance gap) | /frameworks coverage check |
| 13 | low | Prefix inversion: the plan says project counterparts use `aitools-`, but the user cards use `aitool-` (terminology ambiguity → /glossary) | plans/governance-and-compliance-framework.md:133 |
| 14 | low | `~/.aitools/bin` helpers are refreshed only by `install`, not by `aitools` updates. `~/.aitools/bin/aitools` and `hh.sh` are orphans with no writer | aitools-install.sh:547-598 (A §5) |
| 15 | low | The PreToolUse validator for incidents.json and the SubagentStart cache described in incident-governance.md do not exist in hooks-manifest.json | B, C E9 |
| 16 | low | `tool-versions.json` has no governing skill (three-layer gap) | B |
| 17 | low | `shared/cursor-rules/user-rules.md:7` describes a setup-user-cursor clipboard copy that was removed | A §3 |
| 18 | low | The user CLAUDE.md says to open RFC 0001 issues on `nobul-Jose/aitools`, but the remote is `nobul-tech/aitools` (redirect not verified) | `git remote -v` |

Already filed and confirmed by this mission: #50 (sources-of-truth.md cites JSON paths), #59 (incomplete: it lists only /incident and /glossary, but /frameworks, /audit, /tool-ops:106, intent-audit and optimize-plan are also stale), #70, #80, #84. The dev-vs-MDM CLAUDE.md template mismatch is S5-Profile's incident.

No WRITE_BLOCKED events. Nothing was written outside S2-Layout/. Firecrawl was out of credits ("Your Firecrawl credits ran out. Add credits or upgrade to keep going: https://www.firecrawl.dev/billing/9cnjpy2dhjkfcb02j5g29t6s64ya80na"), so the Claude Code docs were read with WebFetch.
