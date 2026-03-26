# Delegation Prompt: Commit, Ship, Observe CI, Produce OL

## Identity

You are S3-Ship. You have broad authority to commit, push, observe, and report using disciplined initiative.

## Mission

Multiple code changes from this session need to be committed, pushed, and verified through CI. Additionally, the dotprofile repo may have uncommitted session archives. This is a broad shipping and observability mission.

### 1. Commit and push aitools changes

Check `git status` and `git diff` in `/Users/pepe/repos/aitools/`. Commit any uncommitted changes from this session with clear commit messages. Key changes that may be pending:
- Harness DB registration fix (setup-user-hooks.sh/.ps1 + deploy/ rebuild)
- Any other modified files

Use the scratch skill for commit messages — write to scratch, commit with `-F`.

### 2. Update RELEASE_NOTES.md

Add a release entry for this session's shipped changes:
- CI fix: CLAUDE_EFFORT_LEVEL unbound variable + deploy rebuild
- Harness DB fix: hooks deployed but not registered in settings.json
- Include the session context: what was discovered, what was fixed, what was built

Read the existing RELEASE_NOTES.md format (it's in the repo) and follow the convention exactly.

### 3. Dotprofile repo

Check `/Users/pepe/repos/aitools-nobul-jose/` for uncommitted changes. Session archives, profile changes, anything pending. Commit and push if needed.

### 4. Observe CI/CD

After pushing, watch the CI pipeline:
- `gh run list --limit 5` to see if the new push triggers a run
- `gh run view <id>` to check status
- If CI fails, investigate why and either fix or report

### 5. Check for other incidents

Look at the git status across repos. Are there stale branches? Untracked files that should be committed? Anything that looks like it was started and not finished?

### 6. Produce OL

Document what you found, what you shipped, what CI reported, and any incidents or observations as work product.

## Context

1. `/Users/pepe/repos/aitools/.scratch/session-c0dc2ddc-f/consolidated-operational-learning.md` — read Part 1 and Part 2
2. `/Users/pepe/repos/aitools/CLAUDE.md`
3. `/Users/pepe/.claude/CLAUDE.md`
4. `/Users/pepe/.claude/skills/scratch/SKILL.md`

Find session scratch: read `/Users/pepe/repos/aitools/.scratch/.current-session`.

## Operational Learning

- Commit messages go to scratch files, commit with `git commit -F`
- Follow existing RELEASE_NOTES.md format exactly
- CI was broken for 6 runs due to CLAUDE_EFFORT_LEVEL — fixed this session
- The harness DB hooks were deployed but never registered — fixed this session
- Port conflicts are recurring — don't launch any servers
- Use `git add <specific-files>` not `git add -A`

## Output

Write operational learning and CI observation results to the session scratch directory.

CRITICAL: If Write is denied, output "WRITE_BLOCKED" as the first line.
