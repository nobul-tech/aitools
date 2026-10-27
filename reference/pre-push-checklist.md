# Pre-Push Checklist (this repo)

> **Script**: On macOS: `bash scripts/check-pre-push.sh`.
> On Windows: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/check-pre-push.ps1`.
> Always use the platform-native variant. Never run the `.sh` version on Windows.

Before pushing to remote, verify:

## 1. Pre-commit checklist passed

All items in the pre-commit checklist were satisfied for every commit being pushed.

## 2. No scratch or sensitive files

Confirm nothing was accidentally committed:
- No scratch files (`chat.txt`, temp notes, `*.tmp`)
- No secrets (`.env`, credentials, tokens, API keys)
- `git log --oneline --name-only origin/main..HEAD` to review all files in the push

## 3. Credential / secret scan

Scan the push diff before it leaves the machine:
- `git diff origin/main..HEAD` -- grep for passwords, tokens, API keys, `.env` contents, hardcoded absolute paths containing usernames
- Catches secrets while they can still be unstaged (post-push is too late)

## 4. No WIP commits

`git log --oneline origin/main..HEAD` must not contain `WIP`, `fixup!`, `squash!`, or `TODO` prefixes. Squash or reword before pushing.

## 5. Release notes current

If pre-commit step 9 (release notes gate) applied to any commit in this push, confirm `RELEASE_NOTES.md` was updated. This is a verification, not a redo.

## 6. Roadmap reflects reality

If the push completes or starts a roadmap item, `ROADMAP.md` should be updated (move to Completed or add to In Progress).

## 7. deploy/ matches source

Runs on every push (commander decision 2026-10-26; it used to run only when a deploy-relevant source changed). It rebuilds from this branch into a temporary copy of the dotprofile's committed tree, under a temporary HOME, and compares that copy's `deploy/` with the committed one; then it dry-runs the generated resolver consumers. The real dotprofile is never touched. A stale dotprofile `deploy/` is a FAIL: run `bash scripts/build-deploy.sh` and commit `deploy/` in the dotprofile repo. Skipped when `userRepoPath` is not configured; WARN when node (bash) or Git Bash (PowerShell) is missing. It also dry-runs the generated `setup-user-claude.sh` as an endpoint (empty `config.json`, no dotprofile) and FAILs unless it reports `Profile source: embedded build-time snapshot`.

## 8. Commit count check

If pushing >5 commits, pause to review the full list (`git log --oneline origin/main..HEAD`) before proceeding. Large pushes are more likely to include unintended changes.

## 9. Branch hygiene

- Direct pushes to `main` only for the channel exception (`CLAUDE.md` "Channel
  exception": `.aitools/channel/handoffs/*`, `.aitools/channel/relay.md`, `plans/*`,
  `CLAUDE.md`), after `git pull --ff-only`. Everything else: a branch (`fix/`,
  `feature/`, `docs/`) and a PR.
- Never force-push `main`. (The script reports the branch; it does not enforce this yet.)

## 10. User repo push

If the user dotfile repo (`userRepoPath` from `~/.aitools/config.json`)
has unpushed commits, push them. Pull first if needed (rebase). Skip if
`userRepoPath` is not configured or the repo is clean.
