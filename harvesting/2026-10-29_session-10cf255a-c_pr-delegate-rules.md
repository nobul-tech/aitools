## Summary

`/delegate` duty element 2 now requires every delegation prompt to tell the delegate explicitly to read all project-scope and user-scope rules not already in its context, each by absolute path. Writing step 4 and the prompt skeleton's Rules block are updated to match.

Commander decision, 2026-10-21.

## Commits

- f4991be /delegate: instruct delegates to read all project and user rules

## Verification

- Docs-only change to `shared/skills/delegate/SKILL.md` (not a protected file).
- Not run: check-pre-push (step 7 fails on every change until #32 is fixed; the fix is in flight as mission DEPLOY-PATH).

## Follow-up

The dotprofile rule `claude/rules/delegation.md` element 2 still has the weaker wording. The edit is drafted and waiting on commander approval (it's a protected file).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
