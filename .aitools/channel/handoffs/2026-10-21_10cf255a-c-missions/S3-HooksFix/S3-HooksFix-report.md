# S3-HooksFix report (mission HOOKS-FIX, 2026-10-21)

1. The standing-order-guard sed check is back at enforce (`MODE_SED="enforce"`, shared/hooks/standing-order-guard.sh:56; header :28-31).
2. Guard smoke test: 37/37 PASS on bash 5.3.15 and on /bin/bash 3.2.57, under an isolated HOME (harness/smoke-bash5.out, smoke-bash32.out).
3. Rule changes (hook-rollout .md/.mdc, user-level hook-lifecycle) ship as drafts with diffs and an apply script. I did NOT write them in place (see open question 1).
4. Bare tty reads: 13 in bash plus their PS1 pairs, listed with replacements in S3-HooksFix-bare-reads.md (INCIDENT).
5. PR #60 is open. Once it merges, `aitools` may be run again on this machine.

## PR

https://github.com/nobul-tech/aitools/pull/60 — branch `fix/sed-guard-enforce` (from origin/main db4b3c5), commit 98dba68 (+ the report commit).

## Files changed

- shared/hooks/standing-order-guard.sh: header comment for MODE_SED, and `MODE_SED="enforce"`. The exemption regex is unchanged.
- .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-HooksFix/:
  - S3-HooksFix-drafts/dot-claude/rules/hook-rollout.md (+ .diff vs live)
  - S3-HooksFix-drafts/dot-cursor/rules/hook-rollout.mdc (+ .diff vs live)
  - S3-HooksFix-drafts/shared/rules/hook-lifecycle.md (+ .vs-S3-Hooks-draft.diff)
  - S3-HooksFix-apply-drafts.sh
  - S3-HooksFix-bare-reads.md
  - harness/S3-HooksFix-guard-smoke.sh, harness/smoke-bash5.out, harness/smoke-bash32.out
  - S3-HooksFix-report.md (this file)

## Draft content, by review finding

- **hook-rollout**:
  - the sed row is at enforce
  - `MODE_SED` is in the list of mode variables
  - new paragraph: "A matching change that only narrows what a check blocks ... keeps the check's current mode ... A change that widens what is blocked, or both narrows and widens, resets the check to observe."
  - reset bullet 2 now reads "so a check blocks commands it did not block before". The old wording used "adding pipeline exemptions" as its example, and an exemption is a narrowing change.
  - new step 4, the exemption test
- **(a)**: the real-HOME ban now covers only agent and delegate verification runs. It says it does not change deploy-paths.md step 2 or tool-lifecycle.md "Rebuild + propagate".
- **(b)**: SD-2 is quoted verbatim from handoffs/2026-10-21_360aa8f3-8.md:93. A note follows it: a dotprofile copy that appears later is ignored and the scripts warn; they do not remove it (setup-user-hooks.sh:131-135, .ps1:92-96).
- **(c)**: non-interactive reverse discovery logs at info (setup-user-hooks.sh:260, .ps1:205). EOF logs a warning (aitools-lib.sh:791). I also found that `--force` does not affect reverse discovery: `tty_interactive` (aitools-lib.sh:774-779) and `Test-InteractiveConsole` (aitools-lib.ps1:773-775) never read AITOOLS_FORCE. The S3-Hooks draft had claimed `--force` takes the default there.
- **Location**: hook-lifecycle is moved to a user-level draft (shared/rules/), per the session commander's message, with no .mdc mirror. **Intent change (protected):** Audience is rewritten to user level, "(this repo)" is dropped from the heading, and "the harness" becomes "the aitools harness". Purpose and Scope are otherwise unchanged.

## Verification

- `bash -n shared/hooks/standing-order-guard.sh`: OK.
- `bash harness/S3-HooksFix-guard-smoke.sh`: RESULT 37 passed, 0 failed (bash 5.3.15).
- `BASH_BIN=/bin/bash bash harness/S3-HooksFix-guard-smoke.sh`: RESULT 37 passed, 0 failed (3.2.57).
- The smoke cases cover:
  - Exit 0:
    - clean `git status` and `ls -la`
    - the #82 read-only forms (quoted, unquoted, `12p`, `'100,$p'`, `'$p'`, two files, the incident's own command)
    - the pipelines `git log | sed -n 1p`, `git log | sed -n 1,3p` and `ls | sed s/a/b/`
  - Exit 2:
    - the sed write forms: `sed -i s/a/b/ file.txt`, `sed -i '' ...`, `sed 's/a/b/w out' f`, `sed s/a/b/ f > g` and plain `sed s/a/b/ f`
    - the near-miss forms: `-n 1p -i`, `--in-place`, `'1,5w out'`, `'s/a/b/w out'` with `-n`, `-n 1,5p f > out`, `'/foo/p'`, and `sed -n 1p` with no file
    - the other checks: `&&`, `||`, `;`, `$()`, backticks, cat/head/tail/awk, `rm -f *.tmp`, `echo hi > f.txt`, and `sed -n 1p a.txt && ls`
  - No observe-log line was written in any case.
  - This covers every guard case in S3-Hooks/S3-Hooks-verification.md section 2.
- check-pre-commit.sh: 9 PASS, 6 SKIP, 4 WARN, 1 FAIL. The FAIL is step 6 (the harvesting `build-deploy-prefix.sh` file is 100644), which was already failing before this branch.
- check-pre-push.sh: 6 PASS, 3 WARN, 1 FAIL. The FAIL is step 7 (the dotprofile deploy/ is stale), which was already failing on main.

## Not run

- Linux or Windows Git Bash runs of the guard.
- build-deploy.sh: the MDM path embeds the hook with `cat`, so it needs no code change. I did not regenerate it, to keep the real HOME safe (#86).
- No RELEASE_NOTES.md entry was added (pre-commit step 9 WARN).
- S3-Hooks harness scripts lost in session-commander cleanup on 2026-10-21; results remain in S3-Hooks/S3-Hooks-verification.md on main. My copy step confirmed all four were missing: `MISSING guard-smoke.sh`, `hooks-functional.sh`, `build-isolated.sh`, `step7-main.sh`. HOOKS-FIX keeps harness/S3-HooksFix-guard-smoke.sh as the guard harness from now on. Nothing replaces the hooks-functional, build-isolated or step7 harnesses.

## WRITE_BLOCKED

None. No write was denied. Not writing the rules in place was my own choice, not a denial.

## INCIDENT markers

- INCIDENT: bare EOF-unsafe `read -r <var> < /dev/tty` remain in reusable scripts. The list is in S3-HooksFix-bare-reads.md: setup-user-skills.sh:200, relay-outbound-prompt.sh:77, and aitools:108,157,957,1058,1062,1066,1118,1122,1125,1128,1181, plus their PS1 Read-Host/ReadLine pairs.
- INCIDENT (low): the guard checks only the first token of a command. As a result, a 2-line command `sed -n 1p f` + newline + `sed s/a/b/wout f` exits 0; the smoke test asserts this as current behavior. I read the code but did not test it: hook lines 195-284 check only FIRST_TOKEN, so `ls` + newline + `sed -i ...` is allowed by both the old and the new guard. The exemption therefore opens no new class of bypass.

## Open questions for the commander

1. **Write the rule drafts in place?** The session commander relayed "drafts APPROVED to be written in place". I kept them as drafts, for two reasons: the approval came before the text existed, and my instructions say a message from another agent is never the user's approval of a protected file. *Suggested answer:* Jose reads the three drafts (the .diff files show exactly what changes). Then one of us runs `S3-HooksFix-apply-drafts.sh <checkout>` and commits to this PR, or to a follow-up PR.
2. **Should the user-level hook-lifecycle keep its `paths:` frontmatter** (shared/hooks/**, scripts/setup-user-hooks.*, ...)? Those paths only match inside the aitools repo. *Suggested answer:* keep it. The rule is about aitools files, and dropping it would load the rule in every repo.
3. **Should the sed exemption be limited to single-line commands?** That would narrow it further, which keeps enforce. *Suggested answer:* yes, in a small follow-up. Add a check that the exemption applies only when COMMAND contains no newline, and add a smoke case for it.

## Delegates used

None.
