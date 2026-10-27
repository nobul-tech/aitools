VERDICT: blocking findings

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
