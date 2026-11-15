# S3-Skill report v1.1 -- skills-fanout and skills-legacy platform targeting

## v1.1 fix-forward (Windows CI run 41265193554): 15 FAILs, all test-harness causes

Commit 5f4d42e on feature/ci-plat-skill (fast-forwarded to 07f0787 first), pushed.

**8 FAILs: USERPROFILE was passed as C:/... (forward slashes).**
- Which checks: fanout retired, retired-mod and cursor (explicit ACTION-row checks), plus the goldens for retired, retired-dry, retired-mod, cursor and cursor-rerun.
- Cause: `Invoke-HarnessSkillsFanout` (aitools-lib.ps1:3110) compares DestDir (all backslashes, as the logs show) with `$USERPROFILE + '\'`. That never matched, so the row printed "<home>/.claude/skills" where the golden has "~/.claude/skills".
- Fix: HOME and USERPROFILE are now passed in Windows form (`cygpath -w`, new `win_path`), as Windows itself sets USERPROFILE.

**2 FAILs: adopt targets under the aitools checkout did not normalize.**
- Which checks: fanout "adopt map shared" and "adopt map dup".
- Fix: `lognorm` now turns every backslash into a slash and replaces the temp root in every form (POSIX, `cygpath -m`, `cygpath -m -l`; case-insensitive). This was checked on Windows-shaped sample lines.
- The exact form the .ps1 logs was not visible (it is in deploy.log). The new normalization covers every form I could think of.

**5 FAILs: the legacy build found no dotprofile.**
- Which checks: the 3 build checks and the 2 MDM ps cases, which need the generated script.
- Cause: build-deploy.sh's resolver runs aitools-profile.ps1 through pwsh, and pwsh's $HOME follows USERPROFILE. USERPROFILE was not set, so the resolver read the runner's own home.
- Fix: the build now also gets USERPROFILE (Windows form).

**Points from v1.0 that turned out fine:** bracket names (`a*b?.md`), the x bit, the whole setup-user-cursor.ps1 run, deploy-harness.ps1 and 8.3 paths in rows all passed.

**macOS, CI=true, compare mode, goldens unchanged:** fanout 123/0/1 and legacy 39/0/0 (pass/fail/skip), under bash 5.3 and /bin/bash 3.2.

**Product diffs: none required.** Optional hardening, not applied: in aitools-lib.ps1 Invoke-HarnessSkillsFanout, compare `($homeDir -replace '/','\')` with `($DestDir -replace '/','\')`, so a USERPROFILE written with forward slashes still displays as ~/.

---

# v1.0

Delegate S3-Skill for Session Commander e99e5ef9-9, 2026-11-01. Plan:
`plans/ci-platform-targeting.md` batch B4.

## Summary

1. Both suites now run ONE language per platform: `.sh` on macOS/Linux, `.ps1` on Windows (Git Bash driving native pwsh), following the b8-consumers exemplar.
2. Every guard bypass is gone: the Perl guard-stripped `.ps1` copies (4 in legacy, 1 in fanout), `AITOOLS_PROFILE_TEST_ANY_OS=1`, and the use of `tests/rules-fanout-cursor/step4-driver.ps1` (fanout's cursor cases now run the real `setup-user-cursor.ps1` whole, with `.cmd` stubs).
3. sh-vs-ps1 parity is now `golden_match` against committed goldens: 34 files in `tests/skills-fanout/golden/*.txt`, 12 in `tests/skills-legacy/golden/*.rows`. All were written from the macOS bash run. None holds a temp path, `/Users/`, `/var/folders`, a hostname or a username.
4. On macOS, in compare mode with `CI=true`, both suites are green under bash 5.3 and /bin/bash 3.2: fanout 123 pass / 0 fail / 1 skip, legacy 39 pass / 0 fail / 0 skip.
5. Windows and Linux have not been run. The Windows half runs for the first time in PR #139 CI, and I list the likely failure points below.

## Branch and SHAs

- Branch `feature/ci-plat-skill` (off `origin/feature/ci-platform-targeting` at a857c12), pushed. No PR.
- `1ba9bb0`: CI targeting B4: skills-fanout runs one language per platform, golden parity
- `f9c652e`: CI targeting B4: skills-legacy runs one language per platform, golden parity

## Files changed

- `tests/skills-fanout/test-skills-fanout.sh`
- `tests/skills-fanout/golden/` (34 new): badheader, binary, binary-edited, bracket, broken, cursor, cursor-none, cursor-rerun, cursor-retired-only, empty, fanout, fanout-dry, fanout-edited, fanout-force, fanout-rerun, fanout-xbit, invalid, kept, manifest-unreadable, missing, nocreate, nocreate-dry, nomanifest, payload, reserved, retired, retired-case, retired-dry, retired-mod, rmfail, unlisted, unreadable, utf8edge, utf8large (`.txt` each)
- `tests/skills-legacy/test-skills-legacy.sh`
- `tests/skills-legacy/golden/` (12 new): adopt, adoptfail, hdu, dstu, empty, fallback, fan, hbad, mfu, nodp, rerr, rerrfb (`.rows` each)

No file under `scripts/`, `shared/`, `.github/`, `tests/lib/` or another suite was touched. No `.ps1` was touched, so there was nothing to parse-check.

## Per suite

### skills-fanout

| Run (macOS) | Old (`--bash-only`) | New |
|---|---|---|
| bash 5.3 | 88 pass, 37 skip | 123 pass, 0 fail, 1 skip |
| /bin/bash 3.2 | 88 pass, 37 skip | 123 pass, 0 fail, 1 skip |

- The 37 old skips were the parity cases, which skip without pwsh. The 1 new skip is `dupcase` (case-insensitive APFS). With `CI=true` the counts are the same.
- **Golden format**: one `golden/<case>.txt` per parity point. It holds:
  - the exit code;
  - the skills tree as `path md5 [x]` (relative, perl byte sort);
  - each backup file listed once as `path.bak.TS (backup)`. Two runs in the same second share one backup name, so a plain md5 list was flaky: the first compare run failed `fanout-force` and `fanout-xbit` until I changed this;
  - no symlinks (they are checked explicitly);
  - the ACTION and claude/cursor-skills rows, sorted, with HOME shown as `HOME` and the temp root as `<TMP>`.
- **rmfail**: the old "backup directory modes sh = ps" check is now an extra line in the rmfail record (`backup gone/sub mode 555`).
- **No golden file on purpose**:
  - `real` and `real-rerun`: the tree is this checkout's own skills, so the golden would change with every skill edit. Their explicit checks run on every platform.
  - `dupcase`: only a case-sensitive file system (Linux) can build it, so macOS cannot write the golden and Windows never runs it.
- **No `NAME.<platform>` variants.**
- The checks that used to read only the `.sh` output now read the output of the language under test. I grepped the `.ps1` sources and each console or log message those checks look for is there, but no Windows run has confirmed it yet.
- The adopt-target checks now compare logs normalized to `<TMP>`. They use `_golden_normalize` from `platform-lib.sh` (see the proposed diff below).

### skills-legacy

| Run (macOS) | Old (pwsh hidden from PATH, so no emulation ran) | New |
|---|---|---|
| bash 5.3 | 27 pass, 3 skip | 39 pass, 0 fail, 0 skip |
| /bin/bash 3.2 | 27 pass, 3 skip | 39 pass, 0 fail, 0 skip (with and without `--bash-only`) |

- The 12 new passes are the per-case golden checks. They replace the old single 12-case `_parity` check, which only ran with pwsh.
- **Golden format**: `golden/<case>.rows` holds the summary rows without the resolver's ACTION and dotprofile rows, sorted with `LC_ALL=C`. No platform variants.
- **MDM**: `build-deploy.sh` runs on every platform, since it is an all-platform bash script. The generated `.ps1` is parsed and run on Windows only.
- **Options**: `--bash-only` is accepted as a no-op. Unknown options are now an error; before, they were silently ignored.

## check.yml steps (proposed; the file is not mine to edit)

Linux (`ubuntu-24.04`), run lines unchanged, names only:
- `setup-user-skills fallback dev + MDM tests (.sh)`: `bash tests/skills-legacy/test-skills-legacy.sh`
- `Claude skills fan-out tests (.sh)`: `bash tests/skills-fanout/test-skills-fanout.sh`

macOS bash 5, run lines unchanged, names only:
- `setup-user-skills fallback dev + MDM tests (.sh, bash 5)`: `bash tests/skills-legacy/test-skills-legacy.sh`
- `Claude skills fan-out tests (.sh, bash 5)`: `bash tests/skills-fanout/test-skills-fanout.sh`

macOS /bin/bash 3.2, unchanged:
- `setup-user-skills fallback dev + MDM tests (macOS /bin/bash 3.2)`: `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/skills-legacy/test-skills-legacy.sh`
- `Claude skills fan-out tests (macOS /bin/bash 3.2)`: `AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/skills-fanout/test-skills-fanout.sh --bash-only`

Windows (`windows-2022`), new. Put them after the pywinpty install step, for example after the b8 step:

```yaml
      - name: setup-user-skills fallback dev + MDM tests (.ps1, native pwsh)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/skills-legacy/test-skills-legacy.sh

      - name: Claude skills fan-out tests (.ps1, native pwsh)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/skills-fanout/test-skills-fanout.sh
```

What the Windows steps need:
- `node` (preinstalled on the runner; build-deploy for legacy MDM).
- `python3` with pywinpty for the pty cases. If python3 is not the setup-python interpreter that pywinpty was installed into, the pty cases FAIL under CI with "pywinpty not installed". They do not skip silently.

## Not converted, or coverage lost

- **The .ps1 half of the POSIX-only fixtures is no longer tested anywhere.** These cases used to run under macOS pwsh:
  - symlink cases: fanout `kept`, `broken`, and the firecrawl checks;
  - chmod cases: fanout `rmfail`, `unlisted`, `unreadable`, `manifest-unreadable`; legacy `mfu`, `hdu`, `dstu`, `adoptfail`;
  - `dupcase`.
  
  Windows SKIPs them, with the reason (or, for legacy, the existing `skip` lines). Their goldens now only pin the .sh behaviour.
- Nothing else was left unconverted.

## Likely Windows failure points (please read the first CI run with these in mind)

1. **bracket case**: `a*b?.md` contains characters NTFS does not allow. Git Bash maps them to private-use code points; whether pwsh round-trips them is unknown. If it fails, give that file only to POSIX and add a `golden/bracket.txt.windows` variant.
2. **x bit**: under Git Bash (noacl), `-x` and perl's `-x` are a guess from a shebang or extension. The goldens mark only `s1/scripts/run.sh` (which starts with `#!`) as `x`, so I expect a match, but that is not verified.
3. **8.3 short paths**: if pwsh logs `C:\Users\runneradmin\...` while `cygpath -m` gives `RUNNER~1`, the `<TMP>` normalization misses. That breaks the `logged ... adopt=<TMP>/...` checks and any golden that holds a path.
4. **setup-user-cursor.ps1 whole run**: steps 1-3 now run on Windows. An ACTION row the .sh does not write would make the four cursor goldens differ.
5. **deploy-harness.ps1** (fanout real case): this is its first run in this suite.

## Proposed diffs (not applied)

`tests/lib/platform-lib.sh`: make the normalizer public, because a suite now uses it for log checks:

```diff
-# _golden_normalize FILE: normalized content on stdout
-_golden_normalize() {
+# golden_normalize FILE: normalized content on stdout (also used by suites to
+# compare logs that hold native paths)
+golden_normalize() {
@@
-    if _golden_normalize "$file" | cmp -s - "$golden"; then
+    if golden_normalize "$file" | cmp -s - "$golden"; then
@@
-    _golden_normalize "$file" | diff "$golden" - | ...
+    golden_normalize "$file" | diff "$golden" - | ...
@@
-        _golden_normalize "$file" > "$golden"
+        golden_normalize "$file" > "$golden"
+_golden_normalize() { golden_normalize "$@"; }   # old name, kept for callers
```

After that, `tests/skills-fanout/test-skills-fanout.sh` `lognorm()` would call `golden_normalize`.

No `scripts/` changes are needed for these suites.

## WRITE_BLOCKED / CONFLICT / INCIDENT

- WRITE_BLOCKED: none.
- CONFLICT: D-DEL4 ("a code-change delegate opens its own PR") vs the commander's newer words of 2026-11-01 ("Branch + PR", one PR #139; "Everything at once"). Resolved by tier 1 (the commander's own words): I pushed `feature/ci-plat-skill` and did not open a PR.
- INCIDENT: none filed. One observation: a suite now depends on the underscore-private `_golden_normalize` (proposed fix above).
- Skills: `/scratch` loaded. `/delegate` was not loaded because I launched no delegate.

## Open questions (with suggested answers)

1. Keep goldens for the POSIX-only cases (they pin only .sh behaviour)? **Suggest yes**: they are cheap and catch .sh regressions on Linux and macOS.
2. Restore .ps1 coverage of the symlink and permission fixtures on Windows (native symlinks via `MSYS=winsymlinks:nativestrict`; deny ACLs via `icacls` instead of chmod 000)? **Suggest a follow-up item**, not this PR.
3. If the bracket case fails on Windows: a POSIX-only glob-chars file plus `bracket.txt.windows`? **Suggest yes**. The `[x]` part stays on every platform.
