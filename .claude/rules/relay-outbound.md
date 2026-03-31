---
paths:
  - .aitools/channel/relay.md
  - scripts/relay-outbound-prompt.sh
  - scripts/relay-outbound-prompt.ps1
  - scripts/aitools
  - scripts/aitools.ps1
  - scripts/hh.sh
  - scripts/hh.ps1
---

## Relay outbound (git) — not managed deploy

**`.aitools/channel/relay.md`** lives **inside this repo**. It is **not** a managed
user file like `~/.claude/CLAUDE.md` (those use `[REVIEW]` / `deploy_managed_file`
during deploy — see `@.claude/rules/managed-file-deployment.md`).

**Inbound (pull):** `aitools` / `hh` runs `git pull` on the aitools clone, then
deploy and relay → `AGENTS.md` when Python is available.

**Outbound (commit + push):** Only the commander (or a shell with credentials)
can publish. After **`aitools`** or **`hh -n`**, the harness may show a
**`[RELAY]`** prompt when:

- `relay.md` has **uncommitted** changes, or
- the current branch is **ahead of `origin/main`** (unpushed commits).

Script sources: `scripts/relay-outbound-prompt.sh` (bash / Git Bash),
`scripts/relay-outbound-prompt.ps1` (PowerShell). Choices: **[c]** continue,
**[q]** exit with code 2, **[s]** show `git status -sb`.

**Skip automation:** `AITOOLS_SKIP_RELAY_PROMPT=1`. **CI / non-interactive:**
short hint only (or set `RELAY_PROMPT_FORCE=1` to force the full prompt when a
TTY exists).

**Agent behavior:** If you edited `relay.md`, propose **`git add` / `git commit` /
`git push`** with a **`channel:`** subject (see relay.md). Do not claim push
succeeded without evidence. Do not put tokens or secrets in relay or commit
messages.
