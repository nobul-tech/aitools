# S3-Cfg report v1.1 (2026-10-31)

## v1.1: fix-forward for PR #139 run 41265193554 (windows: test-config failed 9 checks)

The windows job ran test-config at 238 passed, 9 failed. All 9 failures have one cause: the same directory appears under two names.

- **What the suite passed:** the runner's TEMP is the 8.3 short `C:\Users\RUNNER~1\...`. `cygpath -m` keeps that form, so the suite passed pwsh `C:/Users/RUNNER~1/...`.
- **What pwsh returned:** in some places pwsh spells the path long, `C:\Users\runneradmin\...`.

| FAIL | Cause | Fix |
|---|---|---|
| ps1 step3: relative 'repos' | Get-Location is the long form (`C:\Users\runneradmin\...`); the expected value was short | harness: NH is the long form (`cygpath -m -l`) |
| ps1 step3: '../home/repos' | same | same |
| c4-corrupt, c17-legacy-migrate, c18-real-warning, c20-stale-machine-id, c21-salvage-machine-id, c22e-no-machine-keeps-id, c22f-no-machine-legacy (7 golden FAILs) | userRepoPath only. These cases have no githubUser, so the resolver scans for the dotprofile, and `$found[0].FullName` (aitools-profile.ps1 `Resolve-UserRepoPath` scan branch) gives the long form. That form is not the `cygpath -m` form of GOLDEN_TMP, so it was not replaced by `<TMP>`. | harness: every path handed to pwsh is long (NWORK), and norm_json replaces NWORK (case-insensitive) with `<TMP>`. No golden changed, no NAME.windows file |

- **Commit:** 677355a on feature/ci-plat-cfg, fast-forwarded first to origin/feature/ci-platform-targeting at 07f0787. Pushed; no PR.
- **macOS:** 251 passed, 0 failed under bash 5.3 and under /bin/bash 3.2.
- **Proposed product diff (optional, cosmetic; not needed for the suite):** for parity with the bash scan, which keeps the base prefix as given, aitools-profile.ps1 line 381 could be `$script:RurPath = Join-Path $base $found[0].Name`. Then the scan returns the same spelling as the convention branch (line 365). Today a short-form reposPath gives a long-form userRepoPath on Windows only. It is the same directory, so this is no functional bug.
- **Signals:** WRITE_BLOCKED none; CONFLICT none new; INCIDENT none.

---

# S3-Cfg report v1.0 (2026-10-31)

Mission: convert tests/profile/test-config.sh and test-user-init.sh (+ user-init-harness.ps1) to platform targeting. Delegated by Session Commander e99e5ef9-9.

## Summary

1. Both suites now run each script only where its OS guard allows: `.sh` on macOS/Linux, `.ps1` on Windows (Git Bash driving native pwsh). No guard bypass is left.
2. The sh-vs-ps1 parity checks became one `golden_match` per case. There are 69 goldens in `tests/profile/golden/` (43 `config-*`, 26 `userinit-*`), written from the macOS bash run.
3. On Windows, test-user-init now runs `scripts/aitools.ps1` whole, the same way the bash side runs `scripts/aitools` whole. `tests/profile/user-init-harness.ps1` ran the user-init block past the guard, so I removed it.
4. macOS results (compare mode): test-config 251/251 and test-user-init 169/169, each under bash 5.3 and under /bin/bash 3.2.
5. Windows and Linux are not run. They are validated by PR #139 CI after you merge the branch.

## Branch and commits

- Branch `feature/ci-plat-cfg`, from `origin/feature/ci-platform-targeting` at a857c12. Pushed; no PR opened.
- 3759bc1: test-config.sh and 43 `config-*` goldens.
- cfa08af: test-user-init.sh, 26 `userinit-*` goldens, user-init-harness.ps1 removed.

## Files changed

- `tests/profile/test-config.sh` (rewritten)
- `tests/profile/test-user-init.sh` (rewritten)
- `tests/profile/user-init-harness.ps1` (removed)
- `tests/profile/golden/config-<case>.txt` (43 files)
- `tests/profile/golden/userinit-<case>.txt` (25 files) and `userinit-pty-claim-menu.txt`

## Per suite

### test-config.sh

| | Before (`--bash-only`) | After (compare mode) |
|---|---|---|
| macOS bash 5.3 | 208 passed | 251 passed, 0 failed, 0 skipped |
| macOS /bin/bash 3.2 | 208 passed | 251 passed, 0 failed, 0 skipped |

- **Golden per case:** `config-<case>.txt` holds the exit code, the summary rows (in order) and config.json.
- **JSON normalization:** before the compare, config.json goes through `norm_json`, which removes CR and turns JSON-escaped backslashes (`C:\\Users\\...`) into `/`. On Windows, Join-Path writes those backslashes into config.json. platform-lib's normalizer handles only single backslashes (see the proposed diff below).
- **No `NAME.<platform>` variants.**
- **Native paths on Windows:**
  - Fixture paths and arguments use NH/NDP, the native forms (cygpath -m).
  - HOME and USERPROFILE are both set.
  - The writer runs as `pwsh -NoProfile -NonInteractive -File <native>`.
  - `MSYS_NO_PATHCONV=1`, so Git Bash cannot rewrite `--drives-json`.
- **C25** (failing-rm stub) is .sh only, as before: SKIP on Windows.
- **Installer Step 3/5:**
  - Absolute input: `/abs/repos` (sh) or `C:/abs/repos` (ps1).
  - Run from `/`: gives `/tmp` (sh) or `<Git install dir>/tmp` (ps1).
  - ps1 paths are compared without regard to separators and case.

### test-user-init.sh

| | Before (`--bash-only`) | After (compare mode) |
|---|---|---|
| macOS bash 5.3 | 141 passed | 169 passed, 0 failed, 0 skipped |
| macOS /bin/bash 3.2 | 141 passed | 169 passed, 0 failed, 0 skipped |

- **Golden per case:** `userinit-<case>.txt` holds the exit code, the summary rows, profile.json and the commit subjects of `remote.git` and `gh-remote.git`. The pty menu is in `userinit-pty-claim-menu.txt`.
- **profile.json normalization:** register writes `machine.os` and `machine.arch`, which differ per platform (darwin/arm64, linux/x64, win32/x64). Only inside this machine's profile object they become `<OS>` / `<ARCH>`, so fixture values such as other-box's `"linux"` stay. A new explicit check asserts the platform value of `machine.os` and that `machine.arch` is set.
- **No `NAME.<platform>` variants.**
- **Output normalization (`norm_run`):**
  - Removes SGR colours and CR.
  - For ConPTY, removes the other CSI sequences (cursor-forward is kept as spaces) and OSC title sequences.
  - Replaces the fixture directory with `<D>` in its POSIX, `cygpath -m` and `cygpath -w` forms, and turns the backslashes in the rest of the path into slashes.
- **gh stub on Windows:** it also comes as `gh.cmd`, which runs the bash stub with `cygpath -w "$BASH"`, so it cannot resolve to WSL's bash shim.
- **Summary-panel check** is per language: the bash box rule `────`, or the dashed rule from aitools-lib.ps1 `Show-Summary`.
- **alias-novalue (A-15)** stays bash only (SKIP on Windows).
- **profile-check.js and the decision-2 switch check** run on every platform.
- **pty cases on Windows** run when `python3 -c 'import winpty'` works; otherwise one SKIP line.

## check.yml steps

Replace the existing steps for these two suites.

**linux**

```yaml
      - name: Config writer tests (.sh)
        if: ${{ !cancelled() }}
        run: bash tests/profile/test-config.sh

      - name: User init tests (.sh, pty menus)
        if: ${{ !cancelled() }}
        run: bash tests/profile/test-user-init.sh
```

**macos**

```yaml
      - name: Config writer tests (.sh, bash 5)
        if: ${{ !cancelled() }}
        run: bash tests/profile/test-config.sh

      - name: Config writer tests (macOS /bin/bash 3.2)
        if: ${{ !cancelled() }}
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-config.sh

      - name: User init tests (.sh, bash 5, pty menus)
        if: ${{ !cancelled() }}
        run: bash tests/profile/test-user-init.sh

      - name: User init tests (macOS /bin/bash 3.2)
        if: ${{ !cancelled() }}
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-user-init.sh
```

**windows** (after the pywinpty install step, next to the b8 step)

```yaml
      - name: Config writer tests (.ps1, native pwsh)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/profile/test-config.sh

      - name: User init tests (.ps1, native pwsh, ConPTY menus)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/profile/test-user-init.sh
```

`--bash-only` is still accepted as a no-op, so the old 3.2 run lines also work.

## Not converted, and Windows risks to watch in CI

Everything was converted. These parts are untested on Windows:

1. **Path case and 8.3 short names.** If pwsh writes a long-form path (`runneradmin`) where we passed `RUNNER~1`, or the case differs, a golden diff shows `C:/...` instead of `<TMP>` / `<D>`. The fix is the case-insensitive option in the platform-lib proposal below.
2. **ConPTY rendering of the pty-claim menu.** It could repaint lines or wrap them differently from the POSIX pty. The normalization covers cursor-forward, other CSI sequences and OSC, but this is not proven.
3. **gh.cmd lookup.** It relies on PowerShell finding `gh.cmd` in the first PATH directory ahead of the runner's real `gh.exe`. I believe PowerShell searches PATH in order, but that is not verified.
4. **Whole aitools.ps1 on Windows.** It reads config.json from `$env:USERPROFILE` and needs `$R/.git` (the fixture git-inits it). I read every top-level statement between the guard and the `user` dispatch and found nothing else that runs. If it still breaks for a test-only reason, restoring the harness is `git checkout a857c12 -- tests/profile/user-init-harness.ps1` plus the old ps1 command line.

## Proposed diffs (not applied: owner is the commander)

### tests/lib/platform-lib.sh

Normalize JSON-escaped Windows paths, and optionally ignore case on Windows. My suites do not depend on this change (test-config pre-normalizes with `norm_json`), but other suites that golden-compare JSON will need it.

```diff
@@ _golden_normalize() {
-    GT_POSIX="$tmp_posix" GT_NATIVE="$tmp_native" perl -pe '
+    GT_POSIX="$tmp_posix" GT_NATIVE="$tmp_native" GT_CI="$([ "$TEST_PLATFORM" = windows ] && printf i)" perl -pe '
         s/\r//g;
         for my $t (grep { length } ($ENV{GT_NATIVE}, $ENV{GT_POSIX})) {
             (my $bs = $t) =~ s{/}{\\}g;
-            s/\Q$t\E([^\s|"]*)/my $r = $1; $r =~ tr{\\}{\/}; "<TMP>$r"/ge;
-            s/\Q$bs\E([^\s|"]*)/my $r = $1; $r =~ tr{\\}{\/}; "<TMP>$r"/ge;
+            (my $jbs = $t) =~ s{/}{\\\\}g;   # JSON-escaped: C:\\Users\\...
+            for my $f ($jbs, $t, $bs) {
+                my $re = $ENV{GT_CI} ? qr/\Q$f\E([^\s|"]*)/i : qr/\Q$f\E([^\s|"]*)/;
+                s/$re/my $r = $1; $r =~ s{\\\\}{\/}g; $r =~ tr{\\}{\/}; "<TMP>$r"/ge;
+            }
         }
     ' "$1"
```

### scripts/aitools.ps1

The `# --- BEGIN user init ---` / `# --- END user init ---` markers have no reader once the harness is gone. Suggested: keep them (harmless, and they mark the parity block with `user_init` in scripts/aitools), or delete them in a later scripts/ change. No change needed for this mission.

## Signals

- `CONFLICT: D-DEL4 (the delegate opens its own PR) vs the commander's newer words, 2026-11-01 ("Branch + PR" is one PR, #139; "Everything at once") -- resolved by tier 1: I pushed feature/ci-plat-cfg and did not open a PR.`
- `CONFLICT: the prompt's "also remove its mention in user-init-harness.ps1's header" vs the prompt's operational learning ("Remove every guard bypass: ... drivers that skip a guard") and the plan's Design (retire step4-driver.ps1, which runs a script past its guard) -- resolved by tier 2 (both are the prompt; the plan records the commander's design): I removed the harness, because it is such a driver, and on Windows the real entry point runs. The header edit became moot.`
- WRITE_BLOCKED: none.
- `INCIDENT:` none filed. Observation: `plans/fan-plan-reconciliation.md` lines 182 and 325 still tell agents to run `tests/profile/user-init-harness.ps1` under macOS pwsh. That is stale now and banned emulation. Suggest a one-line plan edit by the commander (plans/ is protected and out of my scope).

## Open questions (with suggested answers)

1. **Run the 3.2 job without `--bash-only`?** Suggested: yes. It is a no-op now, and dropping it keeps the run lines uniform with b8-consumers.
2. **Apply the platform-lib JSON and case diff now or after the first Windows CI run?** Suggested: now. S3-Prof and the other delegates compare JSON too, and the diff is backward compatible: POSIX goldens are unchanged.
3. **Should c8b (read-only `~/.aitools`) SKIP on Windows, where chmod does not block writes?** Suggested: keep it running. It still asserts the dry run writes nothing and reports `would update`, and its comment says so.

## Verification log (macOS, this worktree)

- `bash -n` passes on both suites.
- The inline PowerShell (inst-harness.ps1 heredoc in test-config, hooks stub in test-user-init) parses with `scripts/_validate-ps1.ps1`.
- Goldens contain no `/Users/`, `/var/folders`, `/private/`, `tmp.`, user names, `darwin` or `arm64`.
- `golden_match` fails on a changed result (scratch `neg-golden.sh`).
- Simulated Windows config.json and ConPTY output normalize to the golden form (scratch `sim-win-norm.sh`, `sim-win-run.sh`).
- Scratch: `/Users/new-jose/repos/aitools/.claude/worktrees/ci-plat-cfg/.scratch/session-S3-Cfg/`. It is not harvested from a worktree; nothing in it needs to carry forward.
