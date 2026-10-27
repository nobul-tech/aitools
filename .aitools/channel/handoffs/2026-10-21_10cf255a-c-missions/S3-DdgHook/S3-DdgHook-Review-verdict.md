VERDICT: no blocking findings (v1.1, head `ad72004`)

# S3-DdgHook-Review: re-verification of PR #122 (v1.1)

Reviewer: S3-DdgHook-Review. Re-verified head `ad72004` ("Send delegation-guard output to Claude; check only the delegation text"), the same commit as the PR head (`gh pr view 122 --json headRefOid`). I worked independently again: I did not read the author's hand-back or scratch, and I did not take the fix message's claims on trust. v1.0 (head `98324ed`) is kept below.

## v1.0 findings: status

| v1.0 | Status at `ad72004` | Evidence |
|---|---|---|
| **B1** reminder never reaches Claude | **Fixed** | `finish()` (`delegation-duty-guard.sh:120-131`) prints `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"..."}}` on stdout when the exit code is 0, and the same text on stderr. Enforce exits 2 with stderr only (probe L2: rc=2, stdout 0 bytes). The hooks reference lists `additionalContext` as a PreToolUse `hookSpecificOutput` field: "String added to Claude's context alongside the tool result". The header states that limit (it corrects the next launch, not the current one). In every probe and both suites, stdout parses as JSON and `additionalContext` equals the stderr text exactly (python `json.loads`, bash 5 and 3.2) |
| **B2** `access` always present | **Fixed** | Only `tool_input.prompt` (Agent/Task) or `tool_input.script` / the `scriptPath` file (Workflow) is checked (`:160-209`). Probes with the real payload shape: A 7/8 missing access, A3 (Windows fields) 7/8 missing access, B `"Do the thing."` 0/8, G Workflow 7/8 missing access, Q (tool_input before cwd) 0/8. The suite now uses real-shape fixtures (`COMMON`) |
| **N1** identity / conflict false positives | **Fixed** | Probe C (`s3`, "merge conflict resolution") 0/8. The `toolu_01S3abcS9` id in the suite fixture no longer feeds identity |
| **N2** adversarial timing | **Fixed** | 300 KB `"name prefix "`: 50-59 ms (v1.0: 762 ms; main: 699 ms). 300 KB `"name "`: 52-61 ms (main: 587 ms). The 2 MB scriptPath is now refused (cap 512 KB). Worst case under the cap, 500 KB of `"x.md n prefix "` (probe M): 112-113 ms. 6 MB prompt: 148 ms (v1.0: 1151 ms) |
| N3 `\uXXXX` in scriptPath | Unchanged, safe | Probe F: "not checked", exit 0, reminder sent |
| N4, N5 | Unchanged (documented limits) | Header lines 27-38 |

## New non-blocking findings (v1.1)

- **N8. JSON escapes hide matches at the start of a line.** The checked text is still JSON-escaped, so a newline arrives as the two characters `\n`. Any element regex with a word-boundary or look-behind guard then fails right after a newline:
  - K1 `...\nRepo:\n/Users/new-jose/repos/aitools` with no other access phrase: 7/8, `access` missing. The look-behind `(?<![\w.])` sees the `n`.
  - K2: the same, with a `C:\\repos\\aitools` path at the start of a line.
  - K3 `...the\nrules too`: `rules` missing, because `\brules?\b` finds no boundary between `n` and `r`.
  - This was already true for `rules` on main. The `access` path alternative is new in this PR.
  - Effect: in observe mode these are reminders about elements that are actually present. They would count as false positives in the hook-rollout.md review before enforce.
  - Suggested fix: JSON-unescape the extracted text before matching (`s/\\n/\n/g; s/\\t/\t/g; s/\\"/"/g; s/\\\\/\\/g`; decode `\uXXXX` too, which would also fix N3). Then make the Windows-path alternative accept one backslash.
- **N9. Truncation and window limits produce false negatives by design.** Probe N: a real `Name every .md file with the prefix` phrase after 250 earlier `.md` mentions is reported as missing (the window limit is 200). Probe O: elements placed only after 264 KB of filler give 0/8 (the check limit is 256 KB). Both limits are in the code comments and the header. Real prompts are far below them. Acceptable for observe mode.
- **N10. Nested `prompt` key.** `{"tool_input":{"meta":{"prompt":"x"},"prompt":"<full>"}}` checks `"x"` (probe P, 0/8). The Agent tool has no such nested field, so this is theoretical.
- **N11. Suite output noise.** The telemetry block (`tests/hooks/test-delegation-duty-guard.sh`, the three `(cd "$WORK/repo" && ... 2>/dev/null)` calls) does not redirect stdout, so two hookSpecificOutput JSON lines are printed into the suite log. This is cosmetic. Add `>/dev/null`.

## additionalContext JSON escaping

`finish()` escapes `\` then `"`, turns newline into `\n` and tab into a space, in that order, which is correct. The message is built only from fixed text, the tool name (`Agent|Task|Workflow`), fixed status strings and the fixed element names, so no other control character can appear. Verified: valid JSON in every probe run (the 15 v1.0 probes, plus the 10 new probes under each bash) and 2 x 48 suite cases under bash 5.3.15 and /bin/bash 3.2.57. The replacement strings contain no `&`, so bash 5.2+ `patsub_replacement` does not apply. The longest message (0/8 guidance, about 1.5 KB) is far below the 10,000-character `additionalContext` cap in the hooks reference.

## Rule compliance (re-checked)

- hook-rollout.md: the row now says the output reaches Claude through stdout `additionalContext` and stderr, records that before 2026-10-26 it went to stderr only, and keeps observe. The `.mdc` row matches.
- `registries/tool-ops.json`: the verification cases now expect `hookSpecificOutput.*additionalContext` on stdout.
- Protected edits fall under D-DEL5 review-after. The PR body should list the new old -> new text of the hook-rollout.md / `.mdc` / tool-ops.json rows; I did not re-check the PR body for this commit.
- Portability is unchanged: bash 3.2 OK, no `grep -P`, perl only, fails open.

## What I ran (v1.1)

| Command | Result |
|---|---|
| `bash tests/hooks/test-delegation-duty-guard.sh` | 48 passed, 0 failed (bash 5.3.15); large prompt 43 ms; adversarial 55 ms |
| `env AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-delegation-duty-guard.sh` | 48 passed, 0 failed (bash 3.2.57); 33 ms; adversarial 44 ms |
| `bash .scratch/session-ddgreview/adversarial.sh bash` (v1.0 probes A-J) | B2 and N1 fixed; every stdout is valid JSON |
| `bash .scratch/session-ddgreview/adversarial2.sh bash` and `... /bin/bash` (new probes K-Q) | N8-N10 above; JSON valid, `ctx==stderr` in every run; enforce rc=2 with empty stdout |
| `bash .scratch/session-ddgreview/timing.sh` (main vs PR) | main 699/587 ms vs PR 50/52 ms |
| chrome-devtools, hooks reference "PreToolUse decision control" | `additionalContext` is a PreToolUse field, added alongside the tool result |

CI at `ad72004` when I wrote this: windows and CodeQL passed; linux and macos pending. Not run: Linux and Windows locally, and a live Workflow call.

---

VERDICT (v1.0, head `98324ed`): blocking findings

# S3-DdgHook-Review: independent review of PR #122 (v1.0)

Reviewer: S3-DdgHook-Review (delegated by S3-DdgHook). Reviewed head `98324ed` (worktree `.claude/worktrees/ddghook`, branch `feature/ddg-agent-workflow`). I did not read the author's hand-back or scratch. I treated the PR body's claims as claims and checked them.

Summary: the tests pass, the code is portable and fails open, and the matcher is valid. Two defects stop the hook from doing what the commander asked. (1) Claude never sees the reminder. (2) On every real payload the hook counts the `access` element as present.

## Blocking findings

### B1. Claude never sees the reminder or the guidance (stderr on exit 0)

- **Where:** `shared/hooks/delegation-duty-guard.sh:121` (`printf '%s\n' "$REMINDER" >&2`), `:275` (guidance to stderr), observe path `exit 0` at `:283`.
- **Evidence (Claude Code hooks reference, https://code.claude.com/docs/en/hooks, "Exit code 0", read with chrome-devtools 2026-10-26):** "Claude never sees stderr from a hook that exits 0. To read it yourself on events such as PreToolUse, enable debug logging." The same page, under "Add context for Claude", says text reaches Claude through JSON on stdout: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"..."}}`. For PreToolUse it is inserted "next to the tool result".
- **Transcript evidence:** in `~/.claude/projects/-Users-new-jose-repos-aitools/10cf255a-c378-45d7-83f1-a0baffa7c172.jsonl` the old hook's output is recorded as `"attachment":{"type":"hook_success","hookName":"PreToolUse:Agent",...,"content":"","stdout":"","stderr":"[delegation-guard] Delegation 5/6 duty elements. ..."}`. `content` (what Claude receives) is empty.
- **Repro:** any Agent call with the hook deployed in observe mode.
- **Expected:** the commander asked that the hook "remind to load /delegate skill on ANY agent call ... and ... instruct the delegator to include instructions ...". The reminder has to reach the delegating agent.
- **Actual:** the reminder and the per-element guidance reach only the debug log and the transcript's `stderr` field. They never reach the agent, before or after the call. This was already true of the old hook in observe mode. This PR's purpose depends on it.
- **Suggested fix:** in observe mode (and when nothing is missing), print one JSON object on stdout carrying `hookSpecificOutput.additionalContext` = reminder + guidance, and exit 0. Keep stderr + exit 2 for enforce. Precedent in the repo: `shared/hooks/glossary-skill-guard.sh:35` already emits `additionalContext`. JSON-escape the text in perl, or keep it free of `"` and `\`. Add tests that assert the stdout JSON parses and holds the reminder. Note: for PreToolUse the context arrives with the tool result, so it reaches the agent after the current launch. Record that limit in the header.

### B2. `access` is counted as present on every real payload, so element 7 is never checked

- **Where:** `shared/hooks/delegation-duty-guard.sh:199`. The new alternative `(?<![\w.])(?:\/Users\/|\/home\/|\/root\/|\/tmp\/|~\/)[\w.-]|\b[A-Za-z]:(?:\\\\|\/)[\w.-]` runs against the whole hook payload (`$_ = $text`, where `$text` is all of stdin for Agent and for Workflow with an inline script). Claude Code always sends the common fields `transcript_path`, `cwd` and `scratchpad_dir`, which are absolute paths (hooks reference, "Hook input": example `"transcript_path": "/home/user/.claude/projects/...", "cwd": "/home/user/my-project", "scratchpad_dir": "/tmp/claude-1000/..."`).
- **Repro:** probes A, A3, B and G in `.scratch/session-ddgreview/adversarial.sh`. Each is a real-shape payload with `session_id`, `transcript_path`, `cwd`, `permission_mode` and `hook_event_name`, plus a prompt that contains no path at all:
  - A (macOS fields, prompt has all elements except access): **actual** reminder only (8/8). **Expected** `7/8 ... Missing: access`. The same prompt without the common fields (A2) gives the expected `7/8 ... Missing: access`.
  - A3 (Windows `C:\\...` fields): actual 8/8. Expected 7/8, access missing.
  - B (`"Do the thing."`): actual `1/8`, with access present. Expected 0/8.
  - G (Workflow inline script, real-shape payload): actual 8/8. Expected 7/8.
  - Same result under `/bin/bash` 3.2.
- **Why the suite misses it:** every fixture in `tests/hooks/test-delegation-duty-guard.sh` (`agent_payload`, lines 65-67, and the Workflow payloads) leaves out the common input fields. The access test (line 109) passes for the wrong reason in production.
- **Impact:** the `delegation` telemetry reports access present on 100% of calls. A future promotion to enforce would never block a prompt with no paths. hook-rollout.md "Review" (zero false positives before enforce) cannot detect it, because the error is a false negative.
- **Suggested fix:** check only the prompt text. For Agent, extract `tool_input.prompt`; for Workflow, `tool_input.script` (perl: `/"prompt"\s*:\s*"((?:[^"\\]|\\.)*)"/s`, then unescape). Do not check the whole payload. This also removes the identity false positives in N1. Add real-shape fixtures (all common fields) to the suite, for both a macOS and a Windows `cwd`.

## Non-blocking findings

- **N1. Identity and conflict false positives.** `S[1-9]` under `/i` matches any `s`/`S` followed by a digit. Probe C (`"Upload the build to s3 and fix the merge conflict resolution in main."`) scores identity and conflict as present (2/8). Checking the whole payload also lets the random `tool_use_id` (`toolu_01...`, mixed case) supply `s\d` on a fraction of calls. `conflict\s+resolution` matches ordinary merge-conflict tasks. Suggest: `\bS\d+-\w+` (case-sensitive) or `you are S\d`, and drop the bare `conflict resolution`. The fix for B2 removes the payload-field part.
- **N2. Adversarial timing.** 300 KB of `"name prefix "` with no `.md`: 762 ms (main: 663 ms, so mostly pre-existing). 300 KB of `"name "`: 649 ms (main 565 ms). A 2 MB `scriptPath` file of `"name prefix "`: **4.9 s**. The 2 MB cap is accepted by the new path. The hook never hangs and always exits 0, but the "<50 ms" contract holds only for benign text. Suggest a lower cap (e.g. 512 KB) or prefilters (`index($_, ".md") >= 0 || /markdown/i`) before the windowed regexes.
- **N3. `scriptPath` JSON unescape is partial.** Only `\"`, `\\` and `\/` are decoded. A path with `\u002f` escapes (probe F) falls to "not checked". That is safe (reminder still printed, exit 0), but a `\uXXXX` decode is cheap.
- **N4. Workflow input schema not verified.** The hooks reference lists `Workflow` as a matchable tool name ("built-in tools such as ... Agent, Workflow, ..."). It does not document Workflow's `tool_input` fields. `scriptPath` is a guess guarded to fail open, and the PR body says so.
- **N5. Whole-script limit for Workflow** (one element in any `agent()` counts for all). This is documented in the header and in the guidance text. Acceptable for observe mode.
- **N6. Paths that cannot occur, handled correctly:** a directory, `/dev/zero`, a missing file and the 2 MB cap all give "not checked" with exit 0 (probes H, H2 and the suite). Non-UTF8 bytes (probe E), malformed, truncated and empty input, a 6 MB prompt (1.15 s, exit 0) and an escaped `\"tool_name\"` inside a prompt (probe I) all behave correctly.
- **N7. CI at review time:** `windows` passed, including the step "delegation-duty-guard hook tests (via Git Bash)" (`gh api .../jobs/121996770094`). `macos` and `linux` were still pending.

## Rule compliance

- **hook-rollout.md:** observe kept (`MODE_DUTY="observe"`, line 79). The row is updated and records the change as widening, so it stays observe. Smoke test (Bash payload: silent, exit 0) and violation test (reminder + gaps, exit 0) are in the suite. OK.
- **sources-of-truth.md / D-DEL5:** the protected edits (`.claude/rules/hook-rollout.md`, `.cursor/rules/hook-rollout.mdc`, `registries/tool-ops.json`, `reference/tool-ops-claude-code.md`) are all listed old -> new under "Review after". `shared/skills/aitool-ops/SKILL.md`, `shared/rules/scratch.md` and the hook are not protected. OK. Once B1 is fixed, the hook-rollout row wording "prints missing elements to stderr" needs a matching update.
- **Hook portability (cross-platform.md):** `set -euo pipefail`; no `grep -P`; perl for regex; no `stat` fallback chain; no `mapfile` (`sed -n` parse, bash 3.2 OK); pure-bash tool detection, so the reminder works without perl; fails open on perl failure. OK.
- **Telemetry JSON:** valid (the suite checks it with python3). `missing` and `tool` take values from fixed vocabularies, so nothing needs escaping. OK.
- **Enforce:** exit 2 on a gap and 0 at 8/8 (suite). `none:` and no-perl stay exit 0 in enforce (fail open). Reasonable.
- **CI wiring (`.github/workflows/check.yml`):** macOS bash 5 + `/bin/bash` 3.2, Linux, and Windows Git Bash (the perl-absent case is skipped on Windows and timing is advisory there). The Windows run passed. OK.

## Matcher validity: `Agent|Workflow` is valid

- Hooks reference, "Matcher": a matcher made of "Only letters, digits, _, -, spaces, ,, and |" is an "Exact string, or list of exact strings separated by | or ,". Example: "Edit|Write ... match either tool exactly". `Workflow` is listed among the matchable built-in tool names.
- Manifest precedent: `"Read|Grep"` (glossary-skill-guard) and `"Write|Edit"` (sh-file-fixup) in `shared/hooks/hooks-manifest.json`.
- `scripts/setup-user-hooks.sh:115,275,300-320` and `scripts/setup-user-hooks.ps1:247-271,335-336` pass `matcher` through verbatim and overwrite an existing entry's matcher (`rule.matcher = matcher` / `$rule["matcher"] = $matcherValue`).

## What I ran

| Command | Result |
|---|---|
| `bash tests/hooks/test-delegation-duty-guard.sh` | 39 passed, 0 failed (bash 5.3.15); large prompt 32 ms |
| `env AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/hooks/test-delegation-duty-guard.sh` | 39 passed, 0 failed (bash 3.2.57); 24 ms |
| `bash .scratch/session-ddgreview/adversarial.sh bash` (15 probes A-J) | B2 reproduced (A, A3, B, G); N1-N3, N6 as above |
| `bash .scratch/session-ddgreview/timing.sh` (main vs PR, plus probe A under /bin/bash 3.2) | N2 numbers; B2 reproduced under 3.2 |
| `perl .scratch/session-ddgreview/probe-stderr.pl <transcripts>` | B1 transcript evidence (`hook_success`, `content:""`) |
| chrome-devtools on https://code.claude.com/docs/en/hooks | B1 (exit-0 stderr), matcher syntax, Workflow matchable, common input fields |
| `gh pr view/diff/checks 122`, `gh api .../jobs/121996770094` | head `98324ed`; windows pass, macos/linux pending |

Not run: Linux and Windows locally; a live Workflow call through the deployed hook.

INCIDENT: delegation-duty-guard.sh has reported to stderr with exit 0 in observe mode since 2026-03-24. Per the Claude Code hooks reference, Claude never sees that output, so the observe-mode reminders have never reached a delegating agent. hook-rollout.md describes observe as "prints missing elements to stderr", which implies the agent is reminded. The same pattern should be checked in other observe-mode hooks.
