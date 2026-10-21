# S2-Layout evidence appendix

Baseline: aitools HEAD 04cbdf0 (moved from 51a34d8 during this mission: #50 c491c59, #51 4081cf3,
#52 26c37b2 filed incidents #74-#86, 04cbdf0 housekeeping). Working tree: only the 9 untracked
`shared/skills/{audit,frameworks,glossary,governed-data,harvest,incident,tool-eval,tool-ops,tool-registry}/`.
Dotprofile: /Users/new-jose/repos/aitools-nobul-jose. Machine alias nobul-mac (~/.aitools/config.json:11).

Detailed sub-reports (all read-only, in this directory):
- S2-Layout-A-deploy-map.md — how each artifact class deploys (dev + MDM), config.json consumers, web.
- S2-Layout-B-registry-consumers.md — every registry path reference (52 stale, 18 current), writers, checks, sibling-mission paths.
- S2-Layout-C-review.md — adversarial review of the first draft (S2-Layout-draft-recommendation.md).
- inventory.txt, inventory2.txt — raw listings, drift tables (scripts inventory.sh, inventory2.sh).
- Prior mission (reused, spot-checked): ../S2-Split/ (paths.txt, history.txt).

## E1. Deploy mechanics (verified spot-checks marked [v])
- Skills dev path: setup-user-skills.sh:43 `SKILLS_SRC=$REPO_DIR/shared/skills`; :48-52 adds
  `<userRepoPath>/claude/skills`; :93-98 "dotprofile wins over shared" [v]; :54-56 targets
  ~/.claude/skills and ~/.cursor/skills [v]; :112 deploys SKILL.md only [v]; no prune (A §1).
- Skills MDM path: build-deploy.sh:1105-1125 embeds shared/skills/*/SKILL.md as heredocs; never
  dotprofile skills (A §1).
- CLAUDE.md: dev = dotprofile claude/CLAUDE.md then shared/claude-shared.md (setup-user-claude.sh:64-90);
  MDM = shared/claude-shared.md only (build-deploy.sh:44,330-332) (A §3; also S5-Profile incident).
- User rules: only <userRepoPath>/claude/rules -> ~/.claude/rules, additive (setup-user-claude.sh:262-392;
  build-deploy.sh:148-170,410-439). No shared rule source exists (A §3).
- Hooks: hooks-manifest.json (18 registered + 2 helpers); source order dotprofile claude/hooks, shared/hooks,
  scripts/ (setup-user-hooks.sh:75-86); MDM `cat >` overwrite (build-deploy.sh:1302-1321) (A §4).
- ~/.aitools/bin: only aitools install Step 6 writes harness-db.py, read-session*.py
  (aitools-install.sh:571-598); ~/.aitools/bin/aitools and hh.sh have no current writer (A §5).
- Nothing deploys registries/ or reference/ anywhere (A §5, B headline).
- Shell rc: aitools-install.sh:614-628 appends `source "<abs>/shared/shell/aliases.sh"` once and never
  rewrites it when the marker exists [v] (C E2). Any rename of shared/ breaks every bash/zsh start.
- Project artifacts (.claude/*, .cursor/*, .mcp.json) are never deployed (A §8).

## E2. Loading facts (Claude Code docs, code.claude.com/docs/en/skills, fetched 2026-10-20 via WebFetch)
- "Personal | ~/.claude/skills/... | All your projects on this machine, but not Cowork or cloud sessions".
- Same name: "Enterprise over personal, and personal over project."
- "Cloud sessions additionally load project skills committed to the cloned repository's .claude/skills/."
- "Plugins declared in the repository's .claude/settings.json and plugins enabled only in your user
  settings don't load in cloud sessions."
- Nested `<subdir>/.claude/skills` load "once Claude works on files there" (C E7: web cwd is /home/user).
- Cursor agent CLI reads ~/.cursor/skills only; not ~/.claude/skills or .claude/rules
  (reference/cursor-practices.md:130-133). Cursor User Rules are UI/SQLite only (:137).
- Claude Code web: a reclaim wipes /root; harness re-bootstrapped manually with
  `AITOOLS_FORCE=1 aitools install` (dotprofile environments/claude-code-web/CLAUDE.md:16-20,47,69-70).
  Whether skills installed into the container's ~/.claude/skills load in that session: UNKNOWN.

## E3. Drift today (inventory2.txt:479-528)
- ~/.claude/skills vs shared/skills: DIFF aitool-continue, aitool-ops, handoff, mission-control, planning;
  ABSENT delegate (+ the 9 untracked copies). Same for ~/.cursor/skills.
- ~/.claude/rules lacks delegation.md (dotprofile has it).
- ~/.claude/hooks DIFF: delegation-duty-guard.sh, harness-db-sessionstart.sh, standing-order-guard.sh.
- Conclusion: this Mac's user deploy is months behind source; any design that relies on "deployed copy
  = source" needs a deploy run plus a drift check.

## E4. Stale registry paths (B; spot-checked [v])
- registries/ created by b2641c0 (v0.69.0, 2026-06-15). Still on reference/*.json: /glossary SKILL.md:12,22,35,127 [v];
  /incident :8,48,88,124 [v]; /frameworks :22,45,71 [v]; /audit :103,121 [v]; /tool-ops :106 + tests;
  shared intent-audit :131-135 [v], optimize-plan :34 [v]; setup-bash.sh/.ps1:8; 3 .cursor rules;
  reference/post-push-checklist.md:160; reference/path-targeted-hooks-analysis.md:66-67; ROADMAP.md:28;
  registries/framework-registry.json:183.
- tool-ops-session-audit.sh:23-26 looks for reference/tool-ops.json, :29 exit 0 (incident #70) [v];
  last log write Jun 14 23:25, before b2641c0 (B).
- check-post-push.ps1:268,520 still reference/tool-versions.json; bash :233,448 fixed [v].
- check-pre-commit.ps1:336 pattern misses registries/; neither version covers tool-ops/tool-versions (B).
- No script writes any registry; all writes are agent writes via skills (B). Sizes total 262 KB;
  incidents.json 2,027 lines [v] (> Read default 2,000).

## E5. RCA of the confusing split (investigate skill, light)
**Immediate cause**: The commander could not tell which skills/registries are user-level; he copied
9 project skills into shared/skills/ (L3) because his user CLAUDE.md (dotprofile claude/CLAUDE.md:8)
tells agents in every repo to use /tool-registry, /tool-ops, /tool-eval, which exist only in aitools.
**Contributing factors**:
1. Folder names don't encode deployment scope: `shared/` = user level, `.claude/` = project level but
   `~/.claude/` = user level; registries/ and reference/ carry no level (prevention).
2. Vocabulary mixes two axes: scope modifiers project/shared/dotprofile = source location, user =
   deployment target (registries/glossary.json facets.scopeModifiers); "deployment scope" is a separate
   term (prevention).
3. Prefix inversion: plan says project counterparts use `aitools-` (plans/governance-and-compliance-framework.md:133);
   the user-level cards use `aitool-` (aitool-ops, aitool-eval, aitool-continue) (prevention).
4. The explanation was deleted: CLAUDE.md "Skills as enablement" + tree removed in b504c43 (2026-03-28) [v] (prevention).
5. Requirements moved, placement didn't: the 2026-03-13 placement test ("patterns would be wrong in
   another project", plan:113-116) predates harvesting in every repo (ait-harvest.py) and the
   cross-repo CLAUDE.md order; reference cards (v0.65.1, 9a2125b/cb0ca08) bridged with snapshot copies
   instead of moving the source (prevention).
6. No detection: no check for same-name skills across levels, none for path references; the
   registries move (b2641c0) left 52 stale paths and a dead hook for 4 months (detection).
7. Trigger rules for cross-repo skills are project rules (.claude/rules/aitool-ops.md:30,
   aitool-eval.md:33) never loaded outside aitools (prevention).
**Root cause**: No framework governs artifact placement (framework registry has 13 frameworks + 2
pending; none governs location/level — checked via /frameworks), so each artifact class picked its
folder ad hoc and nothing re-evaluated placement when requirements changed.
**Corrective action**: structural — folder = level rule, same-name check, path-reference check,
resolver code; plus a placement section in the Managed file deployment framework.
**Recurrence risk**: high without the checks (moves recur: v0.69.0 registries, this one, S5-Tools).

## E6. Path map for PR-b (old -> new). Protected = P
| Old | New | P |
|---|---|---|
| registries/*.json (6) | shared/registries/*.json | P (sources-of-truth rows) |
| .claude/skills/{tool-ops,tool-eval,tool-registry,harvest,incident,glossary,frameworks}/ | shared/skills/<same>/ (git mv; tests/ move too) | skills not protected; their intents are |
| .claude/rules/aitool-ops.md, aitool-eval.md | deleted; triggers move to shared/rules/harness-skills.md | P |
| shared/skills/aitool-ops/, aitool-eval/ | retired (PR-c): content folded into /tool-ops, /tool-eval | no |
| (new) shared/rules/ | deployed to ~/.claude/rules additively | P (new rule + intent) |
| (new) ~/.aitools/registries/ snapshot + .source.json | written by setup-user-skills (sole owner) | P (deployment-type row) |
| (new) shared/bin/aitools-registry.py -> ~/.aitools/bin/ | resolver CLI | no (code intent P) |

Every consumer line to update is enumerated in S2-Layout-B-registry-consumers.md (tables 1-3) plus:
scripts/setup-user-skills.sh/.ps1 (snapshot + rules deploy + prune list), scripts/setup-user-claude.sh/.ps1
(shared/rules source), scripts/build-deploy.sh (embed shared/rules + snapshot), scripts/aitools-install.sh/.ps1
(deploy resolver to ~/.aitools/bin), scripts/check-pre-commit.sh/.ps1 (step 16 scope + new checks),
scripts/check-post-push.sh/.ps1 (tool-versions path), shared/hooks/tool-ops-session-audit.sh,
session-archive.sh:67, scratch-init.sh:103, dashboard-serve.sh:58 (replace $HOME/repos/aitools fallback
with resolver), .github/workflows/check.yml:57,162,215,297 (C E3), CLAUDE.md "How the harness is
organized" (P), reference/user-repo.md "What Stays in aitools/shared/" (P), reference/harness.md
Configuration (P), reference/framework-governed-vocabulary.md:41-75 (P), registries glossary scope
modifiers (P), .claude/rules/documentation-standards.md "Skill placement" (P), deploy-paths.md
"auto-embedded" list (P), managed-file-deployment.md content-sources table (P), governed-data-access.md
"What may reference JSON paths" (add the resolver) (P), sources-of-truth.md table (P, and fix #50 by
citing skills), .cursor/rules mirrors (P), shared/claude-shared.md + dotprofile claude/CLAUDE.md:8
("skills in aitools" -> user-level skills) (P), delegate/SKILL.md:143,163,217 and aitool-continue:557-558
and dotprofile delegation.md:10,132 (/aitool-ops -> /tool-ops) (PR-c; delegation.md P, commander-owned).

## E7. Protected drafts for up-front approval (Q-B)

### D1. Glossary scope modifiers (registries glossary facets.scopeModifiers + framework-governed-vocabulary.md)
- project: "In the aitools repo's .claude/ or .cursor/ — loaded only in sessions on the aitools repo; never deployed"
- shared: "In shared/ in the aitools repo — source of everything aitools deploys to user level (~/.claude, ~/.cursor, ~/.aitools)"
- dotprofile: unchanged ("In the user's aitools-<username> repo, personal source")
- user: unchanged ("Deployed to ~/, active on the machine")

### D2. documentation-standards.md "Skill placement" (replacement)
- **Folder decides level.** `shared/skills/` = user level (deployed to ~/.claude/skills and ~/.cursor/skills,
  every repo). `.claude/skills/` = project level (aitools sessions only). Dotprofile `claude/skills/` =
  personal user level.
- **Test**: user level if the skill is useful in a session on any repo, even read-only. Project level only
  if it is meaningful solely inside the aitools working tree (it edits or audits aitools source).
- **One name, one place**: a skill name exists in exactly one of the three folders; pre-commit fails otherwise.
- **No path literals for governed data**: user-level skills reach registries and aitools docs only through
  `aitools-registry` (`~/.aitools/bin/aitools-registry.py`).
- Split personas: `<name>` user level, `<name>-dev` project level (unchanged). No level prefixes.

### D3. shared/rules/harness-skills.md (new user rule) — intent draft
**Intent**: **Purpose**: Give every session in every repo the trigger directives for the harness's
user-level governed skills. **Scope**: When-to-invoke directives for /tool-registry, /tool-ops,
/tool-eval, /harvest, /incident, /glossary, /frameworks only. NOT the processes (the skills). NOT the
registry data (`aitools-registry`). NOT aitools-development rules (aitools `.claude/rules/`). NOT
personal rules (dotprofile `claude/rules/`). **Audience**: Every agent, every session, any repo.

### D4. shared/README.md — intent draft
**Intent**: **Purpose**: State the deployment level of everything under shared/ so a maintainer knows
where each file lands before editing it. **Scope**: The folder -> target map (skills, hooks, rules,
registries, bin, shell, cursor-rules, claude-shared.md) and the one-name-one-place rule. NOT deploy
mechanics (`reference/managed-file-deployment.md`). NOT project-level artifacts (`.claude/`,
`.cursor/`). **Audience**: aitools maintainers and agents editing shared/.

### D5. shared/registries meta.intent (per file: unchanged except scope gains)
Add to each `meta.intent.scope`: "Authored here; deployed read-only to ~/.aitools/registries/.
Accessed through its skill via aitools-registry."

### D6. aitools-registry.py header intent (code intent, P)
intent: Resolve the aitools registries for any repo and environment — live clone (read-write when cwd is
a worktree of repoPath) else ~/.aitools/registries snapshot (read-only) else none; commands path|get|
next-id|validate|mode. NOT a registry editor (skills write, under the review gate). NOT a deploy step.
Consumed by: user-level skills, hooks (tool-ops-session-audit, session-archive, scratch-init), checks.

## E8. Sibling-mission impacts (B §4)
- S5-Tools: `.claude/skills/tool-adopt/` stays project-level under the D2 test (it writes aitools setup
  scripts). Its edits to /tool-eval and /tool-registry must target shared/skills/ if PR-b lands first
  (or PR-b moves them after). `generated/tool-specs/` OK as committed derived source (never deployed);
  `reference/tool-support-decision-tree.md` OK. Registry schema 1.1 edits target shared/registries/.
- S5-Profile: scripts/aitools-profile.js, setup-user-config.* stay in scripts/; add the resolver key
  (repoPath) to config v3 meta as "consumed by aitools-registry". Its claude-shared.md edit unaffected.
- S4-Review: its sources-of-truth draft re-lists registries/*.json paths (B: draft :5-6) — must change
  to shared/registries via skill citations (#50).
