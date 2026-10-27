# S3-MA-FrictionSessions findings v1.0

**Written:** 2026-10-26 (after 23:10Z) · **By:** S3-MA-FrictionSessions (delegate of mission MERGE-ALL, Session Commander 10cf255a-c, commander Jose) · **Scope:** read-only research. Friction the commander hit, taken from his own prompts. Each item gives its evidence, root cause and a concrete remedy (unit test, CI step, check-script step, or a rule or process change). Input to `plans/merge-friction-improvements.md` v1.0. Not committed.

Companion: `S3-MA-FrictionIssues-findings.md` (same folder) covers the GitHub-side failure classes (its F1-F12). Where an item here overlaps one of those, it is marked "= FI-Fn". This file adds what only the session transcripts show.

## How I checked

- **Commander prompts, newest first.** I used `/Users/new-jose/repos/aitools/.scratch/session-fricsess/typed-prompts.py` (written for this task). It keeps typed prompts and AskUserQuestion answers only, and drops sub-agent hand-backs, task notifications, skill bodies and compaction summaries. I ran it on:
  - the live transcript `~/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl`: 93 items, lines 7335 back to 16;
  - every non-sub-agent session in `~/repos/aitools-nobul-jose/sessions/aitools/`, filtered by friction words (`run-all.sh`): 162 hits, 2026-02-28 to 2026-10-21.
- **Transcript lines.** Assistant replies at specific lines came from `.scratch/session-mabrief/dump-lines.py` (for example lines 4112 and 4231).
- **Main-thread context volume:** `handback-size.py` (same scratch directory).
- **GitHub:**
  - `gh issue list --state all`, `gh pr list --state all --limit 130` and `gh run list --limit 300`;
  - `gh run view <id> --log-failed` for the 8 failed CI runs;
  - `gh api repos/nobul-tech/aitools` (merge settings) and `.../rulesets/16468370`.
- **git:**
  - `git rev-list --all --since=2026-10-20` with `--grep` counts;
  - `git worktree list` and `git ls-files`;
  - `registries/incidents.json`, parsed in full with python.
- I verified nothing on Windows. Every count below comes from a command named in its row.

## Summary

| # | Friction | Commander's words (cite) | Fix type |
|---|---|---|---|
| S1 | "Draft" work products, and the draft → approve → apply round trip | "no drafts ... version 1.0" (7264, 6779, 6721) | rule + check step |
| S2 | Worktree/PR overhead on paths that need neither | "i dont like the overhead of worktrees/PRs" (5421, 6071, 6494, 6712, 7264) | CI step + rule |
| S3 | The commander is the merge queue; 19 PRs waited 3.5 days | "all PRs merged" (5057); "Waiting on you: merge #68" (4273) | repo settings + CI |
| S4 | Context spent on hand-backs and re-statements | "2% context left" (1285); "be super efficient with context" (5171) | /delegate rule + hook check |
| S5 | The commander repeats the same mission boilerplate in every launch | "carry forward all OL" (12 prompt lines) | /delegate default |
| S6 | Questions he cannot answer without a re-statement | "restate" / "re-print" (19 times), "im lost here" (840), "conflated" (6431) | rule + skill test |
| S7 | The main checkout's branch was switched; the mission packet vanished | "why did the branch change here? ... we should have stayed on main" (4106) | hook check + test |
| S8 | Local checks are red by design ("known failures") | (via missions) | check-script fix + test |
| S9 | CI was the first, and only, Windows run | "Not run: Windows" in 87 of 245 commits | CI steps |
| S10 | CI fails on things the local run could not see | 8 failed runs, 4 classes | unit tests + CI meta-check |
| S11 | Channel commits pay for a full 3-OS CI run, and that slows the A6 wait | 10 main runs at about 10 min each, 22:01-23:09Z | CI config |
| S12 | Review and report commits on PR branches | 25 "Add S3-... report/review" commits | rule |
| S13 | Stale main checkout: rules and skills load old | handoff A: 105 commits behind | SessionStart hook + test |
| S14 | Unverified harness claims about delegate nesting ("ultracode") | "im not convinced that this is true" (7335); "run a quick test" (2006) | check step |
| S15 | Usage limits and stops cut missions mid-work | "hit session limits ... is any of the work salvagable?" (3832); "the stop of those agents was accidental" (933) | rule (state file) |
| S16 | Merge policy written in three places that now disagree | A1 vs D-DEL4 vs repo settings | rule + settings |

---

## S1. "Draft" work products and the draft → approve → apply round trip (= FI-F10)

**Evidence**
- Commander, in his own words:
  - 2026-03-27T00:18:46Z (`2026-03-26_d5b52bf2.jsonl:539`): "delete the old one and write a new one, dont call it draft, just call it CLAUDE.md".
  - 2026-10-22T03:34:05Z (live:3990): "no need to show me the text before writing it, just write it".
  - 2026-10-26T22:33:08Z (6721): "produced materials should be not be drafts, they should be trated as version 1.0 of working docs".
  - 22:39:56Z (6779): "no drafts, the produced plan should be executable by another sessions, it should be version 1.0".
  - 22:55:20Z (7264): "i dont like that produced work is often "draft"".
- **PR pairs.** Six PRs were titled as drafts "for approval": #57, #61, #63, #64, #96 and #102. Each needed a second "apply" PR or batch: #65, #70, #68, #70, then #101 and #105, and #102's apply is still to come (`gh pr list`).
- **Time to land.** #96 merged at 2026-10-23T01:58Z and was approved at 02:01Z. Its rows were applied in #101 and #105, opened 02:15-02:20Z. Both were still open on 2026-10-26: approved text off main for more than 3 days.
- **18 draft directories** sit under `MF/` (`find -iname "*draft*" -type d`), for example `S3-M3-Docs-drafts` and `S3-H-MDM-drafts`.
- **The draft wording comes from the governing files:**
  - `.claude/rules/sources-of-truth.md:40` ("Draft the change ... do not write it yet") and `:53`;
  - dotprofile `claude/rules/delegation.md:96` ("Otherwise it returns drafts");
  - `shared/skills/delegate/SKILL.md:89,93,96,99,250` (PR body section "Protected-file drafts awaiting approval");
  - `.claude/skills/glossary/SKILL.md:42-77` ("Draft JSON entry ...");
  - the packet `SC-mission-packet.md:92-94`.
  - `grep -l -i draft` also hits 13 more skills and references.

**Root cause.** The pre-write review gate (sources-of-truth.md) and D-DEL4's "returns drafts" make "draft" the only legal output for any protected file. Delegates follow the text, so the word reaches documents that are not protected at all, such as plans and reports.

**Remedy**
- **Rule (decided as A2):**
  - D-DEL5 in the dotprofile `claude/rules/delegation.md` and in `shared/skills/delegate/SKILL.md`: "Work products are versions (v1.0, v1.1 ...), written in place; never 'draft'."
  - `sources-of-truth.md` "The rule" becomes: write the version, commit it, and list the protected files in the commit or PR body under "Protected files changed (review after)".
  - In the PR body skeleton (`delegate/SKILL.md:93`), the section "Protected-file drafts awaiting approval" becomes "Protected files changed (review after)".
- **Check step (new, check-pre-commit step N, .sh and .ps1).** Grep the governed files (`.claude/rules/*.md`, `shared/rules/*.md`, `shared/skills/*/SKILL.md`, `.claude/skills/*/SKILL.md`, the dotprofile `claude/rules/*.md`) for `-i -E "draft the change|returns drafts|drafts? awaiting approval|present for (user )?review|do not write it yet"`. A hit FAILs, unless the line is in `scripts/check-draft-language-allow.txt` (path:line plus a reason). This catches the old wording coming back.
- **Unit test.** `tests/checks/test-draft-language.sh` (+ `.ps1`). A fixture rule containing "Draft the change" FAILs. An allowlisted line PASSes. A file with "v1.0" only PASSes.
- **CI step** (linux job, "PR title/body vocabulary"): fail a pull_request whose title matches `-i '\bdraft|for approval\b'`. Run `gh pr view $PR --json title` with `GITHUB_TOKEN`, or read `${{ github.event.pull_request.title }}`.

## S2. Worktree and PR overhead on paths that need neither

**Evidence**
- Commander:
  - 2026-10-23T02:29:31Z (5421): "i dont like the overhead of worktrees/PRs for handoffs".
  - 2026-10-26T21:58:13Z (6071): "5) fix it directly on main, no worktree/pr overhead ... 7) channel exception for handoffs should just do it on main".
  - 22:17:19Z (6494): "bypass worktrees/pr branches".
  - 22:28:33Z (6712): "no worktrees etc.".
  - 22:39:56Z (6779): "no worktrees/prs, this should bypass all of that ... thats a decision".
  - 7264: "i dont like the overhead of worktrees/prs".
- **76 git worktrees** exist (`git worktree list --porcelain | grep -c ^worktree`). 17 of them are detached reviewer, probe or research worktrees, for example `mf-fix4-review`, `h2-cursor-rv`, `mdmpkg-b-pr106` and `ansa`.
- **Channel-only PRs.** Five PRs touch only channel-exception paths (`.aitools/channel/**`):
  - #94 and #107, opened before the exception was written;
  - #97, #102 and #104, still in the 19-PR merge queue (`gh pr view <n> --json files`).
- **Branch-sync merges.** 33 commits since 2026-10-20 are "Merge origin/main into ..." or "Merge remote-tracking branch ..." (`git rev-list --merges --grep`).

**Root cause**
- Until 2026-10-26 (CLAUDE.md:79-85, 5976553/1af8851) every change went through a worktree and a PR (packet section 4).
- Missions then started one worktree per batch and one more per reviewer.
- Nothing checks a PR for paths that belong on main.

**Remedy**
- **CI step** (linux job, "channel-exception detector", pull_request only):
  - Run `git diff --name-only origin/main...HEAD`.
  - If every path matches `^(\.aitools/channel/|plans/|CLAUDE\.md$)`, fail with "::error::This PR only touches channel-exception paths (CLAUDE.md 'Channel exception'); commit them to main and close the PR."
- **Check step** (check-pre-push, new step): the same test on `git diff --name-only origin/main...HEAD` when the current branch is not `main`. Report WARN with the same text.
- **Unit test:** `tests/checks/test-channel-only.sh`. Three fixtures in a temp repo with a `main` remote: a channel-only branch (WARN), a mixed branch (PASS) and main itself (SKIP).
- **Rule (plan proposal for Q1).**
  - Reviewers review with `gh pr diff <n>` and `git -C <main checkout> show <sha>:<path>`, not a new worktree.
  - A mission uses one worktree for all its batches and creates each batch branch inside it (switching branches inside your own worktree is allowed).
  - Worktree removal stays the commander's decision (packet section 5).
  - A listing helper is safe because it only lists: worktrees whose branch is merged into `origin/main`.

## S3. The commander is the merge queue (= FI-F1, FI-F2)

**Evidence**
- Handoff 2026-10-22 E2 made merging "the commander's"; the agents ended their reports with "Waiting on you: merge #68 once CI is green" (live:4273).
- He then batch-merged about 45 PRs: #80-#95 merged between 2026-10-23T00:37Z and 01:30Z (`gh pr list`).
- 19 PRs, opened 2026-10-23 02:11-04:44Z, were still open on 2026-10-26 until MERGE-ALL. #99 merged at 2026-10-26T23:08:21Z.
- **Repo settings:** `allow_squash_merge: true`, `allow_rebase_merge: true`, `allow_auto_merge: false` and `delete_branch_on_merge: false` (`gh api repos/nobul-tech/aitools`).
- **Ruleset 16468370 "Reibung"** has only `deletion` and `non_fast_forward` rules: no required status checks.
- Squash merges (#50-#73: subjects end "(#NN)") orphaned the #74/#75 stack (handoff D.2).

**Root cause**
- Policy said agents never merge, and GitHub enforces no gate, so the only gate was the commander's attention.
- Mixed merge methods (squash, then merge commits) broke the lineage of stacked branches.

**Remedy**
- **Repo setting:** allow merge commits only (`gh api -X PATCH repos/nobul-tech/aitools -f allow_squash_merge=false -f allow_rebase_merge=false`). This matches A1.
- **Ruleset:** add a `required_status_checks` rule for the `macos`, `linux` and `windows` jobs. Then "CLEAN" means green by construction. Mind S11: with path filters, a required check needs a job that always reports.
- **Auto-merge (option for the plan):** `allow_auto_merge=true`, so a mission can run `gh pr merge <n> --merge --auto` and not poll. It stays gated by the required checks.
- **CI step** (pull_request): "base must be main". Fail when `${{ github.base_ref }} != main`. Stacks are expressed as "contains", with base main, as M3-FINISH did (#112 contains #103). This closes the #74/#75 class.
- **Unverified:** GitHub retargets open PRs when their base branch is deleted after a merge (the "delete branch on merge" behaviour). Check it with chrome-devtools before relying on it.

## S4. Context spent on hand-backs and re-statements

**Evidence**
- **Context warnings from the commander:**
  - 2026-10-21T03:25:39Z (1166): "we only have less than 70K tokens left in this window so be brief";
  - 03:47:06Z (1285): "2% context left, /handoff now";
  - 2026-10-22T03:34:05Z (3990): "we are running out of context so be token efficient";
  - 2026-10-23T00:35:55Z (5032): "be context window efficient but complete";
  - 02:04:35Z (5171): "be super efficieint with context".
- **Compactions:** two in the live session (lines 1361 and 5192).
- **Main-thread volume** (`handback-size.py`, live transcript):

  | Source | Messages | Characters |
  |---|---|---|
  | Sub-agent hand-backs | 33 | 284,747 (average 8,629 each) |
  | Task notifications | 23 | 45,025 |
  | The commander's own typed prompts | 82 | 59,214 |

  Hand-backs are 4.8 times the commander's text.
- **Older sessions:** 2026-03-25 (`2d439e32.jsonl:1350`): "what a stupid waste of context telling me about a claude.md diff here".

**Root cause.** /delegate tells the delegate to write its report to a file, but sets no size limit on the hand-back message. Delegates paste the whole report back, and every hand-back lands in the commander's thread.

**Remedy**
- **Rule (in /delegate "The delegate owes back"):** "The hand-back message is at most 25 lines: status, PR URL(s), report path, top 3 items, questions. Everything else is in the report file."
- **Hook check:** the `delegation-duty-guard.sh` element 8 "hand-back budget" (observe mode, per hook-rollout.md). It checks that the prompt states the limit, as it does for element 7.
- **Skill test:** add a case to `shared/skills/delegate/tests/expected-behaviors.md`: "Given a 300-line report, the delegate's final message is ≤25 lines and names the report path."

## S5. The commander repeats the same mission boilerplate

**Evidence.** In the live session's 93 typed prompts:
- 12 lines say "carry forward all OL" or the like (`grep -c -i "carry(ing)? forward|\bOL\b|operational learning"`);
- 21 lines say "orchestrator", "/delegate", "delegation duty" or "ask any open questions".
- Examples:
  - 6431: "carry forward all OL and fulfill your delegatioin duty and ensure your prompt instructs this corchestrator to do the same";
  - 6779: "it should be an orchestrator ... carry forward and pass down all OL ... use your /delegate skill ... ask any open questions".
- In an older session, 2026-03-26T19:21:36Z (`8236ca9c.jsonl:1565`), he was already asking for recursive OL carry-forward.

**Root cause.** /delegate lists the seven elements but sets no mission defaults. The SC-mission-packet is a per-session file in a handoff folder, not a harness artifact, so each new Session Commander depends on the commander to say it again.

**Remedy**
- **Rule (/delegate "Mission defaults" section, user level).** Unless the commander says otherwise, a mission launch:
  - is an orchestrator;
  - carries the latest handoff's OL section and the packet;
  - tells every delegate to read all rules;
  - surfaces open questions, each with a suggested answer;
  - writes versions, not drafts (D-DEL5);
  - ships per D-DEL4.
- **Artifact.** Promote `SC-mission-packet.md` into a template in the skill (`shared/skills/delegate/mission-packet-template.md`), so it no longer lives in one handoff folder.
- **Skill test:** an `expected-behaviors.md` case: "launch a mission to X" alone yields a prompt with all defaults (the delegation-duty-guard log shows 7/7).

## S6. Questions the commander cannot answer without a re-statement

**Evidence**
- In the live session, "restate", "re-state", "reprint" or "re-print" appears 19 times. "explain", "not sure what", "no idea what you", "im lost" and "what?" appear 12 times.
- Examples:
  - 2026-10-21T03:07:10Z (840): "what do you suggest? im lost here";
  - 2026-10-22T00:40:21Z (2871): "q4) what is the ledger? no idea what you're talking about";
  - 2026-10-22T20:40:43Z (4703): "2) what? cached alias? cached how?";
  - 20:35:07Z (4685): "restate your questions succintly";
  - 2026-10-26T21:58:13Z (6071): "1a) please restate all 3 1b) restate the edits ... 7) re-state row 3 of 96";
  - 22:10:25Z (6431): "1a) this is a bit conflated for me";
  - 22:47:02Z (7065): "re-state all open PRs and the order".

**Root cause.** Questions point at labels the commander does not hold in his head: "Q1c", "row 3 of 96", "A-6..A-9", "the ledger", "HARNESS Q5". The process (CLAUDE.md "The process" step 6, batch clarifications) says nothing about making each question self-contained.

**Remedy**
- **Rule (user-scope; CLAUDE.md "Coaching" UCI "Suggest answers with questions", extended).** "Every question restates its subject in plain words, quotes the text it would change, and gives a suggested answer. Never reference an item by a label alone."
- **Skill test (/delegate and /handoff expected-behaviors):** a question list that contains a bare label ("Q1c?") is a FAIL in review.
- **Hook (optional, observe mode).** A Stop hook that flags an assistant message ending in a question whose text matches `\b(Q[0-9]+[a-z]?|row [0-9]+|A-[0-9]+)\b` with no quote nearby.

## S7. The main checkout's branch was switched, and the mission packet vanished

**Evidence**
- Commander, 2026-10-22T03:45:14Z (4106): "I cant run aitools because the branch changed. why did the branch change here? it shouldt have, we should have stayed on main".
- The Session Commander's answer (4112, 4231): "Early in the session I ran `git switch -c docs/delegate-read-all-rules` in your main checkout". "SC-mission-packet.md had been committed on the old docs/delegate-read-all-rules branch (0d5bd51), so switching your checkout to main removed it" (4297).
- An older case: 2026-03-04 (`1f18d584.jsonl:394`), HEAD trouble with line endings in the local checkout.

**Root cause.** "Never switch the main checkout's branch" is only prose (packet section 4, handoff F3). standing-order-guard has no check for it (`grep -n "git (switch|checkout)|worktree" shared/hooks/standing-order-guard.sh`: no match).

**Remedy**
- **Hook check:** a new standing-order-guard check `MODE_MAINSWITCH`, observe mode first (hook-rollout.md).
  - It blocks `git switch`, `git checkout -b|-B|<branch>` and `git checkout <ref>` (but not `git checkout -- <path>` or `git checkout HEAD -- <path>`) when the command's repo, from `git -C`, a `cd` or the cwd, resolves to a top level outside `.claude/worktrees/`, and that top level is the primary worktree (`git rev-parse --git-common-dir` equals `--git-dir`).
- **Unit test:** `tests/hooks/test-standing-order-guard-mainswitch.sh`, per the hook-rollout.md pre-deploy verification.
  - Smoke: `git status` exits 0.
  - Violation: `git -C <primary> switch -c x` is logged in observe mode and exits 2 in enforce mode.
  - Exemptions: the same command inside a linked worktree exits 0; `git checkout -- file` exits 0.

## S8. Local checks that are red by design (= FI-F7)

**Evidence**
- 36 commit bodies since 2026-10-20 cite pre-commit step 6 as a "known" FAIL (`--grep "step 6.*(known|fail)|FAIL 6|FAIL step 6"`). Incident #133: `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` is 100644.
- Pre-push step 7 FAILs on every push until the dotprofile rebuild (decision B1, 8e490d7).
- Step 3's `[\s]` false positives (#134), and step 20 FAILs cited in 97deb5a and dae07fe.
- The packet (`SC-mission-packet.md:78-82`) lists them as "known pre-existing failures (record, not blockers)".

**Root cause.** The failures were recorded, not fixed. A check that is always red teaches agents to ignore red, and a new failure inside a "known" step goes unseen.

**Remedy**
- **Fix:** `git update-index --chmod=+x` on the harvesting file (#133). Replace `[\s]` with `[[:space:]]` in check-pre-push.sh step 3 (#134).
- **Check-lib change:** a known-failures file, `scripts/check-known-failures.txt` (step id, incident id, expiry date). A listed step reports `KNOWN` (yellow), not FAIL, and the run's exit code ignores it until the expiry. After the expiry it is FAIL again.
- **Unit test:** `tests/checks/test-known-failures.sh`. A listed step that is still in date gives KNOWN and exit 0. An expired entry gives FAIL and exit 1. An unlisted FAIL gives exit 1.
- **Unit test for #134:** `tests/checks/test-secret-pattern.sh` asserts that `tokens:` is not flagged and that `token = value` is flagged, in bash and pwsh.

## S9. CI was the first, and only, Windows run (= FI-F4, FI-F6)

**Evidence**
- 87 of 245 non-merge commits since 2026-10-20 say "Not run: ... Windows" (`git rev-list --all --since=2026-10-20 --no-merges --count -i --grep="Not run:.*Windows"` against `--count`).
- The Session Commander: "Windows has never been run locally, and this CI run is its first real test" (live:4273).
- On main, the Windows job (`.github/workflows/check.yml:330-452`) runs logging, managed-files, a native resolver and build/drift. It runs none of `test-config.sh`, `test-lib.sh` or `test-user-init.sh`, which the macOS and Linux jobs both run (lines 134-149 and 302-308).
- Issue #72 is open: "PS1 managed-file review menu has no Windows test coverage". Handoff G7: nothing from the session ran on Windows.
- The commander's platforms (B5, 6721) include Windows.

**Root cause.** The Windows CI job was never given the M3 suites. There is no Windows machine in the loop, so "Not run: Windows" became a normal line in commit messages.

**Remedy**
- **CI steps** (windows job, via Git Bash with pwsh parity, as the managed-files steps do): "Config writer tests", "Profile lib wrapper tests" and "User init tests" (`bash tests/profile/test-config.sh`, `test-lib.sh`, `test-user-init.sh`).
- **CI step** (windows job): "Installer dry run". Run `pwsh -File scripts/aitools-install.ps1 -DryRun` under a temp `USERPROFILE`, then assert exit 0 and no writes outside the temp dir. This depends on incident #89 (dry-run ignored by tool scripts), so scope it to the config and user steps first.
- **CI meta-check** (linux job, "every suite is in CI"). For each `tests/**/test-*.sh|ps1`, `grep -F` its path in `check.yml`. Fail on any that is missing. On main today this catches `tests/deploy-harness/test-deploy-harness.sh`, `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` and `tests/build-package/test-cli.sh` (none is referenced in check.yml; `grep -n` returned no hit).
- **Unit test for the meta-check:** `tests/checks/test-ci-coverage.sh`. A fixture tree with one listed suite and one unlisted suite FAILs on the unlisted one.

## S10. CI fails on things the local run could not see (= FI-F6)

**Evidence.** The 8 non-success CI runs in the last 300 (`gh run list`; `gh run view --log-failed`) fall into four classes.

| Class | Run(s) | What failed | What fixed it |
|---|---|---|---|
| Different test mode in CI | 39891714493 (#108) | `a78-exc-ro`, `a8-mig-ro`: the real PID was not normalised in the bash-only run | dbcc61a: "case_fresh skipped the NORM_TMP normalisation (it ran only inside the parity block)". Local runs used the pwsh parity mode; the macOS 3.2 CI step is bash-only |
| Git default branch | 39873612279 (#86) | "error: src refspec main does not match any" | "test-user-init: pin bare remotes and clones to main (CI default branch is master)" |
| Windows path form | 39888735993 (#103) | 4 adopt-push ACTION asserts | c05fec8: the lib prints `display_path` (cygpath -w) on MSYS |
| Known red pushed | 39859094088, 39861809999, 39861915512 (#86) | c1/c2/c3/c8 "no row 'OK\|aitools config\|created'" (WARN instead) | 693a7e7's body: "test-config 85/4 (c1, c2, c3, c8): the same 4 fail on the tree before this commit ... batch 4 owns it" |

**Root cause.**
- No single script runs a suite in the same modes as CI.
- Test fixtures assume the git default branch and POSIX paths.
- The rules do not forbid pushing a red suite.

**Remedy**
- **Single source for test modes.** `tests/run-suites.sh <suite...>` holds the mode matrix CI uses: bash 5 with pwsh parity, `/bin/bash` 3.2, and `--bash-only`. CI steps call it, and agents run it locally. A new check-pre-push step runs it for each suite whose directory or scripts the branch touches (`git diff --name-only origin/main...HEAD`).
- **Test-helper lint (check-pre-commit step, and a CI step on linux).**
  - `grep -n -E "git (-C [^ ]+ )?init( |$)" tests/` must show `-b main` or `--initial-branch=main` on every hit.
  - Every expected path in an assert goes through a shared helper (`expect_path`) that applies `display_path` the way the lib does.
  - Unit test `tests/checks/test-test-lint.sh`: a fixture with a bare `git init` FAILs.
- **MSYS path simulation.** Add `AITLIB_TEST_FORCE_MSYS=1` to the lib's `display_path` (in the style of the existing `AITLIB_PROFILE_VIA_PWSH=1`), so a macOS run can exercise the Windows path form. Add a test-adopt-push case that runs with it set.
- **Rule (script-standards.md "Verification").** "Never push a suite with failing cases. A case that cannot pass yet is marked `xfail <incident-id>` in the suite and reported as XFAIL." Plus a test-framework helper `xfail` in each suite, and a test that an XFAIL which passes is reported as XPASS (FAIL).

## S11. Channel commits pay for a full 3-OS CI run on main and slow the A6 wait

**Evidence**
- `check.yml:12-16` runs on every push to main and every PR, with no `paths-ignore` and no `concurrency`.
- **On main, 2026-10-26 22:01-23:09Z:** 10 CI runs, each 9-11 min (`gh run list --workflow CI`). The commits in that window (`git log --since=2026-10-26T21:55Z origin/main`):
  - 7 channel-exception commits: 480b901, 5976553, 1af8851, 8e18ad4, 0ddd127, 8953371, b40a320;
  - 3 code commits: 9923a3c, 8e490d7, and 568fb5b (build-package scaffold, which the commander allowed on main at 6721);
  - the #99 merge.
- **PR runs under load:** on 2026-10-23, several took 25-33 min (for example 39891857647: 02:51Z → 03:22Z).
- **A6 (decision):** after every merge, wait for main's CI to go green. With FAN-PLAN, BUILD-PKG and RECONCILE committing to main, each wait includes their runs.

**Root cause.** The CI has no path filter. Channel-exception commits are docs only, but they trigger the full matrix (macOS brew bash install, every suite, the build).

**Remedy**
- **CI config:** `paths-ignore: ['.aitools/channel/**', 'plans/**']` on `push` and `pull_request`.
- **If S3's required checks are added,** keep one always-run job instead. A `changes` job uses `dorny/paths-filter`, which needs a /tool-eval first under the tool-evaluation rules, or a `git diff --name-only` step. The heavy jobs are skipped with `if:`, and a skipped required job counts as passed.
- **CI config:** `concurrency: { group: ci-${{ github.workflow }}-${{ github.event.pull_request.number || github.sha }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }} }`. This cancels superseded PR runs and never cancels main runs.
- **Mission rule (for A6):** wait on the CI run whose `headSha` is the merge commit (`gh run list --commit <sha>`), not on "latest main".

## S12. Review and report commits on PR branches

**Evidence**
- 25 commits since 2026-10-20 match `^Add (the )?S3-.*(report|review|verdict|hand-?back)` (`git rev-list --count -E --grep`).
- Examples:
  - 4999394 "Add S3-MF-Fix6-Review verdict for PR #108" and 945deb5 "Add S3-MF-Adopt report and independent review of PR #103", both on code PRs;
  - the review verdict file `S3-MF-Incidents-Review-pr102.md` inside #102.
- Each one moves the PR's head SHA, which reviewers cite exactly (brief A1), and it re-runs the 10-30 min CI matrix.

**Root cause.** Packet section 5 says to write outputs "in your worktree", so hand-backs ride on the code branch. The channel exception (2026-10-26) came later.

**Remedy**
- **Rule (/delegate and the packet).** Reports, reviews and hand-backs go to main under the channel exception, never on a code branch. A reviewer's verdict goes on the PR as `gh pr comment` and in its own file, committed to main.
- **CI step:** the S2 detector, reversed. On a pull_request whose diff mixes code with `.aitools/channel/**` files, give a WARN annotation: "move channel files to main".

## S13. Stale main checkout: rules and skills load old

**Evidence.**
- Handoff 2026-10-22 section A: the main checkout was "105 commits behind origin/main ... Rules that Claude Code loads from it are the pre-session versions. Skills load from it too".
- G6 asked the commander to pull.
- No hook warns about it: `grep -rln "behind origin"` in `shared/hooks` found nothing. Only `relay-outbound-prompt.*` and the entry points check ahead/behind, at `aitools` run time.

**Root cause.** Missions work in worktrees that start from origin/main, while the session's own rules and skills load from the main checkout, which nothing keeps current.

**Remedy**
- **Hook:** a SessionStart addition (new hook, per the "new hooks for new features" decision of 2026-03-16, `b8a9ed4e.jsonl:1252`). When the session's repo is the aitools primary worktree and `git rev-list --count HEAD..@{u}` (using the last-fetched refs, no network) is above 0, print "main checkout is N commits behind origin/main: rules and skills are stale; run git pull --ff-only".
- **Unit test:** `tests/hooks/test-stale-checkout.sh`. A temp repo with a bare remote one commit ahead gives the message. Up to date gives no output. A linked worktree gives no output.

## S14. Unverified claims about delegate nesting ("ultracode")

**Evidence**
- Commander:
  - 2026-10-21T23:30:20Z (2006): "im surprised they have no agent tool ... run a quick test launchiung a delegate with "ultracode" ... try to see if we can get 3 deep";
  - 2026-10-26T23:07:00Z (7335): "test in a background workflow agent if that background workflow agent can launch a general purpose agent. im not convinced that this is true".
- The probe's result (7360): "NO ... I have no Agent, Task or Workflow tool".
- Incident #139 is open. The latest main commit is "Record the 2026-10-26 workflow nesting probe in tool-ops-claude-code".

**Root cause.** The behaviour depends on the Claude Code version and the launch path (#59). The record carries no version, so it cannot be trusted across upgrades, and the commander re-asks.

**Remedy**
- **Check step** (check-post-push, new step). The tool-ops-claude-code nesting record holds `probedVersion`. The step compares it with `claude --version` and WARNs "Claude Code changed since the nesting probe (X → Y): re-run the probe (tool-ops-claude-code 'Nesting probe')".
- **Unit test:** `tests/checks/test-nesting-probe-age.sh`, with a stub `claude` on PATH: same version gives PASS, a different version gives WARN, and a missing record gives WARN.
- **Rule:** /tool-ops records every probe as a procedure plus a dated, versioned result.

## S15. Usage limits and stops cut missions mid-work

**Evidence**
- 2026-10-22T01:25:25Z (3819): the usage-limit notice.
- 03:24:35Z (3832): "hit session limits before ... can you take whatever corrective action needs to be taken to restart the SOURCE-TRUTH mission? is any of the work salvagable?".
- 2026-10-21T03:20:48Z (933): "the stop of those agents was accidental. please remediate as needed".
- Handoff I: "PROFILE-TOOLS ran out of context at batch B5".

**Root cause.** A stopped mission's state lives in its context. "Commit and push after every batch" (OL) keeps the code, but not the running estimate or the next step.

**Remedy**
- **Rule (/delegate mission defaults, S5).** After each batch, an orchestrator updates `<MF>/<name>/<prefix>-state.md` (v1.N): done, in flight with branch and worktree, next, open questions. It commits the file to main under the channel exception. A restart reads only that file.
- **Skill test (/mission-control):** "resume mission X" reads the state file first.

## S16. Merge policy written in three places that now disagree

**Evidence**
- A1 (2026-10-26T22:59:58Z, 7286): "merge commits, mission merges".
- The dotprofile `claude/rules/delegation.md` D-DEL4 limits: "never merge or approve its own PR"; packet section 4: "Never push to main, force-push, merge or approve your own PR, or tag".
- The repo allows squash and rebase (S3).
- Decision C (6024): "dotprofile pushes outside of main branch should error out"; B2: channel paths go direct to main. Both contradict the packet's "never push to main" for those paths.

**Root cause.** Each decision was recorded where it was made (brief, CLAUDE.md, chat), and no single file says who may merge or push what.

**Remedy**
- **Rule (dotprofile `delegation.md`):** a decision D-DEL6, "merge authority". By default delegates never merge. A commander-authorised orchestrator merges with merge commits only, when every required check is green and the state is CLEAN, in the stated order. Channel-exception paths are pushed to main by any agent. Give the source decision IDs (A1, B2, C).
- **Settings:** S3 (merge commits only, required checks).
- **Check step** (check-post-push, new step): read the repo's merge settings via `gh api` and WARN when squash or rebase is allowed.

---

## Process friction with no automated catch

- **Long, multi-part prompts with numbered answers** (for example 6071: 7 parts; 2542: about 20). The Session Commander lost track of parts, and the commander re-asked (S6). Suggested: echo each numbered answer back as a one-line "understood as" table before acting. That is a process change, not a test.
- **Mission naming and tables** were asked for repeatedly: "give them all names ... give me a table" (2871), "state by mission number and give each one a name" (1741), "give each mission an intent block and a name" (1618). Suggested: the mission table format (name, commander name, intent, detailed objectives, owner files) becomes a template in /delegate or /planning.

## INCIDENT markers (not filed)

- **INCIDENT:** `shared/hooks/harness-db-sessionstart.sh.bak.2026-06-21T203304Z` and `shared/hooks/standing-order-guard.sh.bak.2026-06-21T203334Z` are tracked in git (`git ls-files shared/hooks`). No check flags tracked `*.bak.*` files. Suggested check step: `git ls-files | grep -E '\.bak\.[0-9]{4}-'` gives FAIL.
- **INCIDENT:** `tests/build-package/test-cli.sh` (added with BUILD-PKG B0, 568fb5b) is not run by CI (`grep -n build-package .github/workflows/check.yml`: no hit). This is the same class as G16, which covers `tests/deploy-harness*` and `rules-fanout-cursor`.
- **INCIDENT:** The Windows CI job lacks the config writer, lib wrapper and user init suites that macOS and Linux run (check.yml:330-452 against 134-149 and 302-308). This ties to #72 and G7.
- **INCIDENT (ambiguity):** Merge authority conflicts across A1, D-DEL4 ("never merge") and the packet (S16). No rule records the mission's merge authority.
- **INCIDENT:** The repo merge settings allow squash and rebase, against the commander's merge-commit decision A1. Squash merges orphaned #74/#75 (handoff D.2).
- **INCIDENT:** CI runs the full matrix for channel-exception-only commits, which delays the A6 post-merge wait (S11).

## Open questions (each with a suggested answer)

1. **S8 known-failures file, or fix only?** Suggested: fix #133 and #134 now, and add the expiring known-failures file only for step 7 until the rebuild. A permanent allowlist is the failure mode.
2. **S3 required checks before or after the 19 merges?** Suggested: after the last merge and before the RELEASE mission, so the queue is not disturbed mid-way. The S11 always-run job must land first, or required checks will block channel commits.
3. **S7 hook scope:** every repo or aitools only? Suggested: every repo, at user level (the rule "never switch the main checkout's branch" is user-scope OL).
4. **S4 hand-back limit:** 25 lines? Suggested: 25 lines, with the report path on line 1.
5. **S2 reviewer worktrees:** retire them? Suggested: yes. Reviewers read with `gh pr diff` and `git show`, and only a reviewer that must run tests gets a worktree.

## Provenance

- Live transcript lines cited: 7360, 7335, 7306, 7286, 7264, 7065, 6779, 6721, 6712, 6494, 6431, 6071, 6024, 5421, 5376, 5171, 5057, 5032, 4703, 4685, 4297, 4273, 4231, 4112, 4106, 3990, 3832, 3819, 2871, 2542, 2006, 1741, 1618, 1285, 1166, 933, 840.
- Archived sessions cited:
  - `2026-03-26_d5b52bf2.jsonl:539`
  - `2026-03-25_2d439e32.jsonl:1350`
  - `2026-03-26_8236ca9c.jsonl:1565`
  - `2026-03-16_b8a9ed4e.jsonl:1252`
  - `2026-03-03_1f18d584.jsonl:394`
  - `2026-06-23_d2fc528a.jsonl:8` ("false starts and stops with mission command and mission control")
- CI runs: 39891714493, 39891264259, 39890650263, 39888735993, 39873612279, 39861915512, 39861809999, 39859094088; durations from `gh run list --workflow CI --limit 40`.
- Commits: dbcc61a, c05fec8, 693a7e7, bb43536, 0d5bd51, 5976553, 1af8851, 8e490d7, 568fb5b.
- Scratch tools (reusable, for /harvest): `/Users/new-jose/repos/aitools/.scratch/session-fricsess/typed-prompts.py`, `run-all.sh`, `handback-size.py`, `failed-jobs.sh`.
- Not done: Windows; any live probe; filing incidents; writing any plan or rule (MERGE-ALL's friction plan consumes this file).
