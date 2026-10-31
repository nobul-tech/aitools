## Summary

Generalizes what this session's parallel missions taught about delegating into the `/delegate` skill. Only lessons that hold in any session and repo; no mission names, PR numbers or session facts.

## Why

Running 8+ parallel mission commanders (HOOKS-FIX, SOURCE-TRUTH, SPEC-REWRITE, GATE-FIX, REGISTRY-CC, SCRATCH-RULE, INCIDENTS, and the earlier workflow missions) surfaced repeatable failure modes: approval given before text existed, worktree removal deleting a delegate's ignored files, two missions needing one interface, PRs merged with open reviews, single-agent "independent" reviews, and the corrected SendMessage behaviour.

## Changes

`shared/skills/delegate/SKILL.md`:
- Step 9: detailed commit bodies and fixed PR body sections.
- Step 10 (new): approve text, not intent; relayed approval carries no authority.
- Step 11 (new): name the delegate's scratch directory; hand-backs in tracked paths.
- New section "Running several delegates at once": shared packet, file ownership, shared contract, verify state before launching / fix forward, independent review means a separate delegate, workflow keywords only help with the Workflow tool.
- Environment limits: "No follow-up messages" replaced with the observed SendMessage behaviour (Claude Code 2.1.307).
- Verifying, lifecycle: removing a git worktree deletes ignored files; check first.
- Recursion: pass the shared packet path down.

Intent block unchanged.

## Verification

- Docs only. Read end to end for consistency with `~/.claude/rules/delegation.md` (no requirement added there; the skill stays the process layer).
- Not run: check-pre-commit / check-pre-push (docs-only; known pre-existing failures: pre-commit step 6, pre-push step 7).

## Protected-file drafts awaiting approval

None. Follow-up needed in a protected file: `reference/tool-ops-claude-code.md` item #25 still says SendMessage is unavailable; the observed 2.1.307 behaviour contradicts it. To be drafted for approval and filed as an incident.

## Follow-ups

- Update tool-ops item #25 (protected; draft for approval).
- After this merges, the `/delegate` skill reaches `~/.claude/skills` on the next `aitools` run.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
