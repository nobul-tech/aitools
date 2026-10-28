# S3-FanoutImpl-AuditB120 hand-back (AUDIT-120-B, 2026-10-26)

Posted: https://github.com/nobul-tech/aitools/pull/120#issuecomment-6432515541
Worktree: /Users/new-jose/repos/aitools/.claude/worktrees/fo-aud120b (detached at 978e72d; kept).
Scratch (logs, case scripts): /Users/new-jose/repos/aitools/.claude/worktrees/fo-aud120b/.scratch/session-a120b/
(suite.log, case-oversize.sh, case-bash32.sh, case/build.{stdout,stderr,tty,rc}.log, case/build32.*.log).

Comment body as posted:

---

AUDIT (logging, B): FINDINGS -- all non-blocking; no blocking finding

Runtime logging / script-standards audit of `scripts/build-deploy.sh` and `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` at PR head `978e72d` (diff `d7f6855...978e72d`). Auditor: S3-FanoutImpl-AuditB120 (runtime; independent of auditor A). Line numbers are PR-head lines.

## What was run (macOS, isolated HOME only)

| # | Command | Exit |
|---|---------|------|
| 1 | `KEEP_TMP=1 bash tests/deploy-harness-mdm/test-deploy-harness-mdm.sh` (suite's own isolated HOME + fixture dotprofile; bash 5.3.15) | 0 (64 PASS, 0 FAIL; `PASS size gate: a generated script over its Intune limit is a WARN, not a build failure (FX-12)`) |
| 2 | Oversize case: local clone of the PR head + a ~1.1 MB fixture skill `shared/skills/zz-big/SKILL.md` (committed in the clone), fixture dotprofile git repo, `HOME=<scratch>/case/home`, `env -u AITOOLS_USER_REPO_PATH bash <clone>/scripts/build-deploy.sh > stdout.log 2> stderr.log` | 0 |
| 3 | Same build under a pseudo-terminal: `script -q build.tty.log bash <clone>/scripts/build-deploy.sh` | 0 |
| 4 | Same build under `/bin/bash` 3.2.57 | 0 (17 matching warn lines, same as run 2) |
| 5 | `/bin/bash -n` on both files | 0 |

Observed warn lines, run 2, stderr (verbatim, excerpt):

```text
[2026-10-27T02:47:36Z] [build-deploy] [warn] deploy/deploy-harness.ps1 is 202519 bytes, over the Intune script limit (200000)
[2026-10-27T02:47:36Z] [build-deploy] [warn] deploy/setup-user-skills.ps1 is 1502755 bytes, over the Intune script limit (200000)
[2026-10-27T02:47:36Z] [build-deploy] [warn] deploy/setup-user-skills.sh is 1467395 bytes, over the Intune script limit (1000000)
[2026-10-27T02:47:36Z] [build-deploy] [warn] Generated scripts over the Intune script limits (WARN only, the build does not fail):
[2026-10-27T02:47:36Z] [build-deploy] [warn]   deploy/aitools-profile.ps1 is 244457 bytes, over the Intune script limit (200000)
[2026-10-27T02:47:36Z] [build-deploy] [warn]   deploy/deploy-harness.ps1 is 202519 bytes, over the Intune script limit (200000)
...
[2026-10-27T02:47:36Z] [build-deploy] [warn]   deploy/setup-user-skills.sh is 1467395 bytes, over the Intune script limit (1000000)
```

stdout (run 2): `[...] [build-deploy] [ok] deploy/deploy-harness.sh: 188534 bytes (Intune limit 1000000)`, then `[ok] Build complete: 50 scripts generated in deploy/`, then `[info] Scripts are self-contained and ready for MDM deployment`. The suite fixture (run 1) gives the same 7 `.ps1` warnings without the `.sh` one.

## Conforms (checked at runtime)

- Format `[<UTC>Z] [build-deploy] [warn] <msg>` on every new line (`blog_warn`, build-deploy.sh:50); warn/error on stderr, info/ok on stdout.
- ANSI colour only when stderr is a terminal: 0 escape sequences in the non-tty logs (runs 2, 4); `ESC[33m ... ESC[0m` on every warn line under the pty (run 3). So the deploy.log that `aitools` appends to stays plain text.
- Each message names the file, its byte size (measured after the CRLF conversion) and the limit. Each over-limit file appears twice: inline, then in the end-of-build list (the suite's `size_gate_warned` checks this count).
- `wc` failure is handled: `if ! _sz=$(wc -c < "$_sz_f"); then blog_error ...; exit 1` (build-deploy.sh:2541-2544). A missing deploy-harness.{ps1,sh} is a `blog_error` + exit 1 (2527-2532). The diff adds no `2>/dev/null` and no `|| true`; `[ -f "$_sz_f" ] || continue` (2535) only guards an empty glob.
- Bash 3.2: the build runs the same under `/bin/bash` 3.2.57 (run 4).

## Findings (all non-blocking)

1. **N1 -- the WARN is not counted, and `aitools` users do not see it.** build-deploy keeps no warning counter (a size warning is held only in `SIZE_WARNINGS`, 2533) and exits 0 when only size warnings fire. That is what FX-12 intends. But its callers send all of its output to the log: `scripts/aitools:2079` (`>> "$LOG_FILE" 2>&1`, then `log_ok "Rebuilt"`) and `scripts/aitools.ps1:2035-2042` (`2>&1 | Out-String` -> `Add-Content`, then `LogOk "Rebuilt"`). The end-of-build list therefore reaches only deploy.log. The console shows OK `Rebuilt`, with no WARN row and no counted warning. Suggested follow-up (outside this diff): have the callers count `[build-deploy] [warn] ... over the Intune script limit` lines and emit one `log_warn` / `write_summary WARN "deploy scripts" "<n> over Intune limit"`, or have build-deploy print a machine-readable count line.
2. **N2 -- contradictory info line.** build-deploy.sh:2577 `blog "Scripts are self-contained and ready for MDM deployment"` prints just before the list of scripts that are over the MDM limits (2578-2585). Suggest wording it conditionally when `SIZE_WARNINGS` is non-empty (e.g. "... ready for MDM deployment except the scripts listed below").
3. **N3 -- deploy-harness.ps1 is now over its limit and only warned.** In both fixture builds `deploy/deploy-harness.ps1` is 202519 bytes. At base d7f6855 the same condition was `blog_error` + `exit 1`. Under this PR it is a WARN and exit 0. I take this to be intended (FX-12, D3), but the merge orchestrator should know that the one script the old gate protected is over the gate on this branch.
4. **N4 -- branch coverage in the suite.** The suite fixture has no `.sh` over 1 MB and no deploy-harness.* within 5%, so the `.sh` limit (2539) and the within-5% branch (2554-2555) are not run by the suite. I ran the `.sh` path by hand (run 2: `setup-user-skills.sh is 1467395 bytes`). The within-5% branch was not run (unknown at runtime; it reads correctly). The test header is stale too: test-deploy-harness-mdm.sh:14 still says "scripts under the Intune size limits".
5. **N5 -- unguarded `wc` in the test helper.** test-deploy-harness-mdm.sh:178 `sz=$(wc -c < "$f"); sz=$((sz + 0))`: a `wc` failure gives `sz=0`, the file is treated as under its limit, and the check can pass without measuring it. This is test code, so the impact is low.
6. **N6 -- the remedy was dropped from the message.** The old over-limit error said "-- move content to deploy-harness.payload". The new WARN (2547) does not say what to do. Optional: name FX-35 (dedupe the inlined lib) or the payload.
7. **N7 -- pre-existing doc drift (not this PR).** reference/script-standards-detail.md "Logging overrides" lists build-deploy's helpers as `blog`, `blog_ok`, `blog_error`. `blog_warn` is missing, although it is already used 15 times at base d7f6855.

Not run: post-push checks, the PowerShell side (build-deploy has no .ps1), Windows/Git Bash.
