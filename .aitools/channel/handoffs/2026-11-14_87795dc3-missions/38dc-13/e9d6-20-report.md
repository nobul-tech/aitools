# e9d6-20 report: POSIX guard on tests/logging/test-logging.sh and tests/menus/test-menu-choice.sh

Version 1.0, 2026-11-14. Author: e9d6-20-guard-log-menus-sh (delegate of
38dc-13-windows-ci-ps1-only, under M6-Polish, Session Commander 87795dc3-e). Worktree
`.claude/worktrees/38dc-13`. Nothing staged, committed or pushed.

**Intent**: **Purpose**: report the guard added to the two bash suites, every Windows branch
removed as dead, the SKIP and header changes, and the verification. **Scope**:
`tests/logging/test-logging.sh`, `tests/menus/test-menu-choice.sh`. NOT their `.ps1` twins,
check.yml, cross-platform.md or other suites. **Audience**: 38dc-13.

## Summary

1. Both suites carry the test-suite POSIX guard (uname case + `BASH_VERSINFO[5]` case),
   copied from the brief and the rule (cross-platform.md "Test suites"), first after
   `set -uo pipefail`, before `--help` and `mktemp`. The message names the `.ps1` twin.
2. Removed every Windows branch: test-logging.sh's `ENTRY_RUNS` gate (1 case, 1 SKIP, 1 `fi`);
   test-menu-choice.sh's `IS_WINDOWS` + pywinpty probe, `tty_occ`'s ConPTY "minimum count"
   branch, and two `if ! $IS_WINDOWS` wrappers.
3. On macOS/Linux, the same cases, check names, order and output. The only text change is
   the two pty SKIP lines in test-menu-choice.sh, which print only when python3 is missing.
4. `bash -n` clean on both; plain refusal run of each: exit 1, guard message on stderr,
   0 bytes on stdout, no new `/tmp` entry; `classify-guards.pl`: `posix` for both.
5. The suites were not run past their guards. Their evidence is the macOS and Linux CI jobs.
   check.yml's windows job still runs both `.sh` suites (check.yml lines 759, 803), which
   now exit 1. 38dc-13 removes those steps.

## 1. tests/logging/test-logging.sh

**Guard** (lines 18-30, after `set -uo pipefail` on line 16):

```
# OS guard: macOS/Linux only. BASH_VERSINFO[5] is bash's compiled-in machine
# type (read-only, never taken from the environment), so neither a uname shim
# on PATH nor an exported OSTYPE hides Git Bash.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        printf 'This script is for macOS/Linux. On Windows, run tests/logging/test-logging.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
case "${BASH_VERSINFO[5]:-}" in
    *-msys*|*-cygwin*|*-mingw*)
        printf 'This script is for macOS/Linux. On Windows, run tests/logging/test-logging.ps1 with pwsh.\n' >&2
        exit 1 ;;
esac
```

**Removed** (each unreachable on macOS/Linux):

| Removed | Why it could never run on macOS/Linux |
|---|---|
| `case "$(uname -s)" in MINGW*\|MSYS*\|CYGWIN*) ENTRY_RUNS=false ;; *) ENTRY_RUNS=true ;; esac` | `uname -s` is `Darwin` / `Linux` there, so `ENTRY_RUNS` was always `true` |
| `if ! $ENTRY_RUNS; then printf 'SKIP entry: 7 pre-lib and argument cases (Windows: scripts/aitools forwards to aitools.ps1)\n' else` and the closing `fi` | the SKIP branch needed `ENTRY_RUNS=false` (Git Bash only). The 7 entry checks in the `else` body are now unwrapped at top level, with the same code and order (the body was not indented, so only the 3 wrapper lines and `fi` went) |

The comment above the entry cases is shorter now. It says that on Windows `scripts/aitools`
hands off to `aitools.ps1` before this code runs (commander, 2026-11-14, RFI 38dc-3), and
that `tests/aitools-entry/test-win-forwarder.ps1` covers that path.

**SKIP texts old -> new**: `SKIP entry: 7 pre-lib and argument cases (Windows: scripts/aitools
forwards to aitools.ps1)` -> removed (it printed only on Windows).

**Header**: Platform paragraph old: "Platform: macOS, Linux, Windows (Git Bash); the
scripts/aitools run cases are macOS/Linux only (on Windows it forwards to aitools.ps1). Exit 1
if any case fails." New: "Platform: macOS, Linux (OS guard below; commander, 2026-11-14: "sh
scripts and tests should only run on linux/mac and ps1 on windows"). On Windows,
tests/logging/test-logging.ps1 tests the PowerShell side (aitools-lib.ps1, check-lib.ps1,
scripts/aitools.ps1). Exit 1 if any case fails." The header grew by 2 lines, so `--help`
went from `sed -n '2,12p'` to `sed -n '2,14p'`. Line 14 is `# Usage: ...`, the last line
of the old range (verified with perl, without running the suite). The scope of the `.ps1`
twin comes from its own header (test-logging.ps1 lines 1-2, 5-8).

## 2. tests/menus/test-menu-choice.sh

**Guard**: same two-case form, lines 44-56 (after `set -uo pipefail` on line 42). The
message is "This script is for macOS/Linux. On Windows, run tests/menus/test-menu-choice.ps1
with pwsh."

**Removed**:

| Removed | Why it could never run on macOS/Linux |
|---|---|
| `IS_WINDOWS=false` | only the MINGW/MSYS/CYGWIN case set it to `true` |
| `case "$(uname -s)" in MINGW*\|MSYS*\|CYGWIN*) IS_WINDOWS=true; # Windows pty = pywinpty (ConPTY)...; if $HAVE_PTY && ! python3 -c 'import winpty' ...; then HAVE_PTY=false; fi ;; esac` | a uname case that matches only Git Bash/MSYS/Cygwin; on macOS/Linux HAVE_PTY depends only on `command -v python3` (kept) |
| `tty_occ`: `if $IS_WINDOWS && [ "$1" -gt 0 ]; then <-ge count> else occ_is ...; fi` and its 3-line ConPTY comment -> `tty_occ() { occ_is "$1" "$2" "$C/plain"; }` | `IS_WINDOWS` was false, so `tty_occ` always ran `occ_is "$1" "$2" "$C/plain"`, which it still does |
| `if ! $IS_WINDOWS; then` / `# ConPTY re-renders lines...` / `fi` around "re-ask: hint on its own line" | the condition was always true; the check is kept and runs as before (re-indented) |
| `if ! $IS_WINDOWS; then` / `# ConPTY may repeat lines...` / `fi` around "text review (adopt): re-ask prints the hint and the prompt, not the menu again" | the same; the check is kept |

Kept: the comment "A trailing CR (Windows line ending) is trimmed" (line 212). That case
tests the library's CR trim with a stubbed `read_tty_choice` and runs on every POSIX
platform. `AITOOLS_TEST_BASH` (check.yml line 120, the macOS `/bin/bash` 3.2 run) is
unchanged.

**SKIP texts old -> new** (both can print on macOS/Linux when python3 is missing; the
pywinpty half applied only to Windows):
- `SKIP pty cases (no pseudo-terminal: python3 missing, or pywinpty not installed on Windows)`
  -> `SKIP pty cases (no pseudo-terminal: python3 missing)`
- `SKIP real-menu pty cases (no pseudo-terminal: python3 missing, or pywinpty not installed on
  Windows)` -> `SKIP real-menu pty cases (no pseudo-terminal: python3 missing)`

Nothing else in the repo parses these texts. A grep of the worktree for "pywinpty not
installed" finds only other suites, reports and an evaluation doc.

**Header**: old: "...Without a pty (python3 missing, or pywinpty not installed on Windows)
the pty cases SKIP with the reason. The JSON cases need node (SKIP without it). / Platform:
macOS, Linux, Windows Git Bash (aitools-lib.sh also runs there)." New: "...Without a pty
(python3 missing) the pty cases SKIP with the reason. The JSON cases need node (SKIP without
it). / Platform: macOS, Linux (OS guard below; commander, 2026-11-14: "sh scripts and tests
should only run on linux/mac and ps1 on windows"). On Windows, tests/menus/test-menu-choice.ps1
tests the PowerShell side (aitools-lib.ps1)." The header grew by 1 line, so `--help` went
from `$. <= 39` to `$. <= 40`. Line 40 is `# Usage: ...`, as line 39 was before.

## 3. Verification (Windows 11, Git for Windows bash; tested: Windows, refusal only)

Script: `.scratch/session-e9d6-20/verify.sh` (one Bash call). Environment as reported:
`uname -s` = `MINGW64_NT-10.0-26300`, `BASH_VERSINFO[5]` = `x86_64-pc-cygwin`. Nothing
was spoofed.

| Check | Result |
|---|---|
| `bash -n` each file | rc 0, no output, both |
| CR bytes | 0 in both (LF kept) |
| `bash tests/logging/test-logging.sh` | rc 1; stdout 0 bytes; stderr `This script is for macOS/Linux. On Windows, run tests/logging/test-logging.ps1 with pwsh.`; 0 new entries in `/tmp` (mktemp's parent; TMPDIR unset) |
| `bash tests/menus/test-menu-choice.sh` | rc 1; stdout 0 bytes; stderr `This script is for macOS/Linux. On Windows, run tests/menus/test-menu-choice.ps1 with pwsh.`; 0 new entries in `/tmp` |
| `perl tests/os-guards/classify-guards.pl W W/.claude/rules/cross-platform.md <list>` | `posix tests/logging/test-logging.sh`, `posix tests/menus/test-menu-choice.sh`, rc 0 |
| `git status --short tests/logging tests/menus` | ` M` on the two `.sh` files only |
| file mode | 100755 both (`git ls-files -s`) |
| `git diff --stat` | test-logging.sh 38 lines changed, test-menu-choice.sh 61 (50 insertions, 49 deletions) |

On Windows only the uname case can be shown to refuse, because it fires first. The
`BASH_VERSINFO[5]` case is checked only by the classifier regex, since spoofing is not
allowed. Bash 3.2: the only new construct is `${BASH_VERSINFO[5]:-}`, and BASH_VERSINFO
exists in bash 3.2. The macOS `/bin/bash` CI step (check.yml line 120) runs it.

**Not run**: either suite past its guard. That evidence comes from the macOS and Linux CI
jobs. I ran no `.ps1` twin (out of scope and unchanged).

## Lines for 38dc-13

- WRITE_BLOCKED: none.
- CONFLICT: brief "keep the macOS/Linux behaviour identical (... same output)" vs the brief's
  "a SKIP text that can fire on macOS/Linux and also mentions Windows may be trimmed" --
  resolved by tier 2 (the prompt's specific permission): the two pty SKIP texts are trimmed.
  This changes output only when python3 is missing, never in CI.
- INCIDENT (process, mine, self-corrected): my first Write of this report went to the
  **main checkout** (`C:\Users\jdpal\repos\aitools\.aitools\channel\handoffs\2026-11-14_87795dc3-missions\38dc-13\e9d6-20-report.md`,
  content "placeholder"), which is read-only under my access. The tool reported "File
  created", so the file did not exist before. I removed it at once with `rm` on that one
  path, and `git -C <main> status --short .aitools/channel/handoffs/2026-11-14_87795dc3-missions`
  is empty. The directory `.../2026-11-14_87795dc3-missions/38dc-13/` is still in the main
  checkout and is empty. Its timestamps (15:20) match my write, but I cannot prove the
  write created it, so I left it. Git does not track empty directories. Suggested: remove
  it if no 38dc-13 work expects it there (`rmdir` on that one path).
- Note: check.yml windows-job steps `bash tests/logging/test-logging.sh` (line 759) and
  `bash tests/menus/test-menu-choice.sh` (line 803) now fail with exit 1, and
  `scripts/check-ci-suites.pl` should flag a POSIX-guarded `.sh` in the windows job. The
  cross-platform.md row "Test suites pending a decision" is stale. Both are 38dc-13's,
  per the brief.

## Open questions (each with a suggested answer)

- Q1. The `.ps1` twin of test-menu-choice still prints "(no pseudo-terminal: python3 missing,
  or pywinpty not installed on Windows)" (ps1 line 538). Suggested: keep it, because both
  reasons apply on Windows.
- Q2. The same pywinpty SKIP text is still in other POSIX-guarded `.sh` suites
  (test-managed-files.sh 283, test-adopt-push.sh 234, test-deploy-harness.sh 306,
  test-user-init.sh 673). Suggested: trim them the same way in one follow-up, which closes
  e9d6-13's Q1.
