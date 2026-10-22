# S3-Layout follow-ups, by owning mission

Mission LAYOUT (S3-Layout, session 10cf255a-c, 2026-10-21). PRs: #71 (PR-a), #74 (PR-b, stacked
on #71), PR-c (stacked on #74). These are changes LAYOUT needed in files other missions own; each
entry gives the file, the exact change and why.

## SOURCE-TRUTH (scripts/setup-user-skills.*, scripts/build-deploy.sh, scripts/aitools-lib.*)

1. **Prune retired skills (#119; required by PR-c).** Without it, `~/.claude/skills/aitool-ops`,
   `aitool-eval` (and the `~/.cursor/skills` copies) stay deployed and stale, and
   `reverse_discover_skills` (setup-user-skills.sh "Reverse discovery") prompts on every run to adopt
   them into the dotprofile. Change, in setup-user-skills.sh and .ps1 and the embedded copy in
   build-deploy.sh:
   - a list `RETIRED_SKILLS="aitool-ops aitool-eval"` / `$retiredSkills = @('aitool-ops','aitool-eval')`;
   - before deploy, for each name present under `~/.claude/skills/` or `~/.cursor/skills/`:
     `backup_dir` / `Backup-Dir`, remove the directory, `log_ok "retired skill removed: <name>"`, one
     `write_summary OK "skills" "retired: <names>"` row; a failed removal is `log_error` + ERROR row;
   - `reverse_discover_skills` / its PS1 twin skips names in the retired list.
2. No change is needed for PR-b's move: discovery globs `shared/skills/*/SKILL.md` (verified by an
   isolated-HOME dev deploy and an isolated build-deploy run, PR #74 body).

## APPLY-DRAFTS (shared/rules/*, shared/claude-shared.md, shared/skills/delegate, reference/managed-file-deployment.md, registries/tool-registry.json)

1. `shared/skills/delegate/SKILL.md` lines 198, 211, 227, 232, 289: replace `/aitool-ops` with
   `/tool-ops` (the card is retired in PR-c; the facts live in `reference/tool-ops-claude-code.md`
   through `/tool-ops`).
2. `reference/managed-file-deployment.md:273` and `:407`: replace `@reference/tool-registry.md` with
   the `/tool-registry` skill (google-chrome / chrome-devtools MCP entry; perl entry
   `platformGotchas`). T-Q7.
3. Draft D3, new `shared/rules/harness-skills.md` (approved intent, S2-Layout-evidence E7 D3, minus
   the resolver): trigger directives for /tool-registry, /tool-ops, /tool-eval, /harvest, /incident,
   /glossary, /frameworks in every repo; their "Where the files live" sections replace
   `aitools-registry`.
4. `shared/claude-shared.md` (and the dotprofile `claude/CLAUDE.md` twin): if the template names the
   governance skills as aitools-only, say they are user-level.
5. `registries/tool-registry.json`: the only tool-versions.json data with no registry home is the
   free-text `notes`; the one worth keeping is python's "Windows uv path not yet validated".

## TOOL-ADOPT (registries/glossary.json, shared/skills/tool-adopt)

1. `facets.scopeModifiers` (D1): project = "In the aitools repo's .claude/ or .cursor/ — loaded only
   in sessions on the aitools repo; never deployed"; shared = "In shared/ in the aitools repo — source
   of everything aitools deploys to user level (~/.claude, ~/.cursor, ~/.aitools)".
2. Term `skill`: add `shared/skills/` as the user-level source.
3. Term `managed tool` (glossary.json:220): "governed by reference/tool-registry.md" -> "governed by
   the tool registry (/tool-registry skill)" (T-Q7).
4. `/tool-adopt` at user level (TA-PLACE) must not leave a `.claude/skills/tool-adopt` copy:
   pre-commit step 21 fails on a name at two levels.

## HARNESS (deploy-harness)

1. Install `~/.aitools/registries/` and `~/.aitools/reference/`: the seven moved skills already
   point there for machines without a clone.
2. `shared/hooks/tool-ops-session-audit.sh`: PR-a repointed it to `registries/tool-ops.json`, so it
   runs again. It still logs to `~/.claude/hooks/logs` and falls back to `$HOME/repos/aitools`
   instead of config `repoPath` (#70, #117).
3. S2L-Q4: see `S3-Layout-design-web-skills.md` (run V5 first).

## M2 (tool support)

1. Setup-script header template (R25): cite the `/tool-registry` skill, not `tool-registry.md`.
2. The R5 (`/tool-eval`) and R6 (`/tool-registry`) drafts target `.claude/skills/`; after PR-b they
   apply to `shared/skills/` (E-paths-PRb) and must keep each skill's "Where the files live"
   section and, for /tool-eval, PR-c's description and playbook pointers.
3. R2/R14 (`tool-lifecycle` rule and mirror) and `reference/tool-evaluation-criteria.md`: they still
   describe an "Under Evaluation" section and a markdown version format that only the deprecated
   `tool-registry.md` had.

## Commander

1. Dotprofile `claude/CLAUDE.md:8` (your identity paragraph): "the tool-registry and tool-ops skills
   in aitools" -> suggested "the tool-registry and tool-ops skills (user-level, from aitools)". Not
   edited: your own text.
2. aitools `CLAUDE.md` "How the harness is organized" could state the folder = level rule (pointer
   to `shared/README.md`). Not edited: your CLAUDE.md edit is in flight.
3. `reference/framework-provenance.md` plans a `shared/skills/aitool-provenance` card; naming rule N1
   (no level prefixes) and PR-c say not to make new reference cards.
