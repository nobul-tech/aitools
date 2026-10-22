# shared/

**Intent**: **Purpose**: State the deployment level of everything under shared/ so a maintainer knows
where each file lands before editing it. **Scope**: The folder -> target map (skills, hooks, rules,
registries, bin, shell, cursor-rules, claude-shared.md) and the one-name-one-place rule. NOT deploy
mechanics (`reference/managed-file-deployment.md`). NOT project-level artifacts (`.claude/`,
`.cursor/`). **Audience**: aitools maintainers and agents editing shared/.

## The rule

1. `shared/**` deploys to **user level** (`~/.claude`, `~/.cursor`, `~/.aitools`, the shell rc) and
   works in every repo.
2. `.claude/**` and `.cursor/**` are **project level**: they load only in sessions on the aitools repo
   and are never deployed.
3. Everything else (`scripts/`, `reference/`, `registries/`, `plans/`, `deploy/`) is aitools source or
   docs. It reaches a user only through a deploy script.

## Where each folder lands

| Source | Deployed to | Deployed by |
|--------|-------------|-------------|
| `shared/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/`, `~/.cursor/skills/<name>/` | `scripts/setup-user-skills.sh/.ps1` (dev); embedded by `scripts/build-deploy.sh` (MDM) |
| `shared/hooks/*.sh` (+ `hooks-manifest.json`) | `~/.claude/hooks/`, registered in `~/.claude/settings.json` | `scripts/setup-user-hooks.sh/.ps1`; embedded by `scripts/build-deploy.sh` |
| `shared/claude-shared.md` | `~/.claude/CLAUDE.md` (fallback when the dotprofile has no template) | `scripts/setup-user-claude.sh/.ps1`; embedded by `scripts/build-deploy.sh` |
| `shared/shell/aliases.sh`, `aliases.ps1` | sourced from the shell rc / PowerShell profile | `scripts/aitools-install.sh/.ps1` |
| `shared/cursor-rules/` | not deployed: templates to paste into Cursor User Rules by hand | none |
| `shared/mcp/README.md` | not deployed: documentation of the MCP setup | none |
| rules/ (planned, mission APPLY-DRAFTS) | `~/.claude/rules/` (additive) | setup-user-claude fan-out |

Registries stay in `registries/` (decision SD-8-reg); deploy-harness will copy them read-only to
`~/.aitools/registries/`. User-level skills that read them say where the files live in their own
"Where the files live" section.

## One name, one place

A skill name exists in exactly one of `shared/skills/` (user level), `.claude/skills/` (project
level) or the dotprofile's `claude/skills/` (personal). To change a skill's level, `git mv` it; never
keep two copies (decision S2L-QA). Pre-commit step 21 (`scripts/check-skill-levels.py`) fails on a
collision. Placement rules: `.claude/rules/documentation-standards.md` "Skill placement".
