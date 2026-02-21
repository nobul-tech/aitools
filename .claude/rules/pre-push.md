## Pre-Push Checklist (this repo)

Before pushing to remote, verify:

### 1. Pre-commit checklist passed

All items in the pre-commit checklist were satisfied for every commit being pushed.

### 2. No scratch or sensitive files

Confirm nothing was accidentally committed:
- No scratch files (`chat.txt`, temp notes, `*.tmp`)
- No secrets (`.env`, credentials, tokens, API keys)
- `git log --oneline --name-only origin/main..HEAD` to review all files in the push

### 3. Credential / secret scan

Scan the push diff before it leaves the machine:
- `git diff origin/main..HEAD` -- grep for passwords, tokens, API keys, `.env` contents, hardcoded absolute paths containing usernames
- Catches secrets while they can still be unstaged (post-push is too late)

### 4. No WIP commits

`git log --oneline origin/main..HEAD` must not contain `WIP`, `fixup!`, `squash!`, or `TODO` prefixes. Squash or reword before pushing.

### 5. Release notes current

If pre-commit step 8 (release notes gate) applied to any commit in this push, confirm `RELEASE_NOTES.md` was updated. This is a verification, not a redo.

### 6. Roadmap reflects reality

If the push completes or starts a roadmap item, `ROADMAP.md` should be updated (move to Completed or add to In Progress).

### 7. deploy/ matches source

If pre-commit steps 3+9 (build freshness + deploy drift check) applied to any commit in this push, confirm `deploy/` is included and matches source. This is a verification, not a redo.

### 8. Commit count check

If pushing >5 commits, pause to review the full list (`git log --oneline origin/main..HEAD`) before proceeding. Large pushes are more likely to include unintended changes.

### 9. Branch hygiene

- Pushing to `main` directly is OK for this single-maintainer repo
- Force-push to `main` requires explicit user approval -- never do it silently

### 10. User repo push

If the user dotfile repo (`userRepoPath` from `~/.config/ai-tooling/config.json`)
has unpushed commits, push them. Pull first if needed (rebase). Skip if
`userRepoPath` is not configured or the repo is clean.
