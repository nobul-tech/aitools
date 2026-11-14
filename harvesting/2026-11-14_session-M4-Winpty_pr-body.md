## Summary

pywinpty (the ConPTY backend of `tests/managed-files/pty-run.py`) becomes a managed Windows library on all three deployment paths:

- `scripts/setup-pywinpty.ps1` installs it into the Python user site with the approved command `python -m pip install --user --only-binary=:all: --require-hashes -r <pin>`. `scripts/setup-pywinpty.sh` reports `OK pywinpty n/a (<platform>)` on macOS and Linux.
- The pin `scripts/requirements-pywinpty.txt` is the single source of truth. It moved from `tests/managed-files/requirements-windows.txt` because `tests/` is not in the package payload.
- The tool registry entry `pywinpty` names the pin as the source of truth. Platform status: Windows supported, macOS and Linux n/a.
- Dev path: installer Step 15b. MDM path: `build-deploy.sh` embeds the pin in `deploy/setup-pywinpty.ps1`. Package path: `scripts/` is already in the payload and the package runs `aitools-install.ps1`, so nothing changed there.
- The CI windows job installs pywinpty through the setup script.

## Why

Commander, 2026-11-14 (session 87795dc3): "/tool-adopt pywinpty.  we will need setup-pywinpty.ps1.  document its source of truth in registry via /tool-registry.  mark windows/linux as N/A." RFI answers: "5) yes 6) agreed 7) yes, i stated i approved it 8) ... we should support pywinpty through all 3 methods of deployment/install".

## Changes

- **Pin.** `scripts/requirements-pywinpty.txt` (moved; `git mv`) has a new `# wheel-tags:` line. The 8 win_amd64 hashes, cp310 to cp315t, are unchanged; their mapping was re-read from https://pypi.org/pypi/pywinpty/3.1.2/json. References updated in `pty-run.py` (its install hint now names the setup script), `test-managed-files.sh`, `test-skills-fanout.sh` and `test-skills-legacy.sh`.
- **`scripts/setup-pywinpty.ps1`.**
  - Pin: `AITOOLS_PYWINPTY_PIN`, then the file beside the script, then the embedded `$AitoolsEmbeddedPywinptyPin`.
  - Interpreter: `python3`, then `python`; `AITOOLS_PYWINPTY_PYTHON` overrides.
  - Order of checks:
    1. Import check: OK verified, nothing written.
    2. Wheel-tag coverage.
    3. venv and EXTERNALLY-MANAGED checks: WARN + ACTION. It never passes `--break-system-packages` or `--target`.
    4. Dry run.
    5. pip install.
    6. Import verify.
  - No Python: WARN + ACTION, exit 0.
- **`scripts/setup-pywinpty.sh`**: one OK row, `n/a (<platform>)`. The wording names the platform, not the environment (/glossary), so `write_environment_skip` is not used.
- **`scripts/aitools-install.ps1` / `.sh`**: Step 15b, right after Step 15 Python.
- **`scripts/build-deploy.sh`**: a copy block pair. The `.ps1` gets the pin as a here-string after the inlined lib. The build fails on a pin that is missing or empty, has no `pywinpty==` line, has a `'@` line, no `# wheel-tags:` line, or no `--hash`.
- **Registry**: `tools.pywinpty` (schema 1.0, through /tool-registry); `meta.lastUpdated`.
- **`shared/rules/tool-lifecycle.md`**: new "Managed libraries" subsection.
- **`.claude/rules/deploy-paths.md`** (and its `.cursor/rules/deploy-paths.mdc` mirror): setup-pywinpty is copy + embed.
- **`scripts/check-post-push.sh/.ps1`**: `TOOL_CMDS` gets `pywinpty`, checked with a package-metadata command. **`reference/script-standards-detail.md`**: tool name `pywinpty`.
- **`reference/evaluations/pywinpty-windows-2026-11-13.md`**: v1.2.
- **`tests/pywinpty/test-setup-pywinpty.sh`** (linux, macOS bash 5 and 3.2, Windows Git Bash) and **`.ps1`** (Windows). `check.yml` steps for both (FO-0).
- **`check.yml`, windows job**: `scripts/setup-pywinpty.ps1` replaces the raw pip step. The step fails unless the script exits 0 with only OK rows and `python3` then imports winpty.
- **`RELEASE_NOTES.md`**: v0.77.0.
- **Mission report**: `.aitools/channel/handoffs/2026-11-14_87795dc3-missions/M4-Winpty/M4-Winpty-report.md`.

## Verification

All on Windows 11, pwsh 7, Git Bash 5.3.15.

- **Local install (approved by the commander, RFI fa81-7):**
  - pip: `Successfully installed pywinpty-3.1.2` (cp314 wheel) into `C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages`. `python3` is PyManager CPython 3.14.6.
  - `winpty-probe.py` section 3: `[git-bash CR] ... 'T0=yes', 'DEVTTY=yes', ... 'GOT[abc]'` and `[pwsh CR] ... 'GOT[abc]'`.
  - managed-files suites: bash 79 passed, 0 failed, 3 skipped (none for pywinpty); pwsh 56/0/0.
  - The real run of `setup-pywinpty.ps1` on the workstation: `pywinpty 3.1.2 verified`, exit 0.
- **New suites:** `.ps1` 31/0/0 (rerun by the orchestrator); `.sh` 31/0/2 on Windows (the 2 skips are POSIX-only cases), and 54/0/0 with `uname` faked to Linux.
- **Other suites:** `tests/os-guards` 34 passed.
- **Isolated MDM build** (HOME and a dotprofile copy in scratch): exit 0, 52 scripts. The generated `setup-pywinpty.ps1`, run alone from a temp dir, gave: dry run "Pin: embedded in this script", then "3.1.2 (installed)", then "3.1.2 (verified)".
- **Package path:** `build-package.sh stage --dry-run` and `all --version 0.0.0 --dry-run` both plan `git archive <commit> -- scripts shared reference registries .claude/rules .claude/skills`.
- **Checks:** `check-pre-commit.ps1` and `check-pre-push.ps1` from the worktree. The results after the merge with main are in the mission report.
- **CI:** see the checks on this PR.

## Not run

- `setup-pywinpty.sh` and the `.sh` suite's dev/mdm cases on real macOS or Linux (CI covers them).
- The whole installers (`aitools install`): agents never run them; they were checked by parser and review.
- A real Intune, PKG or deb package build (those are stubs today).
- A non-dry `build-deploy.sh` against the real dotprofile.

## Review after (D-DEL5: each change old -> new)

- **Registry:** `tools.pywinpty` none -> added; `meta.lastUpdated` 2026-11-13 -> 2026-11-14.
  - `platformStatus` {macos n/a, linux n/a, windows supported}.
  - install.windows: pip `--user --only-binary=:all: --require-hashes -r scripts/requirements-pywinpty.txt`.
  - health.windows: yellow.
  - versions.windows: 3.1.2 / 2026-11-14.
  - setupScript names the pin as the source of truth.
  - pendingChanges records the PEP 668 decision (section "PEP 668").
- **`shared/rules/tool-lifecycle.md`:**
  - Implement list: "`@shared/claude-shared.md` — Managed CLI Tools table" -> "... (not for a managed library)".
  - New subsection "#### Managed libraries" (none -> 9 lines): a library gets no Managed CLI Tools rows; its TOOL_CMDS check is an import/metadata command; its pin is the source of truth the registry names. This is a session-commander decision, pending your review.
- **`.claude/rules/deploy-paths.md`** (+ `.mdc` mirror):
  - none -> "`setup-pywinpty.ps1` is **copy + embed**: copied with the library inlined, plus only its pin data after the library (`$AitoolsEmbeddedPywinptyPin`); no setup logic is duplicated, and a missing or malformed pin fails the build."
  - none -> the auto-embedded bullet "`scripts/requirements-pywinpty.txt` → the pin, embedded in `deploy/setup-pywinpty.ps1` (used only when no pin file sits beside the script)".
- **Evaluation doc** v1.1 -> v1.2:
  - Phase 2 "not installed" -> "approved 2026-11-14, installed".
  - Section 7 "No tool-registry entry recommended" -> superseded by your order.
  - New finding: the uv-managed python3 is EXTERNALLY-MANAGED.
- **Pin path:** `tests/managed-files/requirements-windows.txt` -> `scripts/requirements-pywinpty.txt`, plus the `# wheel-tags:` line.
- **CI windows step:** `python -m pip install --require-hashes -r ...` -> `pwsh -File scripts/setup-pywinpty.ps1` with the OK-rows and import assertions.
- **TOOL_CMDS:** none -> `'pywinpty': python3 -c "import importlib.metadata as m; print(m.version('pywinpty'))"` (sh + ps1).
- **Installers:** none -> Step 15b. **build-deploy:** none -> the setup-pywinpty copy + embed block.
- **No Managed CLI Tools row** (in `shared/claude-shared.md` or the dotprofile). This overrides /tool-adopt step 5, because pywinpty is a library.
- **PEP 668 (commit after the first review round):**
  - `setup-pywinpty.ps1`, EXTERNALLY-MANAGED interpreter: WARN "python externally managed" + ACTION (no install) -> `pip install --target <its user site> --upgrade --only-binary=:all: --require-hashes -r <pin>`, stale `pywinpty-*.dist-info` of other versions removed, import verify, OK "3.1.2 (installed, --target)"; WARN "managed python, no user site" + ACTION only when its user site is disabled or inside its install tree. Unmanaged interpreters: `--user`, unchanged.
  - Registry `pywinpty`: install.windows notes, notes, setupScript.platforms.windows, platformGotchas, nonPreferredMethods (uv) reason: "WARN + ACTION / remedy AITOOLS_PYWINPTY_PYTHON" -> "--target into the interpreter's user site"; `evaluation.pendingChanges` "decision pending" -> "decided (RFI fa81-9)"; `lifecycle.dependencies` drops "A non-managed CPython of the same minor ..."; antiPattern "installing into a uv-managed interpreter" -> "writing into a uv-managed interpreter's install tree".
  - Evaluation doc v1.2 -> v1.3 (changelog line; section 4 "Finding" and section 8 unknown 4 marked decided).
  - RELEASE_NOTES v0.77.0: item 1 and "Known limitation" -> "PEP 668" paragraph.
  - `tests/pywinpty/test-setup-pywinpty.ps1`: the externally-managed case now expects `--target`; new cases (see Verification).

## PEP 668

Commander, 2026-11-14 (RFI fa81-9, verbatim): "fix pep, add it to same branch commit, watch ci/cd, fix any errors, merge when ready".

- aitools Step 15 (`setup-python.ps1`, `uv python install --default`) makes `python3` the uv-managed CPython. That interpreter carries EXTERNALLY-MANAGED, and pip refuses `--user` there: `error: externally-managed-environment ... This Python installation is managed by uv and should not be modified.`
- For such an interpreter, `setup-pywinpty.ps1` now installs with `pip install --target <that interpreter's user site> --upgrade ...`.
  - pip skips its PEP 668 check for `--target` by design. Verified in pip 25.3, `pip/_internal/commands/install.py`: `check_externally_managed()` runs only when `target_dir`, `prefix_path` and `root_path` are all None.
  - The user site (`%APPDATA%\Python\Python3XY\site-packages`) is outside uv's install tree and on that interpreter's `sys.path`.
  - `--upgrade` replaces an existing pywinpty. Stale `pywinpty-*.dist-info` directories of other versions are removed, then the install is verified by import.
  - Never `--break-system-packages`. Refused with WARN + ACTION when the user site is disabled or inside the install tree.
- If the probe finds no marker but pip still says externally-managed-environment, the script switches to `--target` once, under the same conditions.
- Verified against uv CPython 3.14.10 on the workstation, with an isolated APPDATA:
  - dry run shows the `--target` command;
  - install gives `OK|pywinpty|3.1.2 (installed, --target)`;
  - a re-run gives `(verified)`;
  - a seeded `pywinpty-3.1.1.dist-info` is replaced and removed;
  - `PYTHONNOUSERSITE=1` gives `WARN|pywinpty|managed python, no user site`;
  - uv's `Lib\site-packages` is unchanged: no winpty, 3 entries before and after.
- Then a real run on the workstation (PyManager `python3`) reports "pywinpty 3.1.2 verified".

## Follow-ups

1. ~~Decision needed (PEP 668)~~ -- decided and implemented in this PR: see "PEP 668" above.
2. `win_arm64` hashes are not pinned. Add them when an ARM Windows endpoint appears.
3. `deploy/setup-pywinpty.ps1` is 246,923 bytes, over the Intune 200 KB WARN. This is the same pre-existing condition as the other lib-inlined scripts (FX-35).
4. INCIDENT candidate (low): the tool-lifecycle "Lifecycle field completeness" rule says `pending` for an unverified platform version, but every registry entry uses `null`, and n/a platforms are not addressed.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
