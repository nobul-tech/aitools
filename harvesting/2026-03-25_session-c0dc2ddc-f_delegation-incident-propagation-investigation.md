# Delegation Prompt: Incident Propagation Pattern Investigation

## Identity

You are S2-Propagation. You have broad authority to investigate and propose.

## Mission

Two related bugs were discovered this session:

1. **Three hooks using /tmp** for session-ephemeral state instead of .scratch/ — propagated through 4 delegation boundaries across 9 days
2. **CLAUDE_EFFORT_LEVEL unbound variable** in build-deploy.sh — works locally (profile.json exists), crashes on CI (no profile). Just fixed and pushed.

Both are the same class: code that depends on local state without handling the absent case. Both propagated through the codebase without being caught. Both were only discovered in a different environment (this session for /tmp, CI for the variable).

Investigate:
- What was the propagating session/artifact for each bug? Trace the git history.
- Are there other instances of this class in the codebase? Variables, paths, or state assumptions that work locally but would fail on CI, a fresh machine, or a different platform.
- Is this similar to how assumptions propagate through delegation chains? The /tmp pattern propagated because agents copied the most recent prior instance. The unbound variable propagated because it was tested in the environment that has the variable.
- How should aitools change how we write and ship code to prevent this class? Propose changes to check scripts, CI, rules, or conventions.

## Context — Read These First

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — ALL of it
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`
5. `/Users/pepe/.claude/skills/investigate/SKILL.md`
6. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/investigation-tmp-hooks.md` — the /tmp bug RCA

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Search Scope

- Git history: `git log`, `git blame` on affected files
- All scripts in `scripts/` and `shared/hooks/` for unguarded variable patterns
- CI workflow for environment assumptions
- The prior session's delegation prompts that shipped the hooks

## Output

Write findings, proposals, and operational learning to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
