# S3-Prof report v1.1 (2026-10-31)

Mission S3-Prof: convert tests/profile/test-profile.sh, test-lib.sh and test-install.sh to platform targeting. Delegated by Session Commander e99e5ef9-9.

## v1.1: fixes for the first Windows CI run (run 41265193554)

That run had 26 failing checks. All 26 came from three bugs in my test harness. None is a bug in a product script, so no change to scripts/ is proposed. The fixes are in commit 27d7b3b on feature/ci-plat-prof, which was first fast-forwarded to origin/feature/ci-platform-targeting (07f0787).

**1. The temp directory has two spellings on the Windows runner.** cygpath -m gives `C:/Users/RUNNER~1/...` (8.3 short form). pwsh sometimes prints `C:\Users\runneradmin\...` (long form). `from_native` only knew the first.
- Fixed in all three suites: `from_native` now maps back the default, long (-l) and short (-s) cygpath spellings, longest first.
- Failures this fixes:
  - test-profile urp-scan, urp-corrupt-config, urp-utf16: golden mismatch on the `path` line.

**2. test-profile ran four cases against the wrong home.** The dc-host block switches H and restores it, but did not restore HN. The Windows run takes HOME from HN, so the next cases used the dc-host fixture: a legacy profile matched by hostname only, which the resolver refuses (exit 3). `run_impl` now takes HOME from H each time, and the restore also resets HN.
- Failures this fixes (19 checks):
  - exc-set-same: 3
  - exc-set-changed: 6
  - exc-set-dirty: 5
  - exc-set-nopush: 5

**3. cygpath refuses a path whose parent is a file.** test-install's step3-uncreatable case uses exactly such a path. cygpath printed "Not a directory", so pwsh got an empty `-ReposPath` and resolved the current directory instead. Paths under $WORK now get their native prefix by string replacement, with no cygpath call.
- Failures this fixes (3 checks): test-install step3-uncreatable: console output, END line, summary row.

**4. A bash-only check ran on Windows.** In test-lib, the deploy.log check for relay-run-rm-fail sits outside `relay_case`, so it still ran after the bash case was skipped. It now runs only where bash runs (macOS/Linux) and prints a skip line on Windows.
- Failures this fixes (1 check): test-lib relay-run-rm-fail.

**Verification:** on macOS all suites pass under both bash 5 and /bin/bash 3.2: test-profile 735/735, test-lib 161/161, test-install 22/22. No golden file changed.

**Lines:**
- WRITE_BLOCKED: none.
- CONFLICT: none new.
- INCIDENT: none.

## Summary

1. All three suites now run only the language their platform allows. macOS and Linux run .sh, bash and perl. Windows (Git Bash) runs .ps1 under native pwsh. No guard bypass is left: `AITOOLS_PROFILE_TEST_ANY_OS` is gone from all three suites.
2. Each sh-vs-ps1 parity check is now a `golden_match`. There are 190 golden files under tests/profile/golden/: 189 `profile-*` and 1 `lib-*`. test-install has no parity check, so it has no golden files. No `NAME.<platform>` variant was needed.
3. On macOS everything passes under bash 5 and /bin/bash 3.2: test-profile 735/735, test-lib 161/161, test-install 22/22. A tampered golden fails the suite as it should. The goldens contain no temp paths, user names or host names.
4. The Windows half is written but has not been run. Your PR #139 CI will be its first run. It handles native paths both ways (`native_path` going in, `from_native` coming back), turns off MSYS argument conversion, and sets HOME and USERPROFILE.
5. The branch is pushed. I did not open a PR (see the CONFLICT line).

## Branch and commits

Branch `feature/ci-plat-prof`, made from `origin/feature/ci-platform-targeting` at a857c12 and pushed to origin:
- 3cebca0: test-install.sh
- 919c075: test-lib.sh + golden/lib-relay-record.jsonl
- 9d8c224: test-profile.sh + 189 golden/profile-* files

## Files changed

- /Users/new-jose/repos/aitools/.claude/worktrees/ci-plat-prof/tests/profile/test-install.sh
- /Users/new-jose/repos/aitools/.claude/worktrees/ci-plat-prof/tests/profile/test-lib.sh
- /Users/new-jose/repos/aitools/.claude/worktrees/ci-plat-prof/tests/profile/test-profile.sh
- /Users/new-jose/repos/aitools/.claude/worktrees/ci-plat-prof/tests/profile/golden/ (190 new files)

No file changed under scripts/, shared/, tests/lib/ or .github/.

## Per suite

| Suite | Old macOS | New macOS (bash 5 / 3.2) | Linux (expected) | Windows (expected) | Goldens |
|---|---|---|---|---|---|
| test-profile | 763 | 735 / 735 | 739 (adds rm-web, 4 checks) | about 716 (less 19 POSIX-only checks) | 189 profile-* |
| test-lib | 361 | 161 / 161 | 161 | 201 (164 ps + 36 gitbash + 1 golden) | 1 lib-relay-record.jsonl |
| test-install | 41 | 22 / 22 | 22 | 19 | 0 (all checks are explicit) |

Why test-profile drops from 763 to 735 on macOS: the old JSON-engine cases checked two engines each. Each now checks one engine.

None of the golden files needed a `NAME.<platform>` variant:
- `relay-record`: the record's `host` and `os` fields become `<HOST>` and `<OS>`. They are identical only when both shells run on one machine.
- `reg-update` and `reg-create` written files: the profile's own os and arch become `<OS>` and `<ARCH>` (`plat_norm`).
- The JSON-engine fixture is now built from the register fixture before os/arch are set to this machine's values, so its goldens do not depend on the platform.

## How each suite was converted

**Shared in all three suites**
- They source tests/lib/platform-lib.sh. `LANG_RUN` is set to `TEST_LANG`. If pwsh is missing on Windows, the suite fails at once.
- `--bash-only` is kept as a no-op alias, and `--help` is added.
- `from_native FILE` (Windows only) maps the native spellings of `$WORK` back to the POSIX path and removes CRs. It covers `C:/`, `C:\`, JSON-escaped `C:\\` and `/c/`. I tested it on sample lines on macOS.
- Native pwsh calls use `-NoProfile -NonInteractive -File` with native paths.
- HOME and USERPROFILE are set to the native temp home.
- `MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'` is set so arguments like `/caller/urp` and `/usr/local/bin/go` reach pwsh as written.

**test-lib**
- The m2 `via-pwsh-*` cases became the `gitbash` implementation and run on Windows only. There aitools-lib.sh takes its pwsh branch for real (`AITOOLS_PLATFORM=windows`).
- On macOS these cases would run aitools-profile.ps1, whose guard now refuses to run.
- The cygpath stub in the path-args case now passes every path that is not under `/conv/` to the real cygpath.

**test-profile**
- Paths written into fixture config.json files use `HN` (the native home).
- `case_fresh` checks both the command's output and the resulting profile.json against goldens.

**Bug fixed in the old suite:** `NORM_AT` rewrote the kept profile.json in place. That made the exc-set-changed check ("new decidedAt") pass trivially whenever pwsh was present. It now normalizes a copy.

## CI steps for check.yml

macos (`runs-on: macos-15`):
```yaml
      - name: Profile resolver tests (.sh, bash 5)
        run: bash tests/profile/test-profile.sh
      - name: Profile resolver tests (.sh, macOS /bin/bash 3.2)
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-profile.sh --bash-only
      - name: Profile lib wrapper tests (.sh, bash 5)
        run: bash tests/profile/test-lib.sh
      - name: Profile lib wrapper tests (.sh, macOS /bin/bash 3.2)
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-lib.sh --bash-only
      - name: Installer Step 3/5 relay tests (.sh, bash 5)
        if: ${{ !cancelled() }}
        run: bash tests/profile/test-install.sh
      - name: Installer Step 3/5 relay tests (.sh, macOS /bin/bash 3.2)
        if: ${{ !cancelled() }}
        run: AITOOLS_TEST_BASH=/bin/bash /bin/bash tests/profile/test-install.sh --bash-only
```
linux (`runs-on: ubuntu-24.04`):
```yaml
      - name: Profile resolver tests (.sh, incl. claude-code-web)
        run: bash tests/profile/test-profile.sh
      - name: Profile lib wrapper tests (.sh)
        run: bash tests/profile/test-lib.sh
      - name: Installer Step 3/5 relay tests (.sh)
        if: ${{ !cancelled() }}
        run: bash tests/profile/test-install.sh
```
windows (`runs-on: windows-2022`; put these next to the b8 consumer step):
```yaml
      - name: Profile resolver tests (.ps1, native pwsh)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/profile/test-profile.sh
      - name: Profile lib wrapper tests (.ps1 + Git Bash pwsh branch)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/profile/test-lib.sh
      - name: Installer Step 3/5 relay tests (.ps1, native pwsh)
        if: ${{ !cancelled() }}
        shell: bash
        run: bash tests/profile/test-install.sh
```

## Cases that now run on one platform only, and why

- **rm-web** (Linux only, .sh, no golden): the claude-code-web environment exists only on Linux, and PowerShell never branches on the environment (cross-platform.md "Environment branches").
- **rev-m3-numbers** (.sh only): it checks that number literals are kept byte for byte. That is a perl-engine guarantee; aitools-profile.ps1's header says it re-formats non-integer literals. The ps1 half never ran this case before either.
- **jr-keep-out** (.sh only): it tests the perl engine's `edit` command.
- **a78-exc-ro, a8-mig-ro, a8-reg-ro** (.sh only): they rely on chmod 555 making a directory read-only, which chmod cannot do on Windows.
  - Coverage gap: before, these cases exercised the ps1 write-failure messages under pwsh on macOS. Now nothing tests them.
  - Suggested fix: provoke the write failure on Windows another way, for example a file where the directory should be (test-install already does this), in a B5 follow-up.
- **step3-unresolvable** (test-install, bash only, skipped on Windows).
- Help-text cases (`rev-help`, `usage-nocmd`): they run in the platform's one language with no golden, because each language prints its own help text.

## Things to watch in the first Windows CI run

These are unverified risks, not known failures:
1. **8.3 vs long temp-path names.** pwsh may spell the temp root as `RUNNER~1` where cygpath gives the long name, or the reverse. `from_native` would then miss the path, and path checks would fail. test-install's step3-relative check accepts either spelling.
2. **"No such file or directory" text** in a8-reg-nodir. On macOS the parity check showed the ps1 prints the same text as bash. On Windows .NET the text may differ.
3. **gitbash `via-pwsh-run-path-args`.** This is the lib's own UNVERIFIED claim that MSYS converts arguments and environment correctly. It is now actually tested on Windows.
4. **Line endings in written files.** The reg-update byte comparison assumes the ps1 writes LF on Windows, which its header says it does.
5. **Runtime.** About 190 pwsh starts in test-profile and about 200 in test-lib. The plan already marks per-case pwsh start cost as a follow-up.

## Proposed platform-lib.sh change

`from_native` is duplicated in all three suites, and S3-Cfg probably needs the same helper. I propose moving it into tests/lib/platform-lib.sh. This is a suggestion only: I did not apply it, because that file is outside my scope.

```diff
--- a/tests/lib/platform-lib.sh
+++ b/tests/lib/platform-lib.sh
@@ (after golden_match)
+# from_native FILE ROOT -- Windows: rewrite FILE in place, mapping the spellings
+# of ROOT that native programs print (C:/..., C:\..., JSON-escaped C:\\...,
+# /c/...) back to ROOT, with the separators after it turned into slashes; CRs
+# removed. A no-op off Windows.
+from_native() {
+    [ "$TEST_PLATFORM" = windows ] || return 0
+    FN_POSIX="$2" FN_NATIVE="$(native_path "$2")" perl -pi -e '
+        BEGIN {
+            my $n = $ENV{FN_NATIVE}; (my $b = $n) =~ s{/}{\\}g; (my $j = $b) =~ s{\\}{\\\\}g;
+            my $u = $n; $u =~ s{^([A-Za-z]):}{"/" . lc($1)}e;
+            @fn_re = map { qr/\Q$_\E/i } grep { length } ($j, $b, $n, $u);
+        }
+        s/\r//g;
+        for my $re (@fn_re) { s{$re([^\s"\x27|()]*)}{my $r = $1; $r =~ s{\\\\}{/}g; $r =~ tr{\\}{/}; "$ENV{FN_POSIX}$r"}ge; }
+    ' "$1"
+}
```

The suites would then call `from_native FILE "$WORK"`. Nothing under scripts/ needs to change.

## WRITE_BLOCKED, CONFLICT and INCIDENT lines

WRITE_BLOCKED: none. The standing-order guard refused two Bash calls (a `;` chain and a `cat`); I redid them through a scratch script and the Read tool.

CONFLICT: D-DEL4 (a code-change delegate opens its own PR) vs the commander's 2026-11-01 words "Branch + PR" (one PR, #139) and "Everything at once" -- resolved by tier 1: I pushed feature/ci-plat-prof and opened no PR.

CONFLICT: the prompt said to load /scratch at the start; I loaded it only at the end -- resolved by tier 2 (follow the prompt): I used the scratch directory the prompt named from the start and checked my work against the skill once loaded. It matched: session-S3-Prof is under 10 characters, commit messages are in commit-msg-*.txt, and scripts were written with the Write tool. The skill notes that a worktree's .scratch/ is not harvested unless a session starts there.

INCIDENT: none filed. One coverage regression is described under "Cases that now run on one platform only, and why": the Windows write-failure paths (A-7/A-8) now have no test.

## Open questions

1. **Should aitools-json.pl's edit engine also be tested on Windows?** build-deploy.sh runs it under Git Bash there. I suggest no, for now: it is the POSIX resolver's engine, and on Windows the suite already uses aitools-json.pl as a read-only checker. This could be revisited with plan item A1.
2. **Should the 3 POSIX-only goldens stay in the repo?** They are a78-exc-ro, a8-mig-ro and a8-reg-ro. I suggest keeping them: they still pin the macOS/Linux output, and a Windows version of those cases can reuse them once one exists.
3. **Should from_native move into platform-lib.sh?** I suggest yes, with the diff above, when the commander merges S3-Cfg too.

## Delegates

None.
