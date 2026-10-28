# S3-Hook2 hand-back v1.0 (2026-10-28)

**Intent**: **Purpose**: Record what mission HOOK-2 delivered, with its evidence, for the
Session Commander and for MERGE-3, which merges the three PRs. **Scope**: The verified answer
to "does the hook fire per agent()?", the three PRs and their reviews, the hook audit table,
tests, and the process signals. NOT the contract (`S3-Hook2-spec.md` v1.1). NOT the delegates'
own detail (`S3-Hook2-Parser-handback.md` v1.2 in this folder; `S3-Hook2-Db-handback.md` and
`S3-Hook2-Audit-handback.md` on their PR branches). **Audience**: The commander (Jose), Session
Commander 10cf255a-c, MERGE-3.

Mission HOOK-2: S3-Hook2, orchestrator, level 1, delegated by Session Commander 10cf255a-c.

## Summary

1. The delegation guard does **not** fire per `agent()`. One Workflow call raises one
   PreToolUse event, and its `tool_input` carries the whole `script`. A new hook,
   `workflow-delegation-guard.sh` (PR #135, observe mode), parses the script at that event and
   scores each `agent()` prompt for the eight elements.
2. `delegation.avgScore` and `delegation.minScore` in harness-db are now fractions from 0 to 1:
   each event's score divided by its own total (PR #133).
3. The hook audit fixed two more hooks whose guidance never reached Claude: `sh-file-fixup.sh`
   wrote to stderr at exit 0, and `glossary-skill-guard.sh` printed JSON without
   `hookEventName`. It also fixed three hooks whose status lines lied (PR #134).
4. Each PR has an independent reviewer's APPROVE, re-verified on its final head, plus two
   logging audits with 0 blocking findings. CI is green. None is merged.
5. Dotprofile `claude/rules/delegation.md` "Detection" now names both hooks (8299a2d, dotprofile
   main), and `/delegate` SKILL.md step 13 is updated in #135.

## Does the hook fire per agent()? (verified)

No. Evidence: spec v1.1 section 1.

- Hooks reference https://code.claude.com/docs/en/hooks, read with chrome-devtools on
  2026-10-28 (Claude Code 2.1.309):
  - PreToolUse "Matches on any tool name except EndConversation: built-in tools such as ...
    Agent, Workflow, ...".
  - "When a subagent calls a tool, tool events such as PreToolUse and PostToolUse fire the same
    configured hooks as in the main conversation, and the input carries the agent_id and
    agent_type common input fields".
  - "Claude never sees stderr from a hook that exits 0."
- Live record from session 10cf255a-c:
  - The 5 real Workflow payloads carry only `script`.
  - The agent transcripts of workflow wf_11a87d20-2c7 hold 34 `PreToolUse:Bash`, 1
    `PreToolUse:Read` and 68 `PostToolUse:Write` hook records. So hooks fire on the tool calls
    inside workflow agents.
  - `agent()` is a workflow-runtime function, and workflow agents have no Agent, Task or
    Workflow tool (probe wf_e09cb1ca-dca).
- Not run: a live tiny workflow with a logging hook. S3-Hook2 had no Workflow tool.

## PRs (base main, none merged)

| PR | What | Final head | Review (final head) | Logging audits | CI |
|----|------|-----------|---------------------|----------------|----|
| [#135](https://github.com/nobul-tech/aitools/pull/135) | workflow-delegation-guard.sh; delegation-duty-guard.sh back to `Agent`; shared element block plus parity test; registration; `/delegate` step 13 | this commit (see the PR) | APPROVE at f88fb7d ([comment](https://github.com/nobul-tech/aitools/pull/135#issuecomment-6477613522)); re-verify of the final head requested | A [#6477521892](https://github.com/nobul-tech/aitools/pull/135#issuecomment-6477521892), B [#6477552511](https://github.com/nobul-tech/aitools/pull/135#issuecomment-6477552511): 0 blocking | green at f88f539 (run 40749416939) |
| [#133](https://github.com/nobul-tech/aitools/pull/133) | harness-db: scores as score/total fractions; `checked:0` and malformed events skipped and logged; no `total` = /6 | de94c7f | APPROVE ([comment](https://github.com/nobul-tech/aitools/pull/133#issuecomment-6476601106)) | A [#6475829041](https://github.com/nobul-tech/aitools/pull/133#issuecomment-6475829041), B [#6475836584](https://github.com/nobul-tech/aitools/pull/133#issuecomment-6475836584): 0 blocking | green (run 40737493957) |
| [#134](https://github.com/nobul-tech/aitools/pull/134) | hook output-channel audit and fixes | 8104649 | APPROVE ([comment](https://github.com/nobul-tech/aitools/pull/134#issuecomment-6477004337)) | A [#6475829610](https://github.com/nobul-tech/aitools/pull/134#issuecomment-6475829610), B [#6475837135](https://github.com/nobul-tech/aitools/pull/134#issuecomment-6475837135): 0 blocking | green (run 40737729046) |

The non-blocking review findings were sent back as fix batches, and each PR's reviewer
re-verified its final head.

**Merge note.** #133 and #135 both edit the `registries/tool-ops.json` `delegationDutyScore`
line, so whichever merges second gets a one-line conflict. The resolved line is in #135's body,
section "Merge note (for MERGE-3)". A pointer is on #133
([comment](https://github.com/nobul-tech/aitools/pull/133#issuecomment-6477446591)).

## Hook audit table (PR #134)

| Hook | Event | Before | Who saw it | Change |
|------|-------|--------|------------|--------|
| sh-file-fixup.sh | PostToolUse | stderr at exit 0 | nobody (935/935 records) | additionalContext JSON plus stderr; `git -C`; failures reported with git's error; no pipefail abort; every control character escaped; Windows and relative paths handled |
| glossary-skill-guard.sh | PreToolUse | JSON without `hookEventName` | nobody (7/7 rejected; docs: "requires a hookEventName field") | `hookEventName` added |
| harness-db-sessionstart.sh, scratch-init.sh | SessionStart | helper errors hidden; "registered" printed on failure | stdout only | `2>&1`, `PYTHONUNBUFFERED=1`, honest status line |
| harness-db-sessionend.sh | SessionEnd | always said "JSON exported" | nobody (output discarded) | each step checked; honest status line; failure logged |
| intelligence-stop.py | Stop | exit 2 + stderr | Claude | docstring only |
| command-channel-stop, failure-mode-*, standing-order-guard, block-claude-code-guide, block-explore-agent | Stop / PreToolUse | exit 2 + stderr, or deny JSON | Claude | none |
| dashboard-serve, session-catchup, session-archive, harvest-session, tool-ops-session-audit | SessionStart / SessionEnd | stdout or logs, as designed | as designed | none |
| delegation-duty-guard.sh | PreToolUse | stderr at exit 0 | nobody (268 records) | fixed by #122 (merged 2026-10-28T17:35Z) |

No hook's mode changed, and no blocking exit changed.

## Tests and timings (macOS unless stated)

- workflow-delegation-guard suite: 68/68 at f88fb7d under bash 5.3.15 and /bin/bash 3.2.57.
  After the fix batch, CI run 40749416939: macOS and Linux 78 passed plus 1 WARN; Windows 74
  passed, 1 SKIP, 3 WARN.
- delegation-duty-guard suite: 44/44 at f88fb7d; 47/47 after the fix batch (Windows 44/44; the
  3 Windows cases not run are to be named by the re-verify).
- Workflow guard timing, best of 5: 500 KB with 270 `agent()` prompts 72-83 ms; one 486 KB
  prompt about 28 ms; adversarial text about 55 ms. The GitHub macOS runner took 126-130 ms on
  the stress case, so the test WARNs between 100 and 250 ms and fails at 250 ms (listed under
  "Contract change" in the PR body).
- harness-db: 14 unittest cases OK.
- hooks: 142/142 under bash 5 and 3.2 (`tests/hooks/run-hook-tests.sh`, #134).

## Delegates and how they were verified

Parser (#135), Db (#133), Audit (#134), Review133, Review134, Review135, LogA and LogB (for
#133/#134), LogA135 and LogB135. How I checked them:

- I re-ran the Parser's suites myself, at phase 1 and after phase 2.
- I checked the parity test against the real file.
- I read the Db diff and checked that the Python 3.10 syntax is already required by the file.
- I checked the glossary JSON claim against main and docs line 706.
- I diffed tool-ops.json and corrected #133's "Review after" old values myself.
- I resolved the #135 merge conflict myself.

## Process signals

- **DEVIATION:** I branched the worktrees from origin/main before #122 merged. #122 was DIRTY
  at the time, and the work was in different or new files. Every branch merged origin/main with
  `--no-ff` after #122 merged.
- **CONFLICT:** the tool-ops skill says to present changes before writing; D-DEL5 (commander,
  2026-10-26) says protected files are written and reviewed after. Resolved by tier 1: protected
  edits are listed under "Review after".
- **CONFLICT** (from the reviewers, valid): the deployed `/delegate` v1
  (`~/.claude/skills/delegate/SKILL.md:258-259`, `gh pr review`) vs the v2.0 source and the
  prompts (`gh pr comment`). Resolved by tier 2: verdicts were posted with `gh pr comment`. My
  interim 1 report called this a misreading; that was wrong.
- **Renumbering:** the Parser's rows in `reference/tool-ops-claude-code.md` (#28 and #29 in
  Parser hand-back v1.1) are #29 and #30 after f88fb7d, because main added row 28.
- WRITE_BLOCKED: none. The Parser once wrote its hand-back into the main checkout by mistake and
  removed it within a minute; I verified the directory is gone.
- LogA (for #133/#134) did not read the newer dotprofile delegation.md or
  cross-platform-detail.md. The impact on a static audit is low.

## INCIDENT markers (not filed)

1. The deployed `/delegate` skill is stale against the v2.0 source: 7 elements, and it says
   `gh pr review`.
2. glossary-skill-guard JSON lacked `hookEventName`, so every reminder was rejected.
   RELEASE_NOTES.md:588 records it as fixed.
3. sh-file-fixup ran `git update-index` without `-C`, failed silently and reported success. Its
   `ls-files` pipeline crashed under pipefail.
4. No check verifies the output channel a hook claims. The new channel-asserting tests are a
   first prevention layer.
5. Perl CRLF output (Strawberry Perl) broke the result parsing in both delegation hooks. It is
   fixed in #135 with `PERLIO=:perlio`. Other hooks that parse perl output are not audited for
   this.
6. harness-db.py has no top-level exception logging; intelligence-stop.py has 10 silent
   `except Exception` handlers.
7. No runner executes the registries/tool-ops.json verification cases (from DDG-HOOK).

## Open questions (with suggested answers)

1. Should intelligence-stop move to Stop `additionalContext`? Suggested: yes, after it has been
   seen firing; it fired 0 times in 182 Stop summaries.
2. How should the scale change in the Datadog delegation gauges at #133's merge be handled?
   Suggested: an annotation on the dashboard, keeping the metric names.
3. Should the new context be confirmed after the next `aitools` deploy? Suggested: yes, rerun
   `hook-evidence.py` (h2audit `.scratch/session-h2audit/`) and expect non-empty content for
   sh-file-fixup, glossary-skill-guard and the delegation hooks.
4. When should `MODE_WF_DUTY` be promoted? Suggested: after one observe week with zero false
   positives, reviewing the `why` field in events.jsonl.
5. The RFCs (0002, 0005, 0006, rfc-0004-v3) still say the delegation score is "0-6". Suggested:
   one docs pass after #133 merges.

## Follow-ups

- Resolve `agent(r.prompt)` where `r` iterates a const array of object literals (unresolved
  today).
- Remove the two tracked `shared/hooks/*.bak.*` files.
- Child `workflow()` scripts and named workflows are not seen by any hook (documented limit).
