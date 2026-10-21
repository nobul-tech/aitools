# S2-Layout draft recommendation (for adversarial review)

Repo /Users/new-jose/repos/aitools (main 51a34d8). Commander decisions: L1 tool-ops, tool-eval,
tool-registry, harvest are USER-level skills. L2 registries move to user level. L3 his untracked
copies of 9 project skills under shared/skills/ express move intent. L4 the user/project split must
be obvious from names and folders.

## Diagnosis (evidence)
- Two axes are conflated. Glossary scope modifiers (registries/glossary.json facets.scopeModifiers)
  mix SOURCE location (project = "in the aitools repo", shared = "in shared/", dotprofile) with
  DEPLOYMENT scope (user = "deployed to ~/"). The term "deployment scope" (user-level/project-level)
  is separate. So `shared/` means "user-level" but its name says neither user nor deploy.
- `.claude/skills/` is the name of BOTH the project folder (repo) and the user target (~/.claude/skills).
- registries/ and reference/ sit at repo top level with no level marker; they are read by
  user-level hooks/skills (glossary-skill-guard.sh, intent-audit, optimize-plan cite reference/*.json).
- Prefix inversion: plan governance-and-compliance-framework.md:133 says project counterparts use
  `aitools-` prefix; actual user-level reference cards use `aitool-` (aitool-ops, aitool-eval,
  aitool-continue). Prefix carries no reliable level meaning.
- The CLAUDE.md "Skills as enablement" placement text + tree was deleted in b504c43 (2026-03-28).
- Claude Code docs (code.claude.com/docs/en/skills): personal over project on same name; personal
  skills don't load in cloud sessions; project skills committed in the clone do; plugins declared in
  repo settings don't load in cloud sessions.

## Alternatives
A. Keep folders, just move: git mv the skills into shared/skills, registries into shared/registries.
   Low churn; "shared" still unclear.
B. Level-first top folder: rename shared/ -> user/ (source of everything deployed to ~/ and
   ~/.cursor, ~/.aitools); registries/ -> user/registries/ (snapshot-deployed to ~/.aitools/registries/);
   new user/rules/ for harness trigger rules; .claude/ .cursor/ stay project (tool-mandated).
   Max clarity; ~80 live files touch `shared/`.
C. Plugin: plugins/aitools/skills with namespaced /aitools:x. Rejected: plugins don't load in cloud
   sessions, adds marketplace machinery, namespaced names break muscle memory (decision 19).

## Draft pick: B, in 2 PRs
PR1 pure rename shared/ -> user/ (mechanical; verified by byte-diff of build-deploy output under
isolated HOME, modulo path strings). PR2 the moves (L1/L2/L3) + resolver + rules + checks.

Skills: move 7 (tool-ops, tool-eval, tool-registry, harvest per L1; incident, glossary, frameworks
because their registries become user-level and user-level hooks/skills already route to them).
Keep audit, governed-data project-level (they audit/create aitools' own source; developer persona).
Delete project originals (git mv), never both. Retire reference cards aitool-ops/aitool-eval after
folding unique content into /tool-ops, /tool-eval + reference docs.

Registries: authored in git at user/registries/ (review gate unchanged). Skills resolve:
(1) live clone: AITOOLS_REPO_PATH env -> config.json repoPath -> ~/repos/aitools, if
user/registries exists -> read-write (writes only when cwd is the clone, on a branch, gate applies);
(2) snapshot ~/.aitools/registries/ (deployed by aitools install + embedded in MDM deploy, with
.source.json {commit, builtAt}) -> read-only; writes become a gh issue on nobul-tech/aitools;
(3) none -> say unavailable, stop.

Rules: new user/rules/harness-skills.md (trigger directives for user-level governed skills) deployed
to ~/.claude/rules/ additively; dotprofile claude/rules/ wins on same name (delegation.md stays
dotprofile-only per L3). Replaces .claude/rules/aitool-ops.md + aitool-eval.md.

Naming rules: level is shown by folder, never by prefix. Same name at two levels is a check failure.
Project-only skills that shadow nothing keep descriptive names.

Q-A: git mv (delete project original). Q-B: commander approves the protected spec (path map + rule
drafts) up front; delegate ships one atomic PR; PR review is a second check, not the approval.
Splitting protected vs unprotected into separate PRs breaks atomicity (paths must change in one pass).
