# S3-Hook2-Audit handback (v1.0, 2026-10-28)

Mission HOOK2-AUDIT, delegated by S3-Hook2. Branch `fix/hook2-hook-stderr`
(nobul-tech/aitools), PR base `main`. Audience: S3-Hook2 and the commander.

## Summary

1. Audited all 19 hook scripts in `shared/hooks/` (18 manifest entries + the
   `intelligence-stop.py` sibling) against the Claude Code hooks reference
   (2.1.309, saved 2026-10-28) and against 349 session transcripts.
2. Two hooks never delivered guidance to Claude: `sh-file-fixup.sh` (stderr at
   exit 0, 935/935 records) and `glossary-skill-guard.sh` (JSON rejected for a
   missing `hookEventName`, 7/7 records). Both fixed.
3. Two SessionStart hooks hid harness-db.py errors from Claude and claimed
   "registered" on failure; fixed (2>&1, honest status line).
4. Two files only had wrong channel comments (`harness-db-sessionend.sh`,
   `intelligence-stop.py`); corrected. No exit code changed anywhere.
5. 103 tests (4 files + runner) pass on bash 5.3 and /bin/bash 3.2.57; the
   changed-hook tests fail against the origin/main hooks; CI steps added on
   macOS (5 + 3.2), Linux and Windows Git Bash.

## Sources

- Docs: `/Users/new-jose/repos/aitools/.claude/worktrees/hook2/.scratch/session-hook2/hooks-doc-2026-10-28.txt`
  - L535: "Claude never sees stderr from a hook that exits 0."
  - L534: plain stdout reaches Claude only on UserPromptSubmit, UserPromptExpansion,
    SessionStart, PostModelSwitch; otherwise it goes to the debug log.
  - L647-683: exit 2 table (PostToolUse "Shows stderr to Claude; the tool already
    ran"; SessionStart/SessionEnd "Shows stderr to user only"; Stop "Prevents
    Claude from stopping, continues the conversation").
  - L706: "hookSpecificOutput ... requires a hookEventName field set to the event name."
  - L1461 (PostToolUse additionalContext), L1275 (PreToolUse additionalContext),
    L866 (SessionStart plain stdout), L1898-1911 (Stop additionalContext continues
    the conversation), L2424 (SessionEnd discards JSON output).
- Transcript evidence: `.scratch/session-h2audit/hook-evidence.py` and
  `stop-evidence.py` over `/Users/new-jose/.claude/projects/-Users-new-jose-repos-aitools/`
  (349 transcripts, main + subagents + workflow agents). Per-hook counts below.
  The scripts are in scratch (gitignored); counts are quoted here.

## Audit table

Event and matcher from `shared/hooks/hooks-manifest.json`. "Records" are
`attachment` records of type `hook_*` in the transcripts (a hook that prints
nothing leaves none); Stop hooks are recorded in `stop_hook_summary` entries
(182 found, 0 with hookErrors, 0 with hookAdditionalContext, 0 prevented
continuation).

| Hook | Event (matcher) | Output before | Who saw it | Change | Test |
|---|---|---|---|---|---|
| sh-file-fixup.sh | PostToolUse (Write\|Edit) | fix report on stderr, exit 0 | Nobody (L535). 935 records, all exit 0, stderr non-empty, content empty | stdout `hookSpecificOutput.additionalContext` (PostToolUse) + same text on stderr; `git -C <file dir> update-index` (from a cwd outside the file's repo it failed silently and was reported as `git+x` fixed, on every later write too); a failure is reported as `fix failed` | test-sh-file-fixup.sh (22) |
| glossary-skill-guard.sh | PreToolUse (Read\|Grep) | stdout JSON without `hookEventName`, exit 0 | Nobody: 7/7 records `hook_non_blocking_error` "hookSpecificOutput is missing required field hookEventName" | `"hookEventName":"PreToolUse"` added; hook contract comment | test-glossary-skill-guard.sh (12) |
| harness-db-sessionstart.sh | SessionStart | stdout status (reaches Claude); harness-db.py stderr passed through at exit 0; "registered" printed even when harness-db.py failed (`\|\| true`) | stdout: Claude (8 records, content non-empty). stderr: never Claude (L535, L667) | harness-db.py with `2>&1`; "registered" only when both calls exit 0, else "NOT registered (harness-db.py <step> failed; ...)" | test-sessionstart-harness-db.sh (15 of 34) |
| scratch-init.sh | SessionStart | same harness-db.py pattern | same (8 records) | same change | test-sessionstart-harness-db.sh (19 of 34) |
| harness-db-sessionend.sh | SessionEnd | stdout line + harness-db.py stderr; comments said "warnings visible to Claude" | Nobody (L2424; L669 stderr to user only; no next turn) | comments only; harness-db.py logs to `~/.aitools/logs/harness-db.log` (harness-db.py:372, :1120-1129) | smoke (2) |
| intelligence-stop.sh / .py | Stop | stderr + exit 2 on new intelligence | Claude (L654, L1899); 0 firings in 182 Stop summaries | docstring only: it claimed "intel injected via stdout JSON additionalContext" at exit 0, which the code never did; exit 2 kept | smoke (4) |
| command-channel-stop.sh | Stop | stderr + exit 2 on a pending directive | Claude (L654); 0 firings | none | smoke (5) |
| failure-mode-identity-stop.sh, failure-mode-verify-stop.sh | Stop | none (stubs) | n/a | none | smoke (2) |
| standing-order-guard.sh | PreToolUse (Bash) | enforce: stderr + exit 2; observe: log file only | Claude on every block (L539, L1277) | none | smoke (6) |
| block-claude-code-guide.sh | PreToolUse (Agent) | `permissionDecision: deny` JSON, exit 0 | Claude (L1273 "For deny, shown to Claude") | none | smoke (4) |
| block-explore-agent.sh | PreToolUse (Agent) | same | Claude | none | smoke (4) |
| dashboard-serve.sh | SessionStart | stdout line | Claude (8 records) | none | not run (starts the aitools CLI or a server) |
| session-catchup.sh | SessionStart | none (logs to files) | n/a | none | smoke, no-helper path (2) |
| session-archive.sh, harvest-session.sh | SessionEnd | none (logs to files) | n/a | none | smoke, no-helper path (4) |
| tool-ops-session-audit.sh | SessionEnd | JSONL log only | n/a | none | smoke (2) |
| delegation-duty-guard.sh | PreToolUse (Agent) | stderr at exit 0 | Nobody: 268 records, stderr-only (confirms DDG-HOOK B1) | out of scope: PR #122 | (PR #122) |

### Stop hooks: the option analysis

No Stop hook prints guidance at exit 0. The two that emit (`command-channel-stop`,
`intelligence-stop`) use exit 2 + stderr on purpose, which Claude reads as the
reason to continue. Options for a Stop hook's message (docs L1893-1911, L711):

- exit 2 + stderr (current): reaches Claude, continues the turn, labelled a hook error.
- `hookSpecificOutput.additionalContext` at exit 0: reaches Claude, continues the
  turn the same way (same 8-continuation cap), labelled "Stop hook feedback".
- `systemMessage`: shown to the user only; Claude never sees it.

Both delivering options force a continuation; the mission keeps blocking
behaviour unchanged, so both hooks stay at exit 2. Moving `intelligence-stop` to
`additionalContext` (same effect, no error label) is a follow-up for the
commander, not done here.

## Files changed

- `shared/hooks/sh-file-fixup.sh`, `glossary-skill-guard.sh`,
  `harness-db-sessionstart.sh`, `scratch-init.sh`, `harness-db-sessionend.sh`,
  `intelligence-stop.py`
- `tests/hooks/hook-test-lib.sh`, `run-hook-tests.sh`, `test-sh-file-fixup.sh`,
  `test-glossary-skill-guard.sh`, `test-sessionstart-harness-db.sh`,
  `test-hooks-smoke.sh` (new)
- `.github/workflows/check.yml`: "Hook output-channel tests" steps (macOS bash 5
  and /bin/bash 3.2 after the build-deploy tests; Linux after the build-deploy
  test; Windows Git Bash before "Build deploy scripts"). Placed away from PR #122's
  insertion points: `git merge-tree` of this branch with
  `origin/feature/ddg-agent-workflow` is clean.
- Not changed: `.claude/rules/hook-rollout.md` / `.mdc` (none of the changed hooks
  has a row: none blocks or has a mode variable), `registries/tool-ops.json` (its
  verification cases cover only block-claude-code-guide and delegation-duty-guard,
  neither changed here), `scripts/harness-db.py`.

## Verification

- `bash tests/hooks/run-hook-tests.sh`: 103 passed (bash 5.3.15).
- `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/run-hook-tests.sh`: 103 passed (3.2.57).
- Regression: with `TEST_HOOK_OVERRIDE` / `TEST_HDB_HOOK_OVERRIDE` /
  `TEST_SI_HOOK_OVERRIDE` pointing at the origin/main versions, the tests fail
  7 (sh-file-fixup), 3 (glossary) and 14 (SessionStart) checks.
- JSON is checked with python3 `json` (perl JSON::PP fallback); additionalContext
  must equal the stderr text.
- `bash -n` and `/bin/bash -n` on every changed script; `python3 -m py_compile`
  on intelligence-stop.py; no `grep -P`.
- `check-pre-commit.sh`: 12 PASS, 4 WARN, 1 FAIL = step 6, the known
  `harvesting/2026-07-09_session-ba4c0c12-7_build-deploy-prefix.sh` at 100644.
- `check-pre-push.sh`: 6 PASS, 3 WARN, 1 FAIL = step 7, the known stale dotprofile `deploy/`.
- All hook runs used an isolated HOME and a non-git cwd (no telemetry into a real
  session dir, no real harness DB).

## Not run

- `dashboard-serve.sh` (launches `aitools dashboard` or a server).
- The ait-harvest.py paths of session-archive / harvest-session / session-catchup
  (archive commits and pushes the dotprofile); only their no-helper fallback.
- A live Claude Code session confirming the new additionalContext arrives (the
  transcript record type after the fix is unknown until it is deployed).
- `build-deploy.sh` (agents may not run it against the real HOME); the MDM
  embed of the changed hooks is automatic (`shared/hooks/*.sh` read at build time).
- Windows Git Bash locally (CI covers it).

## Review after (D-DEL5)

- `shared/hooks/intelligence-stop.py` docstring (Purpose/Scope/Audience block):
  - item 3: "Inject summary via stderr when new intelligence found or context
    threshold crossed." -> "Inject summary via stderr + exit 2 when new
    intelligence is found (the context-threshold warning is inert, see
    format_context_warning)."
  - Hook contract: "Exit 0 = allow (intel injected via stdout JSON
    additionalContext if present)" / "Exit 2 = block (context warning via stderr,
    forces agent to address fear)" -> "Exit 0, no output = nothing new" / "Exit 2
    + stderr = new intelligence ... Exit 2 is kept as the delivery channel".
- No `.claude/rules/*.md`, `.cursor/rules/*.mdc`, `registries/tool-ops.json` or
  `reference/tool-ops-*.md` edits.

## CONFLICT

- CONFLICT: /delegate v2.0 "Orchestrate, don't execute" (commanders with more
  than a few files split into delegated batches) vs this prompt ("you may launch
  level-3 delegates ... if the hook count makes that worthwhile; otherwise do it
  yourself") -- resolved by tier 2 (prompt): did the work myself in two batches
  (code + tests + CI, then this document), verifying between them; no delegates.

## INCIDENT (not filed)

- INCIDENT: `glossary-skill-guard.sh` printed hookSpecificOutput without
  `hookEventName`; Claude Code rejected every reminder (7/7 transcript records,
  `hook_non_blocking_error`). Spec deviation vs the hooks reference L706. The
  mission prompt and RELEASE_NOTES.md:588 treated it as the correct example.
- INCIDENT: `sh-file-fixup.sh` ran `git update-index` without `-C`, so from a cwd
  outside the file's repo it failed silently (`2>/dev/null || true`) and reported
  `git+x` as fixed (script-standards "Error handling requirements").
- INCIDENT: hook comments asserted channels the docs contradict ("Stderr feedback
  is shown to Claude", "warnings visible to Claude", "intel injected via stdout
  JSON"); no check verifies a hook's claimed channel. Suggested prevention: the
  tests/hooks pattern (assert the channel, not just the exit code) for every hook.

## Follow-ups

1. Tracked backups `shared/hooks/harness-db-sessionstart.sh.bak.2026-06-21T203304Z`
   and `standing-order-guard.sh.bak.2026-06-21T203334Z`: left untouched; `git rm` them.
2. Deployed drift (compare only): `~/.claude/hooks/harness-db-sessionstart.sh` and
   `standing-order-guard.sh` differ from origin/main's `shared/hooks/`.
3. `intelligence-stop`: consider `hookSpecificOutput.additionalContext` (Stop) instead
   of exit 2 (same continuation, no hook-error label) -- commander decision.
4. `scratch-init.sh` and `harness-db-sessionstart.sh` both run `harness-db.py init`
   and `session start` on every SessionStart ("Session already exists" in the
   transcripts): one of them is redundant.
5. `glossary-skill-guard.sh` text is imperative ("Use /glossary skill instead"); the
   docs (L765) advise factual phrasing to avoid prompt-injection defenses.
6. `sh-file-fixup.sh`: on Windows the JSON-escaped `file_path` keeps doubled
   backslashes after the bash regex extraction; whether `[ -f ]` resolves it is
   unknown (CI uses POSIX temp paths). Without perl the hook exits non-zero
   (a non-blocking error), pre-existing.
7. `registries/tool-ops.json` has no verification cases for these hooks; adding them
   is a protected edit for a later mission.
8. RELEASE_NOTES.md not updated (pre-commit/pre-push WARN).

## Open questions

- Should `intelligence-stop` move to Stop `additionalContext`? Suggested answer:
  yes, after one week of observing how often it fires (0 of 182 so far); it keeps
  the continuation and removes the "hook error" label.
- Should the transcripts' new `hook_success` records for sh-file-fixup be checked
  after deploy? Suggested answer: yes, rerun `hook-evidence.py` after the next
  `aitools` run; expect non-empty `content` for sh-file-fixup and
  glossary-skill-guard.

## Delegates

None.
