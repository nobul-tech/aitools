# S3-DiffUX hand-back (mission DIFF-UX, 2026-10-21)

PR: https://github.com/nobul-tech/aitools/pull/81 (branch `fix/review-diff-display`, commits aefa3b5, 126083e)

## Done

The review diff is now LOCAL -> SOURCE. It has these headers:

- `--- this machine  <LOCAL>`
- `+++ repo          <adopt path | source (embedded)>`

Above the diff is the legend line. Lines are red and green unless `NO_COLOR` is set or `TERM=dumb`; the log stays plain text. The menu text describes what each choice does to the lines shown. Bash and PS1 run the same pinned `git diff --no-index` command, and their output is byte-identical on macOS.

Choices, their order, return values and non-interactive behaviour are unchanged. The AI merge input is deliberately unchanged.

## Independent review

S3-DiffUX-Review returned request changes with one blocking finding, B1. A diff over about 64 KB aborted the setup run because `printf | head` died of SIGPIPE under pipefail. The same bug is on main at a larger size.

- B1, N1 (git config pinning) and N2 (`--text`) are fixed in 126083e, with a test for a 330 KB diff.
- GitHub refused the reviewer's `--request-changes` on a PR opened by the same account. The mission commander posted the verdict and the resolution as a PR comment.
- The verdict is kept verbatim in `S3-DiffUX-Review-verdict.md`.

## Verification (macOS)

- `test-managed-files.sh`: 56/56, also with `/bin/bash` 3.2.57 first on PATH.
- `test-managed-files.ps1`: 38/38.
- Mutation check: the new tests fail against the old libs (11 per side), and the huge-diff case fails with `head` put back.
- `bash -n` (3.2) and pwsh ParseFile: clean.
- pre-commit: known FAILs only (step 6, step 20, the latter already on main).
- pre-push: known FAIL only (step 7).

## Not run

- Windows.
- `build-deploy.sh`, so dotprofile `deploy/` copies still show the old display.
- The real `aitools` entry point.

## INCIDENT markers (not filed)

- INCIDENT: The AI merge prompt (`_ai_prompt_merge` in `scripts/aitools-lib.sh` and its twin `Get-AiMergePrompt` in `scripts/aitools-lib.ps1`) has two problems (medium).
  - It calls its diff "unified diff: local vs source" and tells the model to apply it to LOCAL, but bash feeds it a SOURCE -> LOCAL diff.
  - PS1 feeds it an unordered `Compare-Object` listing, so bash and PS1 send the AI different input.
  - Suggested fix: feed the new LOCAL -> SOURCE review diff, with prompt evaluation per agentic-standards.md.
- INCIDENT: Truncating with `printf | head` under pipefail aborts with SIGPIPE on large input. It was fixed here for the review diff. Similar patterns may exist elsewhere in reusable scripts, and an audit is suggested (high). The main-branch instance is the one this PR fixes.
