**Verdict: changes requested** (1 major, 4 minor, 4 nits; no blocking finding)

# S3-MF-Relay-ReviewB: independent review of PR #116 (installers and user init on the lib relay)

Reviewer: S3-MF-Relay-ReviewB, an independent reviewer delegated by S3-MF-Relay. I wrote none of this code and did not read the other reviewer's output.
Reviewed: `origin/fix/mf-lib-relay..origin/fix/mf-installer-relay` at ccccbd8 (1e44578, 27a3b15 merge, 7a16400, ccccbd8), in a detached worktree. The yardstick was the S3-MF-Audit findings (sections 4, 5 and 8 I-1), the mission packet, the rules it lists, and the lib relay contract (aitools-lib.sh:500-721 / aitools-lib.ps1:417-605).

## Summary

The change does what the audit asks, and it does it well in most places:

- **A-1:** the installers have no private relay left. The Step 5 rows follow #115's rule.
- **A-16:** fixed. The first failed write sets the flag before the warning, so there is no recursion. A lib-only negative control fails exactly the four jsonl-blocked assertions.
- **A-17:** fixed. Step 3 has one row per failure, Step 5 is skipped, and the PS `New-Item` silent failure is caught.
- **A-12, A-13, A-14:** fixed.
- bash 3.2 is clean.
- I found no `set -u`/`-e` hazards.

The approved behaviour is untouched: decision 2, item 5, item 6, and the config writer contract. The writer arguments `--machine-id` / `--no-machine` are unchanged, and the relay adds no ACTION.

I request changes for one reason (M-1). Relaying `pwsh -File setup-user-hooks.ps1` from bash user init on Git Bash moves that child's stdout into a pipe. PowerShell writes its review prompts to stdout with `[Console]::Write` and no newline, so the relay holds the prompt until the user has already answered. I reproduced this under a pty. The PR's own I-1 reasoning (relaying moves stdout off the terminal) names this hazard, but this PR applies the relay to the one interactive child it touches.

There is also a factual error in the A-15 PS rationale (m-1).

## Findings

### M-1 (major): Git Bash user init hides the hooks review prompt
- **Where:** scripts/aitools:1021-1023 and 1032 (`hook_cmd=(pwsh ... -File setup-user-hooks.ps1)` run through `run_child_relayed`).
- **Mechanism:** `run_child_relayed` reads the child's stdout line by line (aitools-lib.sh:699-701).
  - The PS review menu writes its prompt with `[Console]::Write("  choice [o/a/m/s/x]: ")` (aitools-lib.ps1:1891, 1893, also 1559, 1594, 2558-2562), and the user-hook adoption prompt does the same with `[Console]::Write("  > ")` (setup-user-hooks.ps1:192). In a `pwsh -File` child, `[Console]` output goes to process stdout, which is now the pipe.
  - `Test-InteractiveConsole` checks only stdin (aitools-lib.ps1:1498-1499), so the menu still runs interactively, but its last line has no newline and stays in the relay's `read` until the user presses Enter.
- **Evidence:** a pty probe (scratch `probe-prompt.py` with `probe-prompt-driver.sh` and `probe-prompt-child.ps1`). The child writes one Write-Host log line, a `[Console]::WriteLine` menu line and a `[Console]::Write` prompt, then calls ReadLine.
  - `direct ps`: prompt visible before answering: True.
  - `relay ps`: prompt visible before answering: **False**. The prompt appears after answering, glued to the next log line: `choice [o/s/x]: [..] [info] got 'o'`.
  - The AI-merge spinner (`[Console]::Write("`r ...")`, aitools-lib.ps1:1473) is also held.
- **Scope:** Windows Git Bash only, which is a first-class platform and on the path the PR names ("Git Bash on Windows relays `pwsh -File`"). PS user init runs the child in-process (`6>&1` captures only Write-Host, and `[Console]` still reaches the console), so it is not affected. The bash child writes its prompts to /dev/tty, so it is not affected either (see n-1).
- **Suggested fix** (pick one):
  - (a) On MINGW, when the run is interactive (`tty_interactive` and not `--force`), run the hooks child unrelayed as before. Record this exception next to the call; its lines then miss deploy.jsonl, which the I-1 assumption already allows for interactive output.
  - (b) Have the relay pass partial lines through, for example by printing a pending fragment when `read -t` times out (watch bash 3.2).
  - (c) Write the PS menu prompts to the console handle instead of stdout. This is wider: every PS menu.
  - Either way, add a pty case to test-user-init, which already drives pty menus, for the relayed `pwsh -File` hooks child.

### m-1 (minor): the A-15 PS premise is wrong, and the new PS check is nearly dead code
- **Where:** aitools.ps1:505-511 (new) and the PR body's A-15 section.
- **The claim:** "pwsh binds the next word, so `--alias --force` arrives as the value `--force`."
  - The aitools.ps1 param block declares `[switch]$Force` (aitools.ps1:13).
  - The author's probe (`mf-relay-b/.scratch/session-mfrelayb/probe-alias.ps1`) lacks `$Force`, so `--force` had nothing to bind to.
- **My probe** (`probe-alias.ps1`, the real param block, pwsh 7.6.3):
  - `pwsh -File ... user init --alias --force` gives `Missing an argument for parameter 'Alias'` and exit 1 before the script runs. The new check never sees it.
  - It catches only values like `-x` or `-`, which bind (`Alias=[-x]`).
- **The installed entry path** is the profile function `function aitools { & "$HOME\.local\bin\aitools.ps1" @args }` (aitools-install.ps1:526). Through it, `--alias` is never bound to `-Alias` at all (`probe-alias-func.ps1`):
  - `aitools user init --alias spare` gives `Alias=[] Remaining=[init,--alias,spare]`.
  - user init ignores `$subArgs` (aitools.ps1:404-413), so the alias is silently dropped.
  - This predates the PR: the comment at aitools.ps1:398-400 says "under pwsh -File".
- **Suggested fix:** correct the comment and the PR text. Fold the follow-up the PR already lists (parse `-Alias` from `$Remaining`) into "parse `--alias` from `$Remaining` on the in-process path".
- `INCIDENT:` `aitools user init --alias <name>` through the installed PowerShell profile function never sets the alias (`--alias` lands in `$Remaining`, and user init ignores it). P-Q12's "register without a prompt" does not work there. Pre-existing; not filed.

### m-2 (minor): the PS installer leaks `$env:AITOOLS_RUN_ID` into the caller's session
- **Where:** aitools-install.ps1:55-57. It sets the variable when unset and never removes it.
- **Effect:** the installer's documented usage is `.\scripts\aitools-install.ps1` (its `-Help` text), which runs in-process in the user's pwsh. After a standalone run the variable stays set, and a second run in the same session reuses the first run's id. Probe `probe-envleak.ps1`: `child run id: 2ba742bc9be4` / `session after run 1: [2ba742bc9be4]` / `child run id: 2ba742bc9be4`.
- **For comparison:** aitools.ps1 removes the id it set (aitools.ps1:2209). Via `aitools` sync the parent's id is set and later removed, so only the standalone path is affected. The bash export happens in a child process and does not leak.
- **Suggested fix:** remember whether the installer set it (`$runIdSet = $true`) and `Remove-Item Env:\AITOOLS_RUN_ID` at the exit footer when it did. Note that the standalone path already leaks `AITOOLS_SUMMARY_FILE` / `AITOOLS_DRY_RUN` the same way.

### m-3 (minor): the warning message differs between the shells
- **Where:** aitools-lib.sh:587 / aitools-lib.ps1:497-498.
- **Message:** bash prints `cannot write $(display_path "$f")` (`~/.aitools/logs/deploy.jsonl`); PS prints the full path. cross-platform.md wants the same messages.
- **Reason:** PS also logs the OS reason as a detail line. bash discards it with `2>/dev/null`, so deploy.log on macOS cannot say why the write failed.
- **Suggested fix:** use the same path form in both; in bash, add a detail line with what is cheaply known: `[ -d "$f" ]` gives "is a directory", `[ -w ]` gives "not writable".

### m-4 (minor): test gaps for new behaviour
- **Step 5 skip:** the branch after a Step 3 failure (aitools-install.sh:502-503 / .ps1 Step 5) is in the installer body, not the extracted blocks, so no test proves Step 5 is skipped. A grep-level assertion on the installer text, or moving the guard into the helpers block, would cover it.
- **PS A-15** (aitools.ps1:508) has no case. See m-1: as written, a test would show it does not catch `--alias --force`.
- **Run id:** the `AITOOLS_RUN_ID` export (install.sh:128-134 / ps1:55-57) is not exercised. `runids=1` in step5-warn holds without it, because the harness is one process.

### n-1 (nit): the relay comment overstates ordering against /dev/tty prompts
- **Where:** aitools-lib.sh:662-664 says the relay shows the child's lines "so its log lines show before any prompt it reads from /dev/tty". That is PR #115 code, but this PR is the first to put an interactive child behind it.
- **Evidence:** pty probe `probe-prompt-small.py` / `probe-prompt-sleep.py`. The bash child writes N log lines to stdout, then its menu to /dev/tty.
  - With no work between the last line and the menu, lines arrived after the menu in 10/10 runs (N=1, 3, 5, 40).
  - With 10 ms or more of work before the menu, 0/10 (10 ms, 50 ms, 200 ms).
- **Impact:** real `prompt_diff_review` computes a diff first, so it is very likely fine. Still, the comment states a guarantee the code does not give.
- **Suggested fix:** soften the comment ("usually").

### n-2 (nit): Step 3 failure reasons
- **bash:** a failed `mkdir -p` / `cd` puts its reason on raw stderr, not in deploy.log (aitools-install.sh:170, 181). PS logs it as `LogDetail` (aitools-install.ps1:121).
- **Message order:** PS logs "Repos path ... is relative -- using <abs>" before it creates the directory (ps1:108); bash logs it after (sh:190). On a creation failure PS shows that line and bash does not.

### n-3 (nit): `log` in pipeline subshells (aitools-install.sh:622, 671)
- **Effect:** if deploy.jsonl first fails inside one of these `| while ... log` loops, the flag and the warning count stay in the subshell, so the warning would repeat and go uncounted.
- **Why it does not happen today:** the main shell logs many lines before Step 13, so the flag is set first. A comment would be enough.

### n-4 (nit): thin wrappers (`jsonl_write`, `run_config_writer`, `Invoke-ConfigWriter`)
- I agree with keeping them (file ownership: test-config.sh belongs to S3-MF-Fix3). They hold no logic, and test-config passes against them.
- Open a tracked issue for their removal rather than leaving it only in the PR body's Follow-ups.

## The PR's stated choices

- **I-1 scope (only Step 5 and user init's two children relayed):** agreed. The reason given, that relaying moves a child's stdout off the terminal, is correct. M-1 is that same effect on the hooks child, so it argues for applying the reasoning to user init's interactive child too.
- **Warnings counted in user init but not visible:** agreed. It is stated honestly, and the tests check what can be seen.
- **A hooks abort becomes `ERROR|claude hooks|aborted (exit 2)` plus one counted error:** consistent with #115 and with interactive-menus.md ("[x]abort logs an error and exits 2"). D-TS13 holds: user init still returns 2 (aitools:1032-1038, aitools.ps1:1657-1664; test hook-abort).
- **A-16 warning is counted and so promotes later OK rows:** matches the mission's restated rule ("one warning").
- **PS `CreateDirectory` + `Test-Path` instead of `New-Item -Force`:** agreed. The result check is correct either way.

## Checked and clean

- **Recursion:** bash `jsonl_record` → `log_warn` → installer `log` → `jsonl_record` returns early because `AITLIB_JSONL_FAILED` is set first (lib.sh:579, 586-587). PS sets `$script:AitLibJsonlFailed` before `LogDetail` / `LogWarn` (lib.ps1:483, 496-498).
- **Scope:** the relay loop runs in the main shell (process substitution), so the flag and WARNINGS persist.
- **bash `2>/dev/null >>`:** the order is right. The redirect failure message goes to /dev/null, and the `if` is the result check.
- **Removed globals:** `LOG_JSONL`, `RUN_ID`, `HOST_NAME`, `$logJsonl`, `$runId`, `$hostName` and `$osName` have no remaining users. `OS_NAME` is still used (install.sh:354, 448, 618).
- **PS dynamic scope:** the relay's locals carry the `AitLib` prefix. The in-process children see the same caller variables as before; `$Writer` / `$WriterArgs` already existed.
- **`$writerRc` / `$writerRelay`:** these capture only the relay's return value. The child's output is consumed by `Send-AitLibChildLine`.
- **bash 3.2:** `local a=()`, `${#arr[@]}` on an empty array, and arrays expanded only when non-empty.
- **Interactive bash children:** menus go to /dev/tty, `tty_interactive` tests stdin only (lib.sh:1563), and no child tests `-t 1` / `IsOutputRedirected` (grep over setup-user-hooks/config .sh/.ps1 and both libs).

## Verification (macOS arm64, isolated HOME and AITOOLS_LOG_DIR under my scratch, run from a scratch cwd)

Syntax checks are clean on every touched script:
- `bash -n` with bash 5 and /bin/bash 3.2.57: aitools-lib.sh, aitools-install.sh, aitools, test-install.sh, test-user-init.sh.
- pwsh parser: aitools-lib.ps1, aitools-install.ps1, aitools.ps1.

Suites:

| suite | bash 5 + pwsh | /bin/bash 3.2 --bash-only |
|---|---|---|
| test-install | 39/0 | 21/0 |
| test-user-init | 252/0 | 141/0 |
| test-config | 269/0 | 174/0 |
| test-lib | 361/0 | 160/0 |
| test-profile | 689/0 | 498/0 |

Negative controls:
- **Base scripts:** `git archive origin/fix/mf-lib-relay` plus the new tests. test-install 7/32 (structural: the base installers have neither block); test-user-init 243/9.
- **Lib-only (mine):** the PR tree with aitools-lib.sh/.ps1 from the base. test-install 35/4, and the 4 failures are exactly jsonl-blocked in bash and ps (`warnings=1` against 2; `cannot write` 0 times against 1). The tests isolate the A-16 lib change. With the old lib the installer also reached the end, so A-16's "goes on" comes from A-1 and the lib change adds the warning.

Probes (in `.claude/worktrees/mf-relay-revb/.scratch/session-mfrelrevb/`):
- probe-prompt.py / -small.py / -sleep.py (M-1, n-1)
- probe-alias.sh / probe-alias-inproc.ps1 / probe-alias-func.ps1 (m-1)
- probe-envleak.ps1 (m-2)

CI at review time: linux and windows pass, macos pending.

## Not run

- Windows / Git Bash. M-1 was reproduced with pwsh on macOS under a pty, with the same `[Console]` code path.
- The full installer (incident #89).
- The A-14 failure path.
- check-pre-commit / check-pre-push: review only, nothing committed.
