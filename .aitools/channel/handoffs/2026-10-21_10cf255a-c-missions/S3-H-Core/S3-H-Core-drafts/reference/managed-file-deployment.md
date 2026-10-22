<!--
Draft by S3-H-Core (2026-10-22) for reference/managed-file-deployment.md,
"## Content Sources" section. Not applied: the file is owned by DIFF-UX
(PR #81) until #81 merges. Apply after #81 merges: insert the subsection
below between the paragraph ending "actually read from." and the
"**`userRepoPath` resolution**" paragraph. Nothing else in the section changes.
Matching rule change (applied in this PR): .claude/rules/managed-file-deployment.md
"Content sources" table, new row "aitools repo + dotprofile -> ~/.aitools/".
-->

### Deployed harness (`~/.aitools`)

`deploy-harness.sh` / `.ps1` copies harness content into `~/.aitools`
(Windows `%USERPROFILE%\.aitools`). Each file goes through
`deploy_managed_file` / `Deploy-ManagedFile` with the tool name
`harness files`; the adopt target is the repo file it was read from. Only
git-tracked files are deployed. On a name conflict the first source wins
and each skipped duplicate is a `log_error` plus an ERROR row.

| Deployed to | Sources, in order |
|-------------|-------------------|
| `~/.aitools/reference/**` | `reference/**` |
| `~/.aitools/registries/**` | `registries/**` |
| `~/.aitools/hooks/` (flat) | `shared/hooks/`, `.claude/hooks/` |
| `~/.aitools/skills/<name>/` | `shared/skills/`, `.claude/skills/` |
| `~/.aitools/rules/` (flat, `*.md`) | `shared/rules/`, `.claude/rules/`, `<userRepoPath>/claude/rules/` |
| `~/.aitools/bin/` | `scripts/harness-db.py`, `scripts/read-session.py`, `scripts/read-session-full.py` |
| `~/.aitools/config.json` | generated from `profile.json` by `setup-user-config` (called by deploy-harness) |

Rules reach the agent tools from `~/.aitools/rules/` through the
`setup-user-claude` / `setup-user-cursor` fan-out. Conflict handling and
its assumptions: `@reference/harness.md` "Deployed harness (`~/.aitools`)".
