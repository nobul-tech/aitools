# S3-MA-ScrubRules findings

**Version:** v1.0 · **Written:** 2026-10-27 · **By:** S3-MA-ScrubRules (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose)
**Scope:** every `.claude/rules/*.md` (24 files) and `.cursor/rules/*.mdc` (18 files) in `/Users/new-jose/repos/aitools`, checked against the code on origin/main at `0a8c487` (`git pull --ff-only`: already up to date). Read-only audit: no rule was edited.
**Method:** each rule read in full from disk; every checkable claim probed with read-only scripts in `.scratch/session-scrubrules/probe1.sh` … `probe5.sh` (grep/sed/python over `scripts/`, `shared/`, `registries/`, `reference/`, `CLAUDE.md`, `ROADMAP.md`, `RELEASE_NOTES.md`). Line numbers are the rule file's lines at `0a8c487`.

Severity: **H** = an agent following the rule does the wrong thing; **M** = false or stale statement, misleads but rarely harms; **L** = wording, parity or style.

---

## 0. Operational learning for whoever applies these

- **Read the rules from disk, not from the injected context.** This session's system context carried copies of `.claude/rules/aitool-eval.md` and `aitool-ops.md` (both retired in 7edbb84 / PR #129) and older text of `cross-platform.md`, `aitools-workspace.md`, `interactive-menus.md`, `managed-file-deployment.md`. The context is a snapshot from session start; long-running orchestrators hand delegates stale rules. Delegation prompts should keep saying "Read each rule by absolute path".
- Applying these replacements is a protected-file edit (`.claude/rules/*.md`, `.cursor/rules/*.mdc`). S3-MA-Versions hit `WRITE_BLOCKED ... [Self-Modification]` on exactly this class (S3-MA-Versions-log.md:17). Expect the same; the commander may need to apply them or grant the allowance.
- Every `.claude/rules` change needs its `.cursor/rules` twin (cursor-rule-parity.mdc:9).

---

## 1. sources-of-truth.md / sources-of-truth.mdc

### F1 (H, contradictory) — pre-write gate contradicts D-DEL5 / A2 review-after
- **Where:** `.claude/rules/sources-of-truth.md:3` ("so they require user review before being written"), `:36-42` (Draft / Present / Wait for approval), `:44-47`, `:49-56` ("Draft the intent, present for user review, write only after approval"), `:58-60`. Twin: `.cursor/rules/sources-of-truth.mdc:9`, `:29-44`.
- **Evidence:** commander decision A2 (brief §2, 2026-10-26T22:59:58Z) "User rule + skill; review after"; the dotprofile user rule D-DEL5 (commit 20683a2) and `shared/skills/delegate/SKILL.md:150-159` already say protected files are written as a version, committed, and reviewed after. The project rule still says "do not write until the user confirms". An agent reading only the project rule follows the old gate (S3-MA-Versions-log.md:83-87).
- **Replacement (md):** apply the v1.0 text recorded verbatim in `S3-MA-Versions-log.md:40-79` (intro paragraph, "The rule", "Exceptions", "Intent statements", "Why this matters"). It is complete and matches the delegate skill; I found nothing in the code that changes it.
- **Replacement (mdc), `:9`:**
  > Certain files are authoritative references that feed scripts, deploy pipelines, or govern AI agent behavior. Changes to these files propagate across machines and affect real workflows, so the commander reviews every change to them. The review comes after the write (review-after, D-DEL5): the change is written as a version and committed, and the commander reviews the diff.
- **Replacement (mdc), `:29-35` "The rule":**
  > Review-after (D-DEL5, commander decision 2026-10-26). Protected changes are versions, never drafts held back for approval. To write, edit, or delete content in any protected file:
  > 1. **Write the version** -- make the change in the file itself, in its final location (new document v1.0; a revision bumps the version where the file records one). Never park it as a "draft" elsewhere.
  > 2. **Commit it** -- through a PR, or direct to main where CLAUDE.md "Channel exception" allows (plans/, handoffs, relay.md, CLAUDE.md). The PR or commit body lists every protected edit under **Review after**: full content for new sections, old -> new for edits.
  > 3. **Present the diff** -- name the commit or PR and the protected files in your response. A change the commander asks for ships as the next version; a change he rejects is reverted by a new commit.
  >
  > Approval after the fact replaces the pre-write gate. It does not cover merging, tagging, deleting, publishing, or pushing to another repo's main: those still need his explicit order.
- **mdc `:39-40` Exceptions:** "may be made without review" -> "need no Review after entry, but mention them in your response"; "that counts as pre-approved. Write it directly." -> "write it directly and say so in the commit body."
- **mdc `:44` last sentence:** "The review step keeps the agent and user in sync." -> "Review-after keeps the agent and user in sync without a pre-write wait: every protected change is a visible commit with a Review after list, which the commander reads and can revert."

### F2 (M, missing) — the rule never mentions the CLAUDE.md "Channel exception"
- **Where:** `sources-of-truth.md:12` (`CLAUDE.md` protected), `:20` (`plans/*.md` protected); no mention of how they are committed.
- **Evidence:** `CLAUDE.md:79-84`: handoffs, relay.md, `plans/*` and `CLAUDE.md` are committed directly to main from the main checkout, no worktree, no PR (commander 2026-10-26).
- **Replacement:** covered by F1 step 2 ("or direct to main where CLAUDE.md 'Channel exception' allows"). No separate edit if F1 lands.

### F3 (M, false) — "the five components"
- **Where:** `sources-of-truth.md:30`.
- **Evidence:** `reference/harness.md:91` "The six components form a dependency chain".
- **Replacement:** `| \`reference/harness.md\` | Harness architecture — the six components and their relationships | Any |`

### F4 (M, contradictory) — frameworks.md called "registry of registries"
- **Where:** `sources-of-truth.md:28`.
- **Evidence:** `frameworks.md:29-31`: "Registries and their governing skills are documented in the framework registry itself (via `/frameworks` skill). Do not duplicate that inventory here — this rule governs the pattern, not the instances."
- **Replacement:** `| \`.claude/rules/frameworks.md\` | Framework rule — check-before-assuming principle, three-layer registry pattern, /frameworks trigger | Any |`

### F5 (L, redundant) — row for `.claude/rules/managed-file-deployment.md`
- **Where:** `sources-of-truth.md:16`, already covered by `:15` (`.claude/rules/*.md`).
- **Replacement:** delete the row, or keep it and change the third column to "Any (also covered by `.claude/rules/*.md`)". Suggest delete.

### F6 (M, parity) — the .mdc table lacks 13 rows the .md has
- **Where:** `sources-of-truth.mdc:13-27`.
- **Evidence:** missing from the mdc: `.claude/rules/managed-file-deployment.md`, `registries/incidents.json`, `reference/managed-file-deployment.md`, "Intent statements in any file", `reference/framework-*.md`, `registries/framework-registry.json`, `.claude/rules/frameworks.md`, `reference/incident-*.md`, `reference/harness.md`, `registries/glossary.json`, `registries/tool-ops.json`, `reference/framework-tool-ops.md`, `reference/tool-ops-*.md`. The mdc also has no "Intent statements" section (md `:49-56`).
- **Replacement:** copy the md table (with F3/F4/F5 applied) and the md "Intent statements" section (as rewritten in S3-MA-Versions-log.md:66-74) into the mdc.

---

## 2. git-safety.md / git-safety.mdc

### F7 (H, stale) — "deploy/ is 100% generated by build-deploy.sh" describes the frozen aitools deploy/
- **Where:** `git-safety.md:3-11`; twin `git-safety.mdc:12-20`.
- **Evidence:** `build-deploy.sh:236` `DEPLOY_DIR="$_urp/deploy"` (the dotprofile), `:738` builds in `$BUILD_TMP/deploy`, `:2716` swaps in; `deploy-paths.md:25-27` "The shared `aitools/deploy/` is frozen (no longer regenerated)". So `build-deploy.sh` no longer leaves diffs in aitools `deploy/`, and nothing in aitools `deploy/` is "committed as part of the normal release flow". The pre-pull reset is still real: `scripts/aitools:2044,2065`, `scripts/aitools.ps1:1961`.
- **Replacement (both files), section "deploy/ is ephemeral":**
  > ### deploy/ is frozen and reset before every pull
  >
  > The aitools `deploy/` directory is frozen: `build-deploy.sh` no longer writes it. It generates the MDM scripts into the dotprofile's `deploy/` (`<userRepoPath>/deploy/`), backing up the old tree to `deploy.bak.<UTC>/` (5 kept) and swapping the new one in only on success (`@.claude/rules/deploy-paths.md`). The `aitools` entry points still reset the aitools `deploy/` to HEAD before every pull (`git checkout HEAD -- deploy/` in `scripts/aitools` and `scripts/aitools.ps1`), so any local edit there is discarded by design. Do not edit or commit aitools `deploy/`; change `scripts/` or `shared/` and rebuild the dotprofile `deploy/`.
- **Pre-pull reset scope rule (`:22-27`):** accurate; keep.

---

## 3. deploy-paths.md / deploy-paths.mdc

### F8 (H, contradictory) — md says pre-commit steps 3+10 no longer apply; mdc says verify with them; the code still runs them against the wrong tree
- **Where:** `deploy-paths.md:91` vs `deploy-paths.mdc:31` ("Verify via pre-commit steps 3+10").
- **Evidence:** `check-pre-commit.sh:103-121` step 3 "Build freshness": with `--fix` it runs `bash build-deploy.sh` (which resolves and replaces the real dotprofile `deploy/` when HOME is not isolated) and then `git add deploy/` in aitools, a no-op on the frozen tree; `:221-232` step 10 diffs aitools `deploy/`, which build-deploy never touches, so it can only pass. PS1 twin: `check-pre-commit.ps1:112`.
- **Replacement (mdc `:31`):** "3. Verify the dotprofile `deploy/` includes the change (the shared `aitools/deploy/` is frozen; pre-commit steps 3 and 10 still inspect it and prove nothing about the dotprofile build)".
- **Replacement (md `:91`):** "3. Verify the dotprofile `deploy/` includes the change. Pre-commit steps 3 and 10 still inspect the frozen `aitools/deploy/` and prove nothing (incident below); `check-pre-push` step 7 is the real check."
- **INCIDENT:** pre-commit step 3 (`--fix`) runs `build-deploy.sh` against the real dotprofile from any session that passes `--fix`, and steps 3/10 check a frozen tree. Same class in post-push step 7 (`check-post-push.sh:204-211`): it runs `build-deploy.sh` (real dotprofile, no HOME isolation) then `git diff deploy/` on aitools, so it always passes and rebuilds the commander's dotprofile as a side effect. Suggest retiring both steps (as step 28 was retired) or pointing them at a temp copy like pre-push step 7.

### F9 (M, false) — "incident I6, see ROADMAP.md"
- **Where:** `deploy-paths.md:174-176`.
- **Evidence:** `ROADMAP.md` has no "I6"; `ROADMAP.md:63` lists "Eliminate deploy template duplication | v0.25.1 | Sentinel-based extraction ... ~507 lines removed" under Completed. Only `setup-user-hooks` keeps duplicated logic (`deploy-paths.md:110-112`).
- **Replacement:** "The remaining duplication (hook-script embedding and REGS_JSON injection in `setup-user-hooks`) is known technical debt. The general extraction was done in v0.25.1 (ROADMAP.md Completed, 'Eliminate deploy template duplication'); there is no open roadmap item or incident for the rest. File one via the `/incident` skill if it needs tracking."

### F10 (L, false) — "`shared/skills/*.md` → read via `cat`"
- **Where:** `deploy-paths.md:144`; twin `deploy-paths.mdc:57`.
- **Evidence:** skills are directories holding `SKILL.md` (`ls shared/skills`); `build-deploy.sh:1429,1520` "Dynamically discover and embed all skills from shared/skills/".
- **Replacement:** "- `shared/skills/<name>/` (each skill's `SKILL.md` and files) → discovered and embedded at build time"

### F11 (M, parity/stale) — mdc MDM path and rebuild steps still name the aitools `deploy/`
- **Where:** `deploy-paths.mdc:12` ("MDM path (`deploy/setup-*.sh/.ps1`)"), `:25` ("Run `build-deploy.sh` to regenerate `deploy/`"), `:30` (same).
- **Evidence:** as F7.
- **Replacement `:12`:** "2. **MDM path** (`<userRepoPath>/deploy/setup-*.sh/.ps1`): self-contained, personalized, generated by `build-deploy.sh` into the user's dotprofile repo. The shared `aitools/deploy/` is frozen."
- **Replacement `:25`/`:30`:** "Run `bash scripts/build-deploy.sh` to regenerate `<userRepoPath>/deploy/` (agents: only under an isolated `HOME` with a copy of the dotprofile)".

---

## 4. aitools-workspace.md (no .mdc twin)

### F12 (M, false) — scratch and harvesting live at the repo root, not under `.aitools/`
- **Where:** `aitools-workspace.md:39` (`scratch/` under `<repo>/.aitools/`), `:43` (`harvesting/` under `<repo>/.aitools/`), `:70-75` ("Decision #34 ... namespace consolidation (`.scratch/` → `.aitools/scratch/`, `harvesting/` → `.aitools/harvesting/`) ... are the governing decisions").
- **Evidence:** `shared/hooks/scratch-init.sh:40` `SCRATCH_DIR="$PROJECT_ROOT/.scratch"`; `scripts/ait-harvest.py:792` `harvesting_dir = project_root / "harvesting"`; `.aitools/harvesting` does not exist; `harvesting/harvest-manifest.json` is tracked at the root (git status). `.aitools/scratch/` exists but holds only two hand-made items (S3-Ledger-Review/, a licence snapshot), not session dirs.
- **Replacement (table rows):**
  > | `<repo>/.scratch/` (repo root) | gitignored | Session-ephemeral working files; one `session-<id>/` per session, path in `.scratch/.current-session` (`scratch-init.sh`) |
  > | `<repo>/harvesting/` (repo root) | tracked | Artifact lifecycle — candidates for harness promotion; manifest `harvest-manifest.json` (`ait-harvest.py`) |
- **Replacement (`:70-75`):**
  > ### Decision #34 status
  >
  > Planning brief decision #34 is superseded by this rule for the cross-machine carry-forward principle. The namespace consolidation it proposed (`.scratch/` → `.aitools/scratch/`, `harvesting/` → `.aitools/harvesting/`) is **not implemented**: the hooks and `ait-harvest.py` use `.scratch/` and `harvesting/` at the repo root. Treat the root paths as current until a plan moves them.

### F13 (M, stale) — `deploy-state/` listed as live
- **Where:** `aitools-workspace.md:50`.
- **Evidence:** `aitools-lib.sh:1065-1072` "Deploy state (~/.aitools/deploy-state/) is no longer used ... left on disk"; `check-post-push.sh:737-741` step 28 retired; `agentic-standards.md:58` "There is no ancestor and no deploy state".
- **Replacement:** `| \`deploy-state/\` | Retired: older versions kept last-deployed hashes here; the managed-file model keeps no deploy state (SOURCE is the source of truth). Left on disk, unused |`

### F14 (H, false) — rules "copied to each tool's rules location by setup-user-claude / setup-user-cursor"
- **Where:** `aitools-workspace.md:54`; same claim in `managed-file-deployment.md:48` ("Rules reach the tools through the `setup-user-claude` / `setup-user-cursor` fan-out").
- **Evidence:** only `setup-user-cursor.sh:389-404` fans `~/.aitools/rules` out (to `~/.cursor/rules`). `setup-user-claude.sh:290-292` deploys `~/.claude/rules` from `$USER_REPO_PATH/claude/rules` only. `deploy-paths.md:62` says it correctly: "(and `setup-user-claude` once it fans out)". On this machine `~/.claude/rules` holds only the dotprofile rules (concurrent-agents.md, delegation.md), so `shared/rules/hook-lifecycle.md` and `scratch.md` never reach Claude Code.
- **Replacement (workspace `:54`):** "| `rules/` | Rules from `shared/rules/`, `.claude/rules/` and the dotprofile `claude/rules/`, one flat directory (first source wins) — deployed by `deploy-harness`; `setup-user-cursor` fans them out to `~/.cursor/rules`. `setup-user-claude` does not fan out yet: it deploys `~/.claude/rules` from the dotprofile `claude/rules/` only |"
- **Replacement (managed-file-deployment `:48`, last sentences):** "Rules reach Cursor through the `setup-user-cursor` fan-out; `setup-user-claude` does not fan out yet (it deploys the dotprofile `claude/rules/` only). Detail: ..."

### F15 (L, stale) — "`aitools install` also copies them until its bin step is removed"
- **Where:** `aitools-workspace.md:56`.
- **Evidence:** `aitools-install.sh:590` "The harness Python CLIs (~/.aitools/bin) are deployed by deploy-harness (Step 8b)"; no `read-session.py` / `harness-db.py` copy left in `aitools-install.sh`, `aitools-install.ps1` or `scripts/aitools` (probe2 "bin step": no hits).
- **Replacement:** "| `bin/` | Deployed harness Python CLIs (`harness-db.py`, `read-session.py`, `read-session-full.py`) — deployed by `deploy-harness` (installer Step 8b), called by hooks via absolute path so every project resolves them |"

---

## 5. artifact-harvesting.md (no .mdc twin)

### F16 (M, false) — SessionStart behaviour and the `aitools` candidate prompt
- **Where:** `artifact-harvesting.md:59` ("`aitools` sync when candidates exist"), `:69-71` (SessionStart "audit `harvesting/`, auto-prune stale, log candidates, ship inventory KPIs"), `:75` ("`aitools` sync: prompt for candidate review if any exist").
- **Evidence:** SessionStart hooks are `scratch-init.sh`, `session-catchup.sh`, `dashboard-serve.sh`, `harness-db-sessionstart.sh` (`shared/hooks/hooks-manifest.json`). The audit runs inside `ait-harvest.py catchup` (`session-catchup.sh:58` → `ait-harvest.py:1025` `_audit_manifest`); pruning marks entries `pruned` and never unlinks (`harvest-session.sh:16`). `scripts/aitools` has no candidate-review prompt (grep `candidate`: no hits; `harvest` hits are archive only, `:1925-1952`). "Ship inventory KPIs": not verified (unknown).
- **Replacement (`:69-71`):** "- **SessionStart hooks**: `session-catchup.sh` runs `ait-harvest.py catchup`, which recovers transcripts and scratch artifacts an abrupt SessionEnd missed and audits `harvesting/harvest-manifest.json` (auto-prune marks stale entries `pruned`; files are never deleted)."
- **Replacement (`:59` and `:75`):** "- `aitools` sync when candidates exist — **not implemented** (no candidate prompt in `scripts/aitools`); review candidates with `/harvest review`."

---

## 6. hook-rollout.md / hook-rollout.mdc

Checked and accurate: the standing-order-guard table (`standing-order-guard.sh:51-57`, literal `"enforce"` checks at `:213,225,231,237,286,298`, `;` exemption for `pwsh`/`powershell`/`perl` at `:183`), and `delegation-duty-guard.sh:49` `MODE_DUTY="observe"` with events at `:56-67`.

### F17 (M, stale) — hook-lifecycle "once a deploy path for shared/rules/ exists"
- **Where:** `hook-rollout.md:109-112`; twin `hook-rollout.mdc:32` "(not yet deployed)".
- **Evidence:** `deploy-harness.sh:295` `add_source rules "shared/rules" ... "$HARNESS_DIR/rules"`; `setup-user-cursor.sh:389` fans it to `~/.cursor/rules`; `setup-user-claude` has no fan-out (F14).
- **Replacement (md):** "The hook lifecycle beyond rollout (source, deploy, adopt, user-created hooks, retirement) is governed by the user-level rule `@shared/rules/hook-lifecycle.md`. `deploy-harness` copies it to `~/.aitools/rules/` and `setup-user-cursor` fans it out to `~/.cursor/rules/`; it reaches `~/.claude/rules/` once `setup-user-claude` fans out the harness rules."
- **Replacement (mdc):** "Hook lifecycle beyond rollout (source, deploy, adopt, retire): user-level rule `shared/rules/hook-lifecycle.md` (deployed to `~/.aitools/rules` and Cursor; not yet to `~/.claude/rules`)."

---

## 7. incident-governance.md (no .mdc twin)

### F18 (H, false) — "Hook specifications" lists hooks that do not exist
- **Where:** `incident-governance.md:212-229`.
- **Evidence:** `shared/hooks/hooks-manifest.json` (the single source of hook registration, its `meta.purpose`) registers no SubagentStart hook, no PreToolUse on incidents.json, no PreToolUse on protected files, no PreToolUse on Edit/Write, no PreToolUse on git commands; `shared/hooks/subagent-context.sh` (named in `plans/governance-and-compliance-framework.md:292`) does not exist; there is no `.claude/settings.json` in the repo. What exists: PreToolUse `standing-order-guard.sh` (Bash), `glossary-skill-guard.sh` (Read|Grep), `block-claude-code-guide.sh`, `block-explore-agent.sh`, `delegation-duty-guard.sh` (Agent); PostToolUse `sh-file-fixup.sh` (Write|Edit); Stop `command-channel-stop.sh`, `failure-mode-identity-stop.sh`, `failure-mode-verify-stop.sh`, `intelligence-stop.sh`. None of the Stop hooks mentions incidents or surfacing duty (grep `incident|surfacing` in intelligence-stop.*: no hits; the others not read in full — unknown).
- **Replacement:**
  > ### Hook specifications
  >
  > Designed in `@plans/governance-and-compliance-framework.md` §Hook Specifications; **only the PostToolUse fixup is implemented**. Registered hooks are listed in `shared/hooks/hooks-manifest.json`.
  >
  > Implemented:
  > - **PostToolUse on Write/Edit** (command): `sh-file-fixup.sh` (CRLF, chmod, git index).
  >
  > Designed, not implemented (no script, not in the manifest):
  > - **SubagentStart** context injector (pre-built skill cache + governance duty + scratch namespace). Until it exists, subagents get governance only through the delegation prompt (`/delegate` skill); they report `INCIDENT:` findings and the delegating agent files them.
  > - **PreToolUse on incidents.json** (agent): field, enum and sequential-ID validation.
  > - **PreToolUse on protected files**: cross-reference reminder.
  > - **PreToolUse on Edit/Write**: error-suppression detection.
  > - **PreToolUse on Bash git commands**: checklist reminder.
  > - **Stop**: surfacing-duty reminder and incident-acknowledgment detection. NOTE: Claude Code `type: "prompt"` hooks require a static `prompt` string; a dynamic Stop hook must be `type: "command"` with stderr output.

### F19 (H, contradictory) — `/incident` "Presents for review ... Writes if approved"
- **Where:** `incident-governance.md:180-181`.
- **Evidence:** `registries/incidents.json` is protected (`sources-of-truth.md:17`); A2/D-DEL5 make protected writes review-after.
- **Replacement:** "- Writes the entry as a version and commits it (review-after, `@.claude/rules/sources-of-truth.md`); lists the new or changed entries under Review after"

---

## 8. governed-data-access.md (no .mdc twin)

### F20 (M, false) — "registries table" in frameworks.md
- **Where:** `governed-data-access.md:5-6` ("NOT which registries exist (see `@.claude/rules/frameworks.md` registries table)"), `:41` ("Registries table: `@.claude/rules/frameworks.md`").
- **Evidence:** `frameworks.md:29-31` holds no table and says the inventory lives in the framework registry, reached through `/frameworks`.
- **Replacement `:5-6`:** "NOT which registries exist (the `/frameworks` skill lists them)." (`:3-8` is an intent statement: protected, review-after.)
- **Replacement `:41`:** "- Registry inventory: `/frameworks` skill (the pattern: `@.claude/rules/frameworks.md`)"
- Checked and accurate: pre-commit step 16 "Capability bypass audit" (`check-pre-commit.sh:332-334`).

---

## 9. glossary.md (no .mdc twin)

### F21 (M, missing) — governed term `incident` not in the word list
- **Where:** `glossary.md:26-128`.
- **Evidence:** `registries/glossary.json` `terms` (105 keys) contains `incident`; the rule does not list it (probe3 diff: json-only = `incident`; rule-only entries are the scope modifiers and base artifacts, which are facets, as designed).
- **Replacement:** add a line `incident` after `impact` (`:67`).

### F22 (M, missing) — "version" (D-DEL5) and "review-after" are not governed terms
- **Evidence:** D-DEL5 (delegate SKILL.md:150) makes "version" vs "draft" a behavioural distinction; neither word nor "review-after" is in `glossary.json`.
- **Suggested:** file both through the `/glossary` skill (written as a version under review-after), then add `review-after` and `version` to this list. TODO(glossary).

### F23 (L, contradictory) — "draft entries, present for review"
- **Where:** `glossary.md:143-144`.
- **Replacement:** "The skill provides the governed PROCESS (check rule, check JSON, determine type, write the entries as a version, commit, list them under Review after)."

---

## 10. documentation-standards.md / .mdc

### F24 (L, stale) — release header format
- **Where:** `documentation-standards.md:24`; mdc `:11`.
- **Evidence:** `RELEASE_NOTES.md:15` `## v0.73.3 -- Fix: ... (2026-10-03)`; every recent header is three-part.
- **Replacement:** "## vX.Y.Z -- Title (YYYY-MM-DD)"

### F25 (M, contradictory) — "Rules ... ~40-100 lines"
- **Where:** `documentation-standards.md:69`; mdc `:31`.
- **Evidence:** 12 of 24 rules exceed 100 lines: script-standards 300, incident-governance 229, cross-platform 209, deploy-paths 176, config-file-safety 172, agentic-standards 152, glossary 148, interactive-menus 143, tool-lifecycle 133, documentation-standards 123, managed-file-deployment 114, hook-rollout 112.
- **Replacement:** "- **Rules** (`.claude/rules/`) = concise behavioral directives, target ~40-100 lines; a rule over 150 lines should move its detail to `reference/` (today: script-standards, incident-governance, cross-platform, deploy-paths, config-file-safety, agentic-standards)". Or raise the target; commander's call. Suggest the first.

### F26 (L, stale) — "Standardize existing rules files to use `@`"
- **Where:** `documentation-standards.md:113`.
- **Evidence:** plain backtick paths remain at `artifact-harvesting.md:10,82`, `frameworks.md:9`, `governed-data-access.md:7,42`, `incident-governance.md:9`, `tool-ops.md:8`, `sources-of-truth.md:10-11,21-24,30,33`, and throughout the `.mdc` files.
- **Replacement:** keep the directive and add "(not yet done: grep for `` `reference/`` without `@` in `.claude/rules/`)". Low priority.

### F27 (M, false) — mdc links a nonexistent rule
- **Where:** `documentation-standards.mdc:37` "See `@.claude/rules/cursor-rule-parity.md`".
- **Evidence:** no such file; the rule is `.cursor/rules/cursor-rule-parity.mdc`.
- **Replacement:** "See `.cursor/rules/cursor-rule-parity.mdc`".

---

## 11. cross-platform.md / cross-platform.mdc

### F28 (M, contradictory) — Cursor cloud is "supported" but has no environment value
- **Where:** `cross-platform.md:8-9` (environments `local`, Claude Code web, Cursor cloud), `:62-63` (API values `claude-code-web` or `local` only).
- **Evidence:** `reference/cross-platform-detail.md:19` `cursor-cloud` "(proposed, pending decision P-2)"; `aitools-lib.sh:45-51` sets only `claude-code-web` or `local`. The mdc states it (`cross-platform.mdc:23`); the md does not.
- **Replacement (md `:62-63`):** "`$AITOOLS_ENVIRONMENT` / `$AitoolsEnvironment` (`claude-code-web` or `local`; `cursor-cloud` is proposed, pending decision P-2, and today detects as `local`)".

### F29 (L, missing) — repos location omits Linux
- **Where:** `cross-platform.md:17`.
- **Replacement:** "- Repos live under `~/repos/` (macOS, Linux) / `%USERPROFILE%\repos\` (Windows)".

### F30 (L, false) — example helpers that do not exist
- **Where:** `cross-platform.md:50-51` "(e.g. `install_via_brew` / `install_via_apt`)".
- **Evidence:** no `install_via_*` in `aitools-lib.sh` / `.ps1` (probe5).
- **Replacement:** "(a library helper per package manager, chosen by capability, e.g. `command -v brew` vs `command -v apt-get`; no such helper is shared yet)".

### F31 (M, missing) — OS-guard exemptions table is incomplete
- **Where:** `cross-platform.md:104-113`; mdc `:48-49`.
- **Evidence:** no OS guard in `scripts/bootstrap.sh`, `bootstrap.ps1`, `hh.sh`, `hh.ps1`, `relay-outbound-prompt.sh`, `relay-outbound-prompt.ps1`, `init-hh-hooks.sh`, `analyze-session.sh`, `build-package.sh`, `aitools-json.ps1`, `_validate-ps1.ps1` (probe2). `build-package.sh:16-20` says its row is "pending approval P-1".
- **Replacement rows (rationale to be confirmed by the commander; I could not find a recorded one for each):**
  > | Entry points sourced or run on any platform | `bootstrap.sh/.ps1`, `hh.sh/.ps1`, `relay-outbound-prompt.sh/.ps1`, `init-hh-hooks.sh` | Bootstrap/shell helpers; each `.sh` also runs in Git Bash |
  > | Helper modules | `aitools-json.ps1`, `_validate-ps1.ps1` | Dot-sourced / called by other scripts, never a setup entry point |
  > | Build scripts | `build-deploy.sh`, `build-package.sh` (P-1, pending) | Bash-only builders, run in Git Bash on Windows |
  > | Analysis tools | `analyze-session.sh` | Read-only session analysis |

### F32 (M, missing) — cross-language exceptions table is incomplete
- **Where:** `cross-platform.md:133-137`.
- **Evidence:** besides `aitools.ps1:2033`, PS1 scripts call Git Bash in `check-pre-commit.ps1:112` (build-deploy.sh), `check-post-push.ps1:234` (build-deploy.sh), `:57,188` (`bash -n`), `:112` (`bash aitools --version`), `check-pre-push.ps1:128-130` (bash discovery).
- **Replacement rows:**
  > | `check-pre-commit.ps1`, `check-post-push.ps1`, `check-pre-push.ps1` → Git Bash | They check `.sh` files (`bash -n`), the bash entry point's `--version`, and the bash-only `build-deploy.sh` | unrecorded (needs approval) | `& $bashExe ...` |

### F33 (M, false) — canonical stat pattern cites a line that no longer has it
- **Where:** `cross-platform.md:189` "(from `session-archive.sh:68`)".
- **Evidence:** `shared/hooks/session-archive.sh:60-75` is now a thin shim that resolves `ait-harvest.py`; no hook contains the stat dispatch. The live example is `get_mtime()` in `scripts/check-lib.sh:199-208` (branches on `$IS_MACOS`, a library, not a hook). `documentation-standards.md:121` also forbids line numbers in rules.
- **Replacement:** "**Canonical `stat` dispatch pattern for hooks** (hooks cannot use the library's `get_mtime()` in `@scripts/check-lib.sh`, so they dispatch on `uname -s`):" and keep the code block.

### F34 (L, parity) — mdc lacks several md sections
- **Where:** `cross-platform.mdc` vs md.
- **Evidence:** mdc has no "Equal platform visibility", "Platform targeting principle", "Hook portability" table/stat warning, "Refresh-Path", ".NET" gotchas, "Note untested platform in commit message". The Cursor agent writes hooks too, so the hook-portability block matters most.
- **Replacement:** add to the mdc: "### Hook portability\nHooks (`shared/hooks/*.sh`) run in bash on macOS, Linux and Git Bash. Never `grep -P`, `find -printf`, or the chain `stat -f %m f || stat -c %Y f` (GNU `stat -f` means --file-system and corrupts the variable); dispatch on `uname -s`. All hooks use `set -euo pipefail`. Detail: `.claude/rules/cross-platform.md` \"Hook portability\"."

---

## 12. managed-file-deployment.md / .mdc

### F35 (H, false) — adopt transform names do not exist
- **Where:** `managed-file-deployment.md:36-38`; mdc `:21` ("`ADOPT_TRANSFORM` / `-AdoptTransform`; today `adopt_claude_md`").
- **Evidence:** bash: `deploy_managed_file` 6th positional arg `ADOPT_FILTER` (`aitools-lib.sh:1992,2010`); caller `setup-user-claude.sh:247` passes `"claude_md_adopt_filter"`. PS1: `-AdoptFilter` scriptblock (`aitools-lib.ps1:1949,1966`), caller `setup-user-claude.ps1:194,272` `$claudeMdAdoptFilter`. `ADOPT_TRANSFORM`, `-AdoptTransform`, `adopt_claude_md` appear nowhere in `scripts/` (probe3/4). `reference/managed-file-deployment.md:50,59,69,370-371` has the same stale names (INCIDENT, outside this audit's scope).
- **Replacement (both):** "CLAUDE.md, a template, passes an adopt filter that strips the machine footer and reverses the interpolation (bash: 6th argument `ADOPT_FILTER`, a function name — `claude_md_adopt_filter` in `setup-user-claude.sh`; PS1: `-AdoptFilter` scriptblock — `$claudeMdAdoptFilter` in `setup-user-claude.ps1`)."

### F36 (M, false) — chrome-devtools command values
- **Where:** `managed-file-deployment.md:89`; mdc `:51`.
- **Evidence:** `setup-user-mcp.sh:68` local: `npx chrome-devtools-mcp@latest --isolated` (no `-y`); `setup-user-mcp.ps1:128` Windows: `claude mcp add ... cmd /c npx chrome-devtools-mcp@latest -- --isolated`; registration is `claude mcp add --scope user` (`setup-user-mcp.sh:9,133`), i.e. `~/.claude.json`, not `mcp.json`. The Claude Code web row (`:90`) matches `setup-user-mcp.sh:65`.
- **Replacement row:** "| Claude Code MCP registration (`claude mcp add --scope user`, `~/.claude.json`) | chrome-devtools command | `cmd /c npx chrome-devtools-mcp@latest --isolated` | `npx chrome-devtools-mcp@latest --isolated` | same as macOS |". Whether Cursor's `~/.cursor/mcp.json` carries the same args: not verified (unknown).

### F37 (M, stale) — "Skills: vendored from upstream in `shared/skills/`"
- **Where:** `managed-file-deployment.md:53`; mdc `:33`.
- **Evidence:** of 20 dirs in `shared/skills/`, only `chrome-devtools` and `a11y-debugging` are vendored (`reference/cursor-practices.md:190-191`); the rest are aitools-authored. `setup-user-skills.sh:4-7` deploys `shared/skills/` plus the dotprofile `claude/skills/` (dotprofile wins); `deploy-harness.sh:293-294` also copies `shared/skills` and `.claude/skills` to `~/.aitools/skills`.
- **Replacement:** "- **Skills**: user-level skills in `shared/skills/` (aitools-authored; `chrome-devtools` and `a11y-debugging` vendored from upstream) and personal skills in the dotprofile `claude/skills/` (wins on a name clash), deployed by `setup-user-skills` to `~/.claude/skills/` and `~/.cursor/skills/`; `deploy-harness` also copies `shared/skills/` and `.claude/skills/` to `~/.aitools/skills/`"

### F38 (L, parity) — mdc content-sources table lacks the deploy-harness row
- **Where:** `managed-file-deployment.mdc:25-28` vs md `:48`.
- **Replacement:** add the md `:48` row (with F14 applied).

---

## 13. config-file-safety.md / .mdc

### F39 (M, stale) — mdc reference examples
- **Where:** `config-file-safety.mdc:62` ("PowerShell merge: `scripts/setup-user-mcp.ps1` (settings.json)"), `:66` ("Inline Node.js validation: `scripts/setup-user-mcp.sh`").
- **Evidence:** settings.json is owned by `sync_managed_json` via `setup-user-settings` (`config-file-safety.md:168`, `deploy-paths.md:116-118`); the inline Node validation is in `setup-user-hooks.sh:388-389`; `setup-user-mcp.sh` has none (probe1).
- **Replacement:** "- Settings sync (field-level review): `scripts/setup-user-settings.sh` / `.ps1` via `sync_managed_json` / `Sync-ManagedJson` (settings.json <-> profile.json)" and "- Inline Node.js validation: `scripts/setup-user-hooks.sh`".
- Checked and accurate in the md: backup retention 20 single files (`aitools-lib.sh:995`), `validate_json_config` in `aitools-install.sh` (and `setup-user-config.sh`), `ValidateJsonConfig` in `aitools-install.ps1` (and `setup-user-config.ps1`).

---

## 14. tool-lifecycle.md / tool-lifecycle.mdc

### F40 (M, false) — "CLAUDE.md — deploy list"
- **Where:** `tool-lifecycle.md:97`; mdc `:58` ("add `setup-<tool>` to 'Deploy using MDM' tool scripts list").
- **Evidence:** `CLAUDE.md` (94 lines) has no deploy list and no "Deploy using MDM" section (probe1). `check-post-push.sh:676-711` step 26 looks for `build-deploy.sh.*generates` in CLAUDE.md and therefore always SKIPs ("could not find deploy reference in CLAUDE.md").
- **Replacement:** delete the row in both files. **INCIDENT:** post-push step 26 is dead; retire it or point it at a list that exists.

### F41 (H, contradictory) — rebuild steps run against the real HOME and dotprofile
- **Where:** `tool-lifecycle.md:101-105`; mdc `:66-70`.
- **Evidence:** `build-deploy.sh` replaces `<dotprofile>/deploy/` (`deploy-paths.md:86-90`: "an agent runs it only under an isolated `HOME` with a copy of the dotprofile"); `setup-user-claude.sh` writes `~/.claude/CLAUDE.md`. Mission packet §5: never run `setup-user-*` or `build-deploy.sh` against the real HOME (#86). "verify count increments by 2" has no defined counter in `build-deploy.sh` output (unknown which count is meant).
- **Replacement:**
  > #### Rebuild + propagate
  > 1. Agents: `bash scripts/build-deploy.sh` under an isolated `HOME` with a copy of the dotprofile (`@.claude/rules/deploy-paths.md`); verify the new `setup-<tool>.sh/.ps1` pair is in the generated `deploy/`. The real dotprofile rebuild is the commander's (or a mission ordered to do it).
  > 2. Propagate CLAUDE.md with `aitools` (commander), never `setup-user-claude` against the real HOME from an agent.
  > 3. `bash scripts/check-post-push.sh` — all checks pass.
  > 4. Commit + push both repos (aitools via a PR; dotprofile to its main).

### F42 (M, missing) — no pointer to `/tool-adopt`
- **Where:** `tool-lifecycle.md:113-133` (triggers and cross-references); mdc has none either.
- **Evidence:** `shared/skills/tool-adopt/` exists; its description covers "Make a managed tool supported on a platform and environment ... create or migrate its setup scripts, integrate, verify, and keep the registry and tool-lifecycle rule current"; `managed-file-deployment.md:104` already routes onboarding through "`/tool-adopt` step 5".
- **Replacement (add before "When to invoke /tool-registry"):**
  > ### When to invoke /tool-adopt
  >
  > Invoke the `/tool-adopt` skill after `/tool-eval` passes Phase 2, when a setup script reports no method for a platform, when a tool is requested from any repo, or when changing a tool setup script. It walks the onboarding checklist above.
- and in Cross-references: "- Onboarding and platform adoption: `/tool-adopt` skill".

### F43 (M, contradictory) — "Protected (present for review)"
- **Where:** `tool-lifecycle.md:93`; mdc `:54` "(present for review before writing)", `:44` "(protected -- present for review)".
- **Replacement:** "#### Protected (write as a version; review-after, `@.claude/rules/sources-of-truth.md`)".

### F44 (M, parity) — the mdc carries six sections the md lacks; mdc cross-references a heading that does not exist
- **Where:** `tool-lifecycle.mdc:30-32` (Lifecycle field completeness), `:76-94` (Install command verification gate), `:114-116` (Cross-platform vetting), `:118-120` (MCP server isolation), `:122-132` (MCP server disable scope), `:134-139` (Deployment pattern updates); `:28` "See tool-lifecycle.md Bundled dependencies section" (md heading is "Bundled dependency graduation", `:50`).
- **Evidence:** cursor-practices.md:159 calls the pair "Near-identical"; they are not.
- **Replacement:** either port those six sections to the md (they are still true behaviour per web-sources.md and setup-user-mcp `--isolated`) or drop them from the mdc. Suggest port, since the md is the Claude Code copy and is the shorter one. Fix `:28` to "Bundled dependency graduation section".

### F45 (L, stale) — mdc smaller claims
- `tool-lifecycle.mdc:74` "Future: `aitools user sync` will automate this" — `scripts/aitools` has `user init` (`:124`), no `user sync`. Replace with "(no automation yet; `aitools user init` handles profiles, not template rows)".
- `:116` "verify availability on both macOS and Windows" -> "on macOS, Windows and Linux (and the supported environments: `reference/cross-platform-detail.md`)".
- `:32` "all 6 fields" — the registry's `lifecycle` object has 5 keys (`concurrency`, `dependencies`, `invocation`, `platformStatus`, `postInstallConfig` for `claude-code`); whether "Last verified version" lives under `versions` was not checked (unknown). Re-verify before editing.

---

## 15. script-standards.md / .mdc

Checked and accurate: every helper named in the block-order lists exists (`display_path`, `read_config_key`, `backup_dir`, `emit_merge_details`, `ReadConfigKey`, `Backup-Dir`, `ConvertPSObjectToHashtable`, `Emit-MergeDetails`, `check_build_prereqs`/`Check-BuildPrereqs`, `diagnose_build_failure`/`Diagnose-BuildFailure`, `ensure_tool_on_path`, `invoke_ai`/`Invoke-AI`); auth checks (`setup-modal.sh:153`, `setup-datadog.sh:184`, `setup-vercelcli.sh:171`); `aitools user init` exists; `check-prereq-detection.*` exists.

### F46 (M, contradictory) — "(protected -- requires user approval to modify)"
- **Where:** `script-standards.md:289`; mdc `:137` "(protected file, user approval needed)".
- **Replacement:** "Be listed in `@reference/script-standards-detail.md` exemptions table (protected: written as a version and reviewed after, `@.claude/rules/sources-of-truth.md`)".

---

## 16. agentic-standards.md / .mdc

Checked and accurate: speed tiers (`aitools-lib.sh:871-873` haiku/sonnet/opus), `prompt_diff_review`/`Prompt-DiffReview`, the protected-file adopt WARN (`aitools-lib.sh:1076-1104`).

### F47 (L, stale) — mission name as implementation pointer; gate wording
- **Where:** `agentic-standards.md:51` ("mission SOURCE-TRUTH implements this model"), `:104-106` ("the review gate applies at commit and PR"); mdc `:57`, `:110-112`.
- **Replacement `:51`:** "...in `@scripts/aitools-lib.ps1`), with `review_json_fields` / `Review-JsonFields` for JSON."
- **Replacement `:104-106`:** "Adopting into a protected file (`.claude/rules/sources-of-truth.md`) is allowed. It writes only the working tree and logs a WARN that names the file; the commit that carries it lists the file under Review after (review-after)." (The WARN text at `aitools-lib.sh:1104` says "the review gate ... applies at commit"; align it when the rule changes.)

---

## 17. relay-outbound.md / .mdc

Checked and accurate: `[c]ontinue [q]uit (exit 2) [s]how git status` (`relay-outbound-prompt.sh:74`), `AITOOLS_SKIP_RELAY_PROMPT` (`:24`), `RELAY_PROMPT_FORCE` (`:14,49`).

### F48 (M, contradictory) — "Only the commander can publish" / "propose git add/commit/push"
- **Where:** `relay-outbound.md:21-22`, `:36-39`; mdc `:13`, `:19`.
- **Evidence:** `CLAUDE.md:79-84` Channel exception: agents commit `relay.md` (and handoffs, plans, CLAUDE.md) directly to main from the main checkout after `git pull --ff-only`.
- **Replacement (`:21-22`):** "**Outbound (commit + push):** `relay.md` goes directly to main (CLAUDE.md \"Channel exception\"): any agent with push credentials commits it from the main checkout. After **`aitools`** or **`hh -n`**, the harness may show a **`[RELAY]`** prompt when:"
- **Replacement (`:36-39`):** "**Agent behavior:** If you edited `relay.md`, run `git pull --ff-only`, stage only `relay.md`, commit with a **`channel:`** subject (see relay.md), and push to main. If the pull is not a fast-forward, leave it uncommitted and tell the commander. Do not claim the push succeeded without evidence. Do not put tokens or secrets in relay or commit messages."

---

## 18. smoke-test-pattern.md / .mdc

### F49 (L, missing) — Linux
- **Where:** `smoke-test-pattern.md:9`; mdc `:15`.
- **Replacement:** "Platform dispatch: `pwsh -File` for `.ps1` on Windows, `bash` for `.sh` on macOS and Linux (and Claude Code web)."
- Also, both files say "from Claude Code"; the mdc is a Cursor rule. mdc `:9` -> "from an AI agent (Claude Code or Cursor)".

---

## 19. web-sources.md / .mdc

### F50 (M, missing) — Firecrawl deprecation
- **Where:** `web-sources.md:17-21`; mdc `:9-11`.
- **Evidence:** mission packet §5 "Firecrawl is deprecated: do not use Firecrawl tools"; `shared/skills/delegate/SKILL.md:181-182` "Firecrawl is deprecated: do not use its tools even when they appear in the tool list". Firecrawl MCP tools and skills are present in sessions (this one included).
- **Replacement (add after `:21`):** "Firecrawl is deprecated: do not use its MCP tools or skills for any web reading, even when they appear in the tool list (commander decision; `/delegate` skill standing orders)."

---

## 20. cursor-rule-parity.mdc and its correspondence table

### F51 (M, stale) — the Rule Correspondence table it points to is wrong
- **Where:** `cursor-rule-parity.mdc:9` -> `reference/cursor-practices.md:151-171`.
- **Evidence:** the table lists `.claude/rules/cursor-rule-parity.md` (`:160`; no such file); says `smoke-test-pattern` has no mdc (`:169`; `.cursor/rules/smoke-test-pattern.mdc` exists); omits `agentic-standards`, `git-safety`, `managed-file-deployment` (all have twins); and does not say why eight rules have no mdc: `aitools-workspace`, `artifact-harvesting`, `frameworks`, `glossary`, `governed-data-access`, `incident-governance`, `tool-evaluation`, `tool-ops` (probe5). `cursor-practices.md:190-191` also says skills deploy "via `setup-user-mcp`" (now `setup-user-skills`).
- **Replacement table (for `reference/cursor-practices.md`):**
  > | `.claude/rules/agentic-standards.md` | `.cursor/rules/agentic-standards.mdc` | Identical |
  > | `.claude/rules/config-file-safety.md` | `.cursor/rules/config-file-safety.mdc` | Condensed |
  > | `.claude/rules/cross-platform.md` | `.cursor/rules/cross-platform.mdc` | Condensed |
  > | `.claude/rules/deploy-paths.md` | `.cursor/rules/deploy-paths.mdc` | Near-identical |
  > | `.claude/rules/documentation-standards.md` | `.cursor/rules/documentation-standards.mdc` | Condensed |
  > | `.claude/rules/git-safety.md` | `.cursor/rules/git-safety.mdc` | Identical |
  > | `.claude/rules/hook-rollout.md` | `.cursor/rules/hook-rollout.mdc` | Condensed |
  > | `.claude/rules/interactive-menus.md` | `.cursor/rules/interactive-menus.mdc` | Condensed |
  > | `.claude/rules/managed-file-deployment.md` | `.cursor/rules/managed-file-deployment.mdc` | Near-identical |
  > | `.claude/rules/plan-execution.md` | `.cursor/rules/plan-execution.mdc` | Condensed |
  > | `.claude/rules/relay-outbound.md` | `.cursor/rules/relay-outbound.mdc` | Near-identical |
  > | `.claude/rules/script-standards.md` | `.cursor/rules/script-standards.mdc` | Condensed |
  > | `.claude/rules/smoke-test-pattern.md` | `.cursor/rules/smoke-test-pattern.mdc` | Identical |
  > | `.claude/rules/sources-of-truth.md` | `.cursor/rules/sources-of-truth.mdc` | Condensed (keep the table complete) |
  > | `.claude/rules/tool-lifecycle.md` | `.cursor/rules/tool-lifecycle.mdc` | Must match (F44) |
  > | `.claude/rules/web-sources.md` | `.cursor/rules/web-sources.mdc` | Identical |
  > | (CLAUDE.md Code Conventions) | `.cursor/rules/general.mdc` | Python style folded in |
  > | — | `.cursor/rules/cursor-rule-parity.mdc` | Cursor-only (this rule) |
  > | `aitools-workspace`, `artifact-harvesting`, `frameworks`, `glossary`, `governed-data-access`, `incident-governance`, `tool-evaluation`, `tool-ops` | — | No twin today: reason not recorded. Commander's call: add twins, or record "Claude Code skill triggers only" |

---

## 21. Files checked with no finding

`frameworks.md` (skill `/frameworks` exists), `plan-execution.md` / `.mdc` (`reference/plan-execution-detail.md` has the "Error-handling rules (non-negotiable)" block), `tool-evaluation.md` (`/tool-eval` skill and `reference/evaluations/` exist), `tool-ops.md` (`/tool-ops` skill exists), `interactive-menus.md` / `.mdc` (post-push steps 29/30 exist in both check scripts; abort behaviour matches `scripts/aitools:1097-1098,1157-1158`, `aitools-install.sh:284-285`, `aitools.ps1:161-162`; `AITOOLS_FORCE` at `scripts/aitools:151`), `general.mdc`, `documentation-standards.md` skill-placement section (pre-commit step 21 = `check-skill-levels.py`, collision across all three folders), `incident-governance.md` `/audit` (`.claude/skills/audit/SKILL.md:4` `disable-model-invocation: true`) and the `closed` array (`incidents.json` keys `meta`, `incidents`, `closed`).

## 22. INCIDENT markers (not filed)

1. INCIDENT: pre-commit steps 3/10 and post-push step 7 inspect the frozen aitools `deploy/`; step 3 `--fix` and post-push step 7 run `build-deploy.sh` against the real dotprofile without HOME isolation (F8).
2. INCIDENT: post-push step 26 always SKIPs; CLAUDE.md has no deploy list (F40).
3. INCIDENT: `reference/managed-file-deployment.md:50,59,69,370-371` documents `ADOPT_TRANSFORM` / `-AdoptTransform` / `adopt_claude_md`; the code uses `ADOPT_FILTER` / `-AdoptFilter` (F35).
4. INCIDENT: `setup-user-claude` does not fan out `~/.aitools/rules`, so user-level `shared/rules/` (hook-lifecycle.md, scratch.md) never reach `~/.claude/rules`, while two rules say it does (F14).
5. INCIDENT: incident-governance.md presents five unimplemented hooks as the hook spec (F18).
6. INCIDENT: `sources-of-truth.md` still holds the pre-write gate against D-DEL5 (F1; already recorded in S3-MA-Versions-log.md:83).
7. INCIDENT (harness): the session's injected rules context is a session-start snapshot; it carried two retired rules (section 0).

## 23. Open questions (with suggested answers)

- Q1: F25 rule length: enforce ~100 lines, or raise the target? Suggested: keep the target, move detail out of the six longest rules in a later docs pass.
- Q2: F31/F32 exemption rationales were never recorded. Suggested: accept the rows above as written, mark build-package's row "P-1 pending".
- Q3: F51 eight rules without Cursor twins. Suggested: record "skill-trigger rules, Claude Code only" for glossary, frameworks, governed-data-access, tool-ops, tool-evaluation; add twins for aitools-workspace, artifact-harvesting and incident-governance, which state behaviour the Cursor agent also needs.
- Q4: F8 post-push step 7 and pre-commit steps 3/10. Suggested: retire them (pre-push step 7 already covers the build in a temp copy).
