# S3-Layout design note: user-level skills in Claude Code web (S2L-Q4)

Design only, not implemented (launch prompt). Author: S3-Layout, session 10cf255a-c, 2026-10-21.

## The question

After PR-b, the seven governance skills live at user level (`shared/skills/` deployed to
`~/.claude/skills/`). Does a Claude Code web session see them? If not, how should it get them?
Your note (plan item S2L-Q4): "use claude.ai account skills, but also check for Claude Code web,
and if we are in the web, deploy skills to the project level? Or set the project directory to the
home directory?"

## What is known (sources)

- Claude Code docs, skills page (fetched 2026-10-20 by S2-Layout, S2-Layout-evidence.md E2):
  personal skills in `~/.claude/skills/` load in "all your projects on this machine, but not Cowork
  or cloud sessions". Cloud sessions "additionally load project skills committed to the cloned
  repository's `.claude/skills/`". I did not re-fetch the page in this mission.
- The web container's home is wiped on reclaim; the harness is re-bootstrapped with
  `AITOOLS_FORCE=1 aitools install` (dotprofile `environments/claude-code-web/CLAUDE.md`, per
  S2-Layout E2).
- The harness already detects the environment: `is_claude_code_web` / `Test-ClaudeCodeWeb`,
  `$AITOOLS_ENVIRONMENT` (`.claude/rules/cross-platform.md` "Environment branches").
- Unknown: whether skills written into the container's `~/.claude/skills/` by `aitools install`
  during a running web session are listed in that session or the next one. "Not ... cloud sessions"
  suggests no, but nobody has tested it (S2-Layout V5).

## Options

| # | Option | For | Against |
|---|--------|-----|---------|
| A | **claude.ai account skills** (upload the 7 SKILL.md files to the account) | Loads in web, desktop and Cowork; no per-repo work | A third copy to keep in sync by hand; account skills cannot read the repo-relative paths unless the session has the aitools clone; upload is manual today |
| B | **Web branch in setup-user-skills: deploy to project level.** When `is_claude_code_web`, also copy each `shared/skills/<name>/` into `<current repo>/.claude/skills/<name>/` and add those paths to `.git/info/exclude` | Uses the documented cloud-session loader; works for any repo cloned into the session; no tracked copy, so N2 (one name, one place) still holds in git | Depends on Claude Code rescanning `.claude/skills/` after the session starts (unknown; may need a new session); writes into the working repo (excluded, but visible to `git status --ignored`); in the aitools repo itself the copy would sit next to the tracked project skills (no name overlap after PR-b) |
| C | **Point the project directory at home** (start the web session in `~`, so `~/.claude/skills` is a project dir) | No copies | Breaks the cloned-repo model of web sessions (cwd is the repo); not something a skill or script controls; likely unsupported |
| D | **Environment setup script** (the web environment's setup hook runs `aitools install` before the session starts) | If personal skills do load when present at start, nothing else is needed | Contradicts the docs line above; needs V5 to prove it |

## Recommendation

1. Run V5 first (one web session: `aitools install`, start a new session, list skills). It decides
   between D (works as is) and the rest.
2. If V5 fails, do **B** for the 7 governance skills and the process skills, gated on
   `is_claude_code_web` (cross-platform.md requires a recorded decision naming the environment), and
   report one `OK` row per run. Keep git clean with `.git/info/exclude`, never a tracked copy.
3. Use **A** only for the few skills you want in Cowork or claude.ai chat, and make the upload a
   script step when an API exists; do not make it the primary route.
4. Drop **C**.

Owner if approved: mission HARNESS (deploy-harness is decided to install `~/.aitools/skills`, mission packet section 6) or
SOURCE-TRUTH (setup-user-skills). Needs a decision id (D-ENV-style) before any environment branch.
