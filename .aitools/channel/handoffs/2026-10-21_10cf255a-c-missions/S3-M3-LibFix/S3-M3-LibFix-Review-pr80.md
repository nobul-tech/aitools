# S3-M3-LibFix-Review: PR #80 review at dae07fe

1. **Verdict: request changes**, posted as a comment, because GitHub refuses request-changes from the PR author's account. 0 blockers, 2 majors, 4 minors, 1 nit.
2. **Review:** https://github.com/nobul-tech/aitools/pull/80#pullrequestreview-5620940373 (commit dae07fe).
3. **M1:** the wrappers trust the resolver's exit code without its tagged output. A crash or a pwsh failure therefore reads as "found, empty path" (rc 0) or as shared-only mode (rc 1). The bash Git Bash branch and PowerShell disagree on the same failure.
4. **M2:** the AITLIB_* renames contradict the approved tree rev 5 (PR #78: `TOOL_EXC_*`, `MACHINE_ALIAS` / `MACHINE_VIA`, and the "prints" row), and the PR has no protected-file draft for the tree.
5. **Confirmed fixed:** B1 and M1 in both shells (end to end and by probe), plus Review3 m1, m3 and m4. All suites pass.

## Method
- **Read in full:**
  - the mission packet;
  - the user rules: CLAUDE.md, concurrent-agents.md, delegation.md;
  - the project CLAUDE.md and all 26 `.claude/rules/*.md`;
  - the references: script-standards-detail, cross-platform-detail, logging, managed-file-deployment, plan-execution-detail;
  - plans/tool-support-and-machine-profile.md;
  - the S3-M3Lead plan;
  - Review3, section "PR #80".
- **Did not read** S3-M3-LibFix-report.md (independence).
- **Also read:**
  - tree rev 5, sections 7 and 8, from `origin/docs/m2-tree-user-repo`;
  - the resolver's output and exit contract (`aitools-profile.sh` / `.ps1`).
- **Code:** `git archive dae07fe` was extracted to `.scratch/session-LFReview/snap`, and `18218ce` to `snap-old`. Everything ran from the snapshots, never from the worktree.
- **Environment:**
  - Every run used an isolated HOME under `.scratch/session-LFReview/`.
  - The resolver ran only with `AITOOLS_PROFILE_TEST_MACHINE_ID` / `AITOOLS_PROFILE_TEST_HOSTNAME` / `AITOOLS_PROFILE_TEST_ANY_OS=1`.
  - The real HOME and the live dotprofile were not touched.

## Commands and results (scripts in `/Users/new-jose/repos/aitools/.claude/worktrees/m3wrap/.scratch/session-LFReview/`)
| Script | Purpose | Result |
|---|---|---|
| `run-suites.sh` | test-lib (bash 5 + pwsh; 3.2 `--bash-only`; 3.2 + pwsh), test-config, test-profile (each also under 3.2), tests/logging, tests/managed-files, `bash -n` (3.2 and 5), pwsh parser | test-lib 72/0, 32/0, 72/0; test-config 89/0 (3.2: 55/0); test-profile 319/0 (3.2: 231/0); logging sh 24/0, ps 15/0 (5 skipped); managed-files sh 42/0, ps 24/0; syntax clean. Logs in `suites/` |
| `negctl.sh` | dae07fe test-lib against the 18218ce libs | 32 passed, 40 failed. caller-vars-survive fails in both shells. The bash failure is the driver aborting on an unbound `AITLIB_*` name, not detected clobbering (m4c) |
| `probe-clobber.sh` | caller names vs the old and new libs | old: every caller value overwritten in both shells. New: all kept |
| `probe-urp.sh` | Review3 B1 repro (copied), setup-user-config with `-UserRepoPath` different from config.json | both shells write the argument path, `via=argument` |
| `audit-names.pl` | names the section assigns and defines | bash: only `AITLIB_*` globals. PS: only `$script:AitLib*` plus `$global:LASTEXITCODE`, and no top-level statement |
| `probe-args.sh` | forced bash → pwsh branch and PS in-process, with an echo stub | empty args (middle, end, only), regex / pipe / `$` values, `-Verbose`, `--path` as a value, spaces, non-ASCII: all intact |
| `probe-action.sh` | ACTION dedupe edge cases; `set -u` | 6 unique rows from 9 calls, identical bytes in both shells, a relative summary path works. A missing slug aborts under `set -u` (nit) |
| `probe-usage.sh` | record with an empty path (resolver usage error) | rc 1, result "" in both shells. ACTION "run aitools user init". PS prints the resolver's raw stderr line on the console (m1, m2) |
| `probe-pwshfail.sh` | pwsh cannot run the resolver (`throw` / parse error) | bash forced branch: throw → urp, rmp and eget read as "no dotprofile", with no rows. Parse error → urp rc 0 with an empty path. PS in-process: rc 3 + ERROR rows (M1) |
| `probe-notags.sh` | resolver exits 0 or 1 with no output | both shells: exit 0 → urp rc 0 with an empty path, and eset WARN "saved but not pushed" + ACTION. Exit 1 → silent shared-only mode (M1) |
| `gh pr checks 80`, `gh run view ... --job 120084981606` | CI | linux test-lib 72/0 (pwsh: true). macOS pending at review time. The windows job does not run test-lib |

## Posted review (verbatim)

## S3-M3-LibFix-Review: independent review of PR #80 at dae07fe

> Posted as a comment. GitHub refused `--request-changes`: "Can not request changes on your own pull request" (the reviewer uses the PR author's account). Read this as **request changes**.

**Verdict: changes requested.** 0 blockers, 2 majors, 4 minors, 1 nit.

The Review3 fixes hold. B1 and M1 are fixed in both shells, end to end. m1, m3 and m4 are fixed. The m2 argument path works on macOS for every edge case I tried. All suites pass. Two things still need work:
- **M1:** the wrappers trust the resolver's exit code even when the resolver printed nothing. A crashed resolver therefore reads as "found" with an empty path, or as "no dotprofile". In the Git Bash → pwsh branch, pwsh's own failures produce exactly those exit codes.
- **M2:** the renamed result names contradict the approved decision tree (rev 5, PR #78), and the PR offers no protected-file draft for the tree.

Code reviewed: 18218ce + dae07fe. I read them from a `git archive dae07fe` snapshot and ran everything from it under an isolated HOME. The resolver ran only with the `AITOOLS_PROFILE_TEST_*` overrides.

---

### Majors

**M1. Exit codes are trusted without the resolver's tagged output, so a resolver failure reads as success or as shared-only mode.**

The real resolver always emits a `via` tag (`user-repo-path`, `resolve`, `exception-get`) or a `result` tag (`exception-set`) before it exits through `finish`. The wrappers never check that the tag is there. They act on the exit code alone:

| Wrapper | bash | PowerShell |
|---|---|---|
| user-repo-path | `aitools-lib.sh:249-256` | `aitools-lib.ps1:181-186` |
| machine profile | `aitools-lib.sh:294-296` | `aitools-lib.ps1:222-223` |
| exception get | `aitools-lib.sh:322` | `aitools-lib.ps1:244` |
| exception record | `aitools-lib.sh:365-382` | `aitools-lib.ps1:288-302` |

Under `set -euo pipefail`, the resolver dies with the failing command's status, usually 1, before it prints anything. Exit 1 is also its "nothing found" code.

`probe-notags.sh` uses a resolver stub that writes to stderr and exits with no tagged output. Results were identical in both shells:

```
exit 0, no output: urp rc=0 path=[] via=[]               <- "found", empty dotprofile path
                   eset rc=0 result=[]  + WARN "saved but not pushed" + ACTION "run git push in your dotprofile"
exit 1, no output: urp rc=1 path=[] via=[]               <- shared-only mode, no ERROR, no row
```

The Git Bash branch (`aitools-lib.sh:175`) makes this likely. The `-Command` line is `...; & $env:AITLIB_PS1 @a; exit $LASTEXITCODE`:
- A statement-terminating error (a parse error, and I expect also an ExecutionPolicy refusal) does not stop the sequence. `$LASTEXITCODE` is then `$null`, so pwsh exits 0.
- A `throw` exits 1.

`probe-pwshfail.sh` (forced branch, `AITLIB_PROFILE_VIA_PWSH=1`):

```
parse.ps1  -- bash: urp rc=0 path=[] via=[]   eget rc=0   (no error for urp)
              ps in-process: urp rc=3 + ERROR|dotprofile|resolver failed
throws.ps1 -- bash: urp rc=1, rmp rc=1, eget "unavailable (no dotprofile)", rows: none
              ps in-process: rc=3 + ERROR rows + ACTION
```

So the bash and PowerShell libs give opposite answers to the same failure, and the bash answer is silent. This breaks script-standards "Error handling requirements" (no suppressed failure feeding conditional logic) and the Contract's "ERROR rows ... are written on every failing call". The first real consumer is B8c's check-lib.sh, which runs under Git Bash on Windows.

Suggested fix, in both libs:
- Honour rc 0 or 1 only when the expected tag is present: `via`, or `result` for exception-set. Otherwise treat it as a resolver failure: rc 3 with ERROR, "unavailable", or `failed`.
- In the pwsh `-Command`, set `$ErrorActionPreference = 'Stop'`, wrap the call in `try { & ...; exit $LASTEXITCODE } catch { [Console]::Error.WriteLine($_); exit 2 }`, and map a `$null` `$LASTEXITCODE` to 2.
- Add test-lib cases for "stub exits 0 / 1 with no output" and "forced pwsh, the script fails to parse".

**M2. The Contract renames contradict the approved decision tree rev 5, with no protected-file draft.**

`reference/tool-support-decision-tree.md` on `docs/m2-tree-user-repo` (PR #78, approved as R1/REV5) still uses the old names:
- **Lines 309-310:** `TOOL_EXC_PLATFORM` / `TOOL_EXC_METHOD` / `TOOL_EXC_PATH` / `TOOL_EXC_DECIDED_AT` (`tool_exception_get`).
- **Lines 567 and 618:** `MACHINE_ALIAS` / `MACHINE_VIA`.
- **Line 399:** says `tool_exception_get` "prints `<platform>|<method>|<path>|<decidedAt>` or nothing". This contradicts the tree's own globals rule at lines 300-305 and this PR.

The PR body says "`TOOL_EXC_*` moved to `AITLIB_TOOL_EXC_*`, so the rule has no exception". But its "Protected-file drafts awaiting approval" section lists only the lib intent.

M2 implementers build from the tree. A `$TOOL_EXC_METHOD` read under `set -u` is an unbound-variable abort at T5, which leaves no summary row.

Suggested fix: add a tree draft (section 7 globals list, the section 7.2 row, the section 8 `MACHINE_*` names) to the PR's protected-file section, and tell the M2 lead. This is a doc fix, not a code fix.

### Minors

**m1. `AITLIB_TOOL_EXC_RESULT` is "" on more paths than the Contract says, and the ACTION is wrong for those paths.**
- The Contract says "" means only "resolver missing".
- A resolver usage error (e.g. an empty path) or a crash also leaves it "", with rc 1 (`probe-usage.sh`: `bash rc=1 result=[]`, `ps rc=1 result=[]`).
- Those failures get ACTION "run aitools user init to remember tool choices" (`aitools-lib.sh:389-391`, `.ps1:311-313`), which user init cannot fix.
- Suggest: set `failed` when rc is not 0 or 3, and use a neutral ACTION for rc 2 ("see deploy.log"), or none.

**m2. PowerShell parity: the in-process resolver's raw stderr reaches the console unstructured and never reaches deploy.log.**
- bash copies the resolver's stderr into deploy.log as detail lines (`aitools-lib.sh:185-191`).
- `Invoke-AitLibProfile` (`aitools-lib.ps1:128`) lets `[Console]::Error.WriteLine` lines through. `probe-usage.sh` shows `aitools-profile: exception-set needs --slug, ... (see --help)` printed bare on the console, and deploy.log has no copy.
- This breaks the log-line format rule. Suggest capturing the error stream, or documenting the difference.

**m3. The Git Bash branch deviates from the dispatch pattern.**
- pwsh runs without `-ExecutionPolicy Bypass`. The cross-platform.md "OS guard + dispatch rule" prescribes `pwsh -NoProfile -ExecutionPolicy Bypass -File ...`. `-Command` is needed here for the UTF-8 setup, but `-ExecutionPolicy Bypass` can still be added.
- `cygpath -w` results are unchecked (`aitools-lib.sh:164`, `:167`), while dae07fe added the check for `cygpath -u` (`:218`). An empty `ps1_arg` then feeds M1.
- Windows itself remains UNVERIFIED.

**m4. Test gaps.**
- (a) **No found-exception case.** `AITLIB_TOOL_EXC_FOUND=true` and the PLATFORM/METHOD/PATH/DECIDED_AT values (PS: `.Found`, `.Method`, ...) are never asserted, in either shell. That is the reader's main job.
- (b) **No resolver-error case.** Nothing covers resolver rc 2 (urp/rmp ERROR "resolver failed", record rc 1).
- (c) **The bash half of the negative control proves less than it seems.** It fails on unbound `AITLIB_*` names, not on clobbering. The driver aborts under `set -u`; the log shows an empty "got".
  - My `probe-clobber.sh` does show the old lib clobbering 9 caller globals and the new one keeping them.
  - So the fix is real; only the test's evidence for it is weak.
- (d) **The Windows CI job does not run test-lib.** Running it there under Git Bash would turn the UNVERIFIED m2 branch into a tested one.

### Nit
- **`set -u` and missing arguments.** `tool_exception_get` or `tool_exception_record` called with missing arguments aborts the caller with `$1: unbound variable` (`aitools-lib.sh:316`, `:354`).
- **Global `LASTEXITCODE`.** `$global:LASTEXITCODE = 0` (`aitools-lib.ps1:126`) changes the caller's global.

### Checked and fine
- **B1.** Review3 `probe-urp.sh`, re-run on dae07fe: both shells write the argument's `userRepoPath` (`via=argument`).
- **Caller names survive (M1).** `probe-clobber.sh`, caller names kept across sourcing and all wrapper calls:
  - bash: `USER_REPO_PATH`, `PROFILE_FILE`, `PROFILE_NAME`, `PROFILE_COMPANY`, `IDENTITY_GIT_*`, `MACHINE_ALIAS`, `MACHINE_VIA`, `TOOL_EXC_FOUND`;
  - PowerShell: `-UserRepoPath`, `-MachineAlias`, `$profileFile`, `$profileName`, `$profileCompany`, `$machineVia`, `$identityGitName`;
  - the 18218ce libs clobber all of these.
- **Names.** A name audit (`audit-names.pl`) finds:
  - no PowerShell top-level statement in the section;
  - no unprefixed bash global (the `AITLIB_PS1` / `AITLIB_PS_ARGS` env prefixes are command-scoped);
  - only `$script:AitLib*` assignments in PowerShell, plus `$global:LASTEXITCODE`.
- **m1 (Review3):** unchanged and dry-run give no warning and no ACTION.
- **m3 (Review3):** `_aitlib_action_once` / `Write-AitLibActionOnce` dedupe exact lines. Tested with `|`, `.*[y]$` against `.*[y]`, `-n`, a leading space and a relative `AITOOLS_SUMMARY_FILE`. The bash and PS summary files are byte-identical.
- **m4 (Review3):** `mktemp` is checked.
- **m2 args (macOS, forced branch and in-process).** `probe-args.sh` checked:
  - an empty argument in the middle, at the end, and as the only argument;
  - values with `| .* [x] $HOME`, `-Verbose`, `--path` as a value, double spaces and `José ü`.

  All arrive intact.
- **Contract against code.** Names, return codes, the PS return object and the once-per-run ACTION match, apart from m1 and M1.

### Runs (macOS, isolated HOME)
- **test-lib:** 72/0, and 72/0 with `/bin/bash` 3.2 + pwsh. With `--bash-only` under 3.2: 32/0.
- **test-config:** 89/0 (3.2: 55/0).
- **test-profile:** 319/0 (3.2: 231/0).
- **tests/logging:** sh 24/0, ps 15/0 (5 skipped).
- **tests/managed-files:** sh 42/0, ps 24/0.
- **Syntax:** `bash -n` (3.2 and 5) and the pwsh parser are clean.
- **CI linux:** test-lib 72/0 with pwsh: true.

### Not run
- Windows / Git Bash, so ExecutionPolicy behaviour is inferred from the parse-error probe.
- check-pre-commit / check-pre-push (not needed for a review).
- Callers (none switched yet).

The lib-section intent text awaits Jose's approval (protected). This review takes no position on it.

Probes and logs: `.claude/worktrees/m3wrap/.scratch/session-LFReview/` (`probe-*.sh`, `audit-names.pl`, `suites/`).

🤖 Generated with [Claude Code](https://claude.com/claude-code)

## WRITE_BLOCKED
- None. GitHub refused `gh pr review --request-changes` with "Review Can not request changes on your own pull request (addPullRequestReview)". As the mission prompt instructs, the review was posted with `--comment` and the body says so at the top.

## INCIDENT markers (not filed)
- `INCIDENT:` Two rules in `.claude/rules/cross-platform.md` can be read against each other:
  - "Cross-language script calls require explicit approval" (approved table: only `build-deploy.sh`);
  - "OS guard + dispatch rule" (a `.sh` calls the `.ps1` on Windows through `pwsh -NoProfile -ExecutionPolicy Bypass -File`).

  The aitools-lib.sh Git Bash branch calls aitools-profile.ps1. It is not in the approved table, and it does not use the dispatch rule's form. The rule does not say which of the two governs a library calling its own counterpart.
- `INCIDENT:` `reference/tool-support-decision-tree.md` rev 5 (PR #78) contradicts itself:
  - the section 7.2 row `tool_exception_get` says it "prints `<platform>|<method>|<path>|<decidedAt>` or nothing";
  - lines 300-305 say helpers return results in globals.

  It also still names the pre-#80 globals (`TOOL_EXC_*`, `MACHINE_ALIAS` / `MACHINE_VIA`). This is M2.
- `INCIDENT:` No harness rule says a wrapper must validate a child resolver's output before trusting its exit code. The resolver's "not found" exit code (1) is the same as `set -e` death and pwsh's own failure code. This is M1. Suggested home: script-standards-detail.md "External command error handling".

## Open questions (with suggested answers)
- **Q1. Is M2 a code or a doc fix?** Suggest doc: keep the `AITLIB_*` names (they are what fixed B1/M1) and put a tree draft in this PR's "Protected-file drafts" section for Jose's approval. Tell the M2 lead before M2 B2/B3 code the old names.
- **Q2. Should the Git Bash branch be verified rather than left UNVERIFIED?** Suggest yes: add `bash tests/profile/test-lib.sh` to the windows CI job (Git Bash is on the runner). That covers cygpath, MSYS env/argument conversion and the code page for free.
- **Q3. Which code should rc 2 resolver failures in `tool_exception_record` give?** Suggest `AITLIB_TOOL_EXC_RESULT=failed`, rc 1, and an ACTION that points to deploy.log instead of "run aitools user init".

## Delegates used
None.
