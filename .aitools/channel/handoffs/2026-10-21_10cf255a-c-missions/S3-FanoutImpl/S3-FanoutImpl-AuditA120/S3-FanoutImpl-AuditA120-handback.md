# S3-FanoutImpl-AuditA120 hand-back (PR #120, static logging audit)

Comment URL: https://github.com/nobul-tech/aitools/pull/120#issuecomment-6432458748

I posted the comment on 2026-10-26, then edited it once with `gh pr comment --edit-last` to fix a line-number typo (`:547-548` became `:2547-2548`). The body below is the corrected version that is live now.

- WRITE_BLOCKED: none. One inline Bash command was refused by the standing-order-guard as too long; I wrote this file with Write instead.
- INCIDENT candidates: finding 1 (the callers do not surface build-deploy warns) and finding 5 (the override table in reference/script-standards-detail.md omits `blog_warn`).

## Comment body as posted

AUDIT (logging, A): FINDINGS

Static logging / script-standards audit of `git diff d7f6855...978e72d` (scripts/build-deploy.sh, tests/deploy-harness-mdm/test-deploy-harness-mdm.sh). 0 blocking, 5 non-blocking. Auditor: S3-FanoutImpl-AuditA120 (static read only; build-deploy not run). Line numbers are the PR head 978e72d.

## Checked and clean

- **Log line format.** Every new message goes through `blog_warn` / `blog_error` / `blog_ok` (build-deploy.sh:43-51): `[<utc>Z] [build-deploy] [warn|error|ok] <msg>`. Warn and error lines go to stderr, with ANSI colour only when stderr is a terminal (:48-50), so deploy.log stays plain. This matches script-standards.md "Standalone build logging" and reference/logging.md section 5.
- **Message content.** The inline warn (:2547-2548), the end-of-build list (:2582) and the near-limit warn (:2555) each name `deploy/<file>`, its size in bytes and the limit.
- **Error handling (brief rules 1-8).** The new code adds no `2>/dev/null`, `|| true` or empty catch. A failed `wc -c` gives `blog_error` and `exit 1` (:2541-2544). A missing deploy-harness.ps1/.sh gives `blog_error` and `exit 1` (:2527-2532). `[ -f ] || continue` (:2535) is a glob no-match guard, not a suppression.
- **End-of-build list.** It runs after the swap and `ls -la` (:2578-2585) and is safe under `set -euo pipefail`: printf is 0, the while loop is 0 and the `if` is 0, so the script exits 0. It is bash 3.2 compatible: a newline-joined string, no arrays, no mapfile.
- **Exit status with only warnings.** 0. This is by design (FX-12 / D3, comment at :2523-2526).
- **Test assertion.** `size_gate_warned` (test:172-188) counts `[warn]` lines that contain the exact inline message. The inline line and the indented list line both contain it, and the header line (:2579) does not, so the count of 2 is correct. The build output is captured with `2>&1` into a file (test:90), so stderr warns are included and carry no ANSI codes. The under-limit branch asserts that no over-limit warn appears.
- `bash -n` passes on both head files.

## Non-blocking findings

1. **The size WARN never reaches the console or summary on the normal `aitools` path.** build-deploy has no WARNINGS counter: `blog_warn` (:50) only prints. The callers send the build output to deploy.log only and report success from the exit code alone:
   - scripts/aitools:2079-2080: `bash .../build-deploy.sh >> "$LOG_FILE" 2>&1` then `log_ok "Rebuilt"`
   - scripts/aitools.ps1:2035-2042: `Add-Content $logFile`, then `LogOk "Rebuilt"`

   An over-limit script shows as an OK `Rebuilt` with no WARN row. The "repeated at the end of the build" list is only visible on a direct `bash scripts/build-deploy.sh`. This is not a direct rule violation: build-deploy is the documented standalone exception, and `write_summary` is a setup-script rule. But it falls short of the intent of reference/logging.md section 7, "the caller logs each returned line at its level -- `warn` with `log_warn` (counted)". The problem predates this PR (every `blog_warn` has it), but FX-12 makes the WARN the only signal left, now that it no longer fails the build.

   Suggested follow-up, outside this PR's files: after the build in scripts/aitools and aitools.ps1, raise each `[warn] ... over the Intune script limit` line from the build output as `log_warn` / `LogWarn` (counted) plus one `write_summary WARN "deploy scripts" "<n> over Intune limit"`.
2. **Test helper, unchecked `wc`** (test:178). `sz=$(wc -c < "$f"); sz=$((sz + 0))`: if `wc` fails, `sz` becomes 0 and the file takes the under-limit branch, so the case passes vacuously. Suggest `sz=$(wc -c < "$f") || return 1`.
3. **The test has no over-limit fixture.** The over-limit branch (test:180-181) runs only if the real build happens to produce an oversized script. The frozen aitools `deploy/` at this head has `setup-user-hooks.ps1` 206305 bytes and `setup-user-skills.ps1` 228149 bytes (`git ls-tree -l 978e72d deploy/`), so the branch is probably exercised. Whether the fixture dotprofile build produces the same sizes is unknown. The test also does not assert the header line (:2579). Suggest asserting that at least one file took the over-limit branch, or adding a small forced-limit case.
4. **Asymmetric and less specific messages.**
   - The near-limit (95%) warn and the OK size line apply only to `deploy-harness.*` (:2552-2560). Other generated scripts get no line unless they are over the limit.
   - The over-limit message dropped the base's remediation hint `-- move content to deploy-harness.payload` (base build-deploy.sh, removed line). That hint still applies to `deploy-harness.*`.

   Suggest keeping the hint for `deploy-harness.*`, and naming FX-35 (the deferred deduplication) for the others.
5. **Documentation drift (predates this PR, outside the diff).** The override table at reference/script-standards-detail.md:166 lists build-deploy's functions as `blog`, `blog_ok`, `blog_error`. It omits `blog_warn`, which is defined at build-deploy.sh:50 and is the function this PR relies on. That file is protected, so this is a follow-up for review, not for this PR.

Note, outside the diff: build-deploy.sh:2511 `chmod +x ... 2>/dev/null || true` has no comment and no result check. It predates this PR and is unchanged by it.
