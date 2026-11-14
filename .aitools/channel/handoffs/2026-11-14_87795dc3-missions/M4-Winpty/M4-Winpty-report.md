# M4-Winpty report: pywinpty adopted as a managed Windows library on all three deployment paths

Version 1.0 (2026-11-14). Author: M4-Winpty, delegated by Session Commander 87795dc3-e.

**Intent**: **Purpose**: Record what mission M4-Winpty delivered and how it was verified,
and the decisions it leaves for the commander. **Scope**: the pywinpty adoption (pin, setup
scripts, registry, the three deployment paths, tests, CI), the local install on the
commander's workstation, verification evidence, open questions. NOT the code (PR #148). NOT the
evaluation (`reference/evaluations/pywinpty-windows-2026-11-13.md` v1.2). NOT registry data
(`/tool-registry` skill, entry `pywinpty`). **Audience**: the commander reviewing PR #148; the
session commander 87795dc3-e verifying the mission.

## Summary

1. pywinpty 3.1.2 is installed on this workstation (approved command), and the pty suites
   now run their interactive cases on Windows locally (no "pywinpty not installed" SKIP).
2. `scripts/setup-pywinpty.ps1` (install) and `.sh` (n/a), with the pin
   `scripts/requirements-pywinpty.txt` as the single source of truth, are wired into the
   dev path (Step 15b), the MDM path (pin embedded by build-deploy.sh) and the package path
   (no change needed: `scripts/` is in the payload and the package runs aitools-install.ps1).
3. The registry entry `pywinpty` records the pin as source of truth; platform status
   macOS n/a, Linux n/a, Windows supported.
4. CI installs pywinpty through the setup script; two new suites (`tests/pywinpty/`).
5. Open decision: the aitools-managed (uv) `python3` is EXTERNALLY-MANAGED, so on a machine
   whose only CPython is that one the script WARNs instead of installing.

## Deliverables

- PR: https://github.com/nobul-tech/aitools/pull/148, branch `feature/pywinpty-adopt`, base `main`.
- Commits (batches): 6feada2 pin move (A, M4-Winpty); 1332987 registry + evaluation v1.2 +
  tool-lifecycle rule (F, delegate M4-F-Registry); 867f6b9 setup scripts (B, delegate
  M4-B-Script); 110c280 TOOL_CMDS + tool-name row (G, M4-Winpty); a915cc7 installers +
  build-deploy + deploy-paths (D, delegate M4-D-Wire); 7af8fb8 tests + CI + build-time pin
  checks + RELEASE_NOTES v0.77.0 (E, delegate M4-E-Tests); 484927b merge of origin/main (#146).

## Local install on this workstation

- Command (commander, RFI fa81-7), from `C:\Users\jdpal\repos\aitools` on main:
  `python -m pip install --user --only-binary=:all: --require-hashes -r tests/managed-files/requirements-windows.txt`
  -> "Downloading pywinpty-3.1.2-cp314-cp314-win_amd64.whl (2.1 MB) ... Successfully installed pywinpty-3.1.2", exit 0.
- Interpreter: `python3` = `C:\Program Files\PyManager\python3.exe` -> `C:\Users\jdpal\AppData\Local\Python\pythoncore-3.14-64\python.exe`, CPython 3.14.6.
- Site: `C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages\winpty\__init__.py`.
- Probe `python tests\managed-files\winpty-probe.py "C:\Program Files\Git\usr\bin\bash.exe"`:
  `[git-bash CR] exit=0 out=['T0=yes', 'DEVTTY=yes', 'abc', 'GOT[abc]']`,
  `[pwsh CR] exit=0 out=['REDIRECTED=False', 'USERINTERACTIVE=True', 'abc', 'GOT[abc]']`.
- Suites: `test-managed-files.sh` 79 passed, 0 failed, 3 skipped (chmod, #564 64 KB diff,
  claude.md adopt on Windows -- none for pywinpty); `test-managed-files.ps1` 56/0/0.
- Real run of the finished `scripts/setup-pywinpty.ps1`: "pywinpty 3.1.2 verified (winpty at
  C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages\winpty\__init__.py)", exit 0.
- Rollback: `python -m pip uninstall -y pywinpty`.

## Verification

| What | Result |
|---|---|
| Pin hashes vs PyPI JSON API (raw JSON, python urllib, 2026-11-14) | 8 hashes = win_amd64 cp310, cp311, cp312, cp313, cp314, cp314t, cp315, cp315t; arm64 and sdist not pinned; latest 3.1.2 |
| setup-pywinpty.ps1 smoke (M4-B, 15 isolated cases) | dry run, install, verified, missing pin, no python, MDM embedded pin, uv EXTERNALLY-MANAGED, bad hashes, uncovered tag, unreadable pin: all as designed |
| Isolated MDM build (M4-D; HOME + dotprofile copy in scratch) | exit 0, 52 scripts; generated .ps1 run alone: "Pin: embedded in this script", "(installed)", "(verified)" |
| Package path | `build-package.sh stage --dry-run` and `all --version 0.0.0 --dry-run`: payload `git archive <commit> -- scripts shared reference registries .claude/rules .claude/skills`; design.md App B runs aitools-install.ps1 |
| tests/pywinpty/test-setup-pywinpty.ps1 (after merging main) | 31 passed, 0 failed, 0 skipped (windows, 28 s) |
| tests/pywinpty/test-setup-pywinpty.sh (after merging main) | 31 passed, 0 failed, 2 skipped (windows; POSIX-only cases); 54/0/0 with uname faked to Linux (M4-E) |
| managed-files suites (after merging main) | 79/0/3 and 56/0/0 |
| tests/os-guards | 34 passed, 0 failed |
| check-pre-commit.ps1 (after merge) | 6 PASS, 11 SKIP, 1 WARN, 1 FAIL: step 20 dead path refs, the 5 pre-existing ones (CLAUDE.md:100, reference/cursor-practices.md:43, reference/tool-registry.md:341/:354, shared/claude-shared.md:95), none in a file this branch touches |
| check-pre-push.ps1 (after merge) | 7 PASS, 0 SKIP, 3 WARN, 0 FAIL (step 7 rebuild passed) |
| CI on PR #148 | see "CI" below |

Delegates and how they were verified: M4-F-Registry (registry entry read in full by
M4-Winpty; JSON parses; diff adds only the entry and meta.lastUpdated); M4-B-Script (both
scripts read in full; real run on the workstation); M4-D-Wire (build-deploy and installer
diffs read; pre-push step 7 rebuild); M4-E-Tests (main checkout checked unchanged; pwsh suite
rerun by M4-Winpty: 31/0/0; both suites rerun after the merge).

## CI

Run 43547645144 on 484927b (https://github.com/nobul-tech/aitools/actions/runs/43547645144):
success on macos (job 132302579204), linux (132302579572) and windows (132302579494);
CodeQL run 43547498972 success. From the job logs:

- windows, install step: `[setup-pywinpty] [info] pip: Successfully installed pywinpty 3.1.2`,
  `summary: OK|pywinpty|3.1.2 (installed)`, import from
  `C:\Users\runneradmin\AppData\Roaming\Python\Python312\site-packages\winpty\__init__.py`;
  python3 on the runner is `C:\hostedtoolcache\windows\Python\3.12.10\x64\python3.exe` (cp312).
- windows, probe: `[git-bash CR] ... 'GOT[abc]'`, `[pwsh CR] ... 'GOT[abc]'`; managed-files
  79/0/3 and 56/0/0; `tests/pywinpty` .sh 31/0/2 (POSIX-only cases skipped with reason), .ps1
  31/0/0.
- linux: `tests/pywinpty/test-setup-pywinpty.sh` 54/0/0 (`OK|pywinpty|n/a (linux)`, nothing
  written under HOME).
- macos: 54/0/0 on bash 5.3.20 and 54/0/0 on /bin/bash 3.2.57.

The report commit itself triggers one more run; its result is in the final hand-back.

## Not run

- `setup-pywinpty.sh` and the .sh suite's dev/mdm cases on real macOS/Linux (CI).
- The installers end to end (agents never run `aitools install`; parser and review only).
- Real Intune/PKG/deb package builds (stubs today).
- `check-post-push` (runs after merge; its step 1 fails before merge by design).

## Decisions taken in this mission (not the commander's words)

- No Managed CLI Tools row (pywinpty is a library) -- session commander; written into
  `shared/rules/tool-lifecycle.md` "Managed libraries" for review.
- Platform skip wording `n/a (<platform>)`, not `write_environment_skip` (which prints the
  environment) -- M4-B-Script via /glossary.
- `AITOOLS_PYWINPTY_PYTHON` is both the test override and the documented remedy for an
  EXTERNALLY-MANAGED `python3` -- M4-Winpty.
- The import check runs before the tag/venv/marker checks (a verified install changes
  nothing, so it never WARNs) -- M4-Winpty.
- CI fails the install step on any non-OK row, so a WARN cannot turn into silent suite SKIPs.

## CONFLICT lines

- CONFLICT: /tool-adopt step 5 and /tool-registry step 2 "Managed CLI Tools row" vs the
  session commander's decision (library, no row) -- resolved by tier 2 (prompt): no row.
- CONFLICT: reference/script-standards-detail.md "Python package install pattern (uv-first)"
  (`uv pip --system`) vs the commander's approved command (`python -m pip install --user ...`)
  -- resolved by tier 1 (commander's words): pip --user (M4-B-Script).
- CONFLICT: shared/rules/tool-lifecycle.md "Lifecycle field completeness" (`pending` for an
  unverified platform version) vs the registry convention (`null`, n/a platforms) --
  resolved by tier 2 (prompt): `null` (M4-F-Registry).
- CONFLICT: design contract item 3 ACTION wording ("put a non-managed CPython first on PATH")
  vs setup-python.ps1, which warns when the uv shim is shadowed -- resolved by M4-Winpty's
  refinement (tier 2): the ACTION names `AITOOLS_PYWINPTY_PYTHON` instead.

## INCIDENT candidates (not filed)

- INCIDENT: tool-lifecycle "Lifecycle field completeness" says `pending`; every registry
  entry uses `null`; n/a platforms are not addressed (low).

## Open questions (with suggested answers)

1. **PEP 668 on an aitools-built machine.** Step 15 (`setup-python.ps1`, `uv python install
   --default`) makes `python3` the uv CPython, which carries EXTERNALLY-MANAGED; `python3 -m
   pip install --dry-run --user ... -r scripts/requirements-pywinpty.txt` exits 1 with
   "error: externally-managed-environment ... This Python installation is managed by uv and
   should not be modified." So on a fresh endpoint the script reports WARN + ACTION.
   Options: (a) keep WARN + ACTION; (b) `--target <user site>` for a managed interpreter
   (pip skips the check for `--target` by design: pip 25.3
   `pip/_internal/commands/install.py`, `check_externally_managed()` runs only when
   `target_dir`, `prefix_path` and `root_path` are None; uv's tree is untouched); (c)
   `--break-system-packages` together with `--user`. Suggested: (b) -- it needs the
   commander's explicit words, since it deliberately routes around a marker.
2. **win_arm64.** Not pinned; an ARM endpoint gets WARN "no wheel for cp3XY-win_arm64".
   Suggested: add the 8 arm64 hashes when an ARM Windows endpoint appears.
3. **Platform status "supported" with the limitation of Q1.** Suggested: keep it (the
   commander answered RFI fa81-5 "yes"; the limitation is in the registry notes and
   pendingChanges); revisit with Q1.
4. **Intune size.** `deploy/setup-pywinpty.ps1` is 246,923 bytes, over the 200 KB WARN, like
   24 other lib-inlined scripts. Suggested: leave to FX-35.
5. **Main checkout untracked files.** The main checkout has untracked `harvesting/` files from
   earlier sessions (git status at session start); not this mission's. Suggested: harvester.
