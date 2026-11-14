# Evaluation: pywinpty as a local Windows test dependency — Windows 11 workstation — 2026-11-13

Version 1.1 (2026-11-13). Author: M3-Fixes-D (delegate of M3-Fixes, Session Commander
87795dc3-e). Phase 2 gate: **not installed**; the install, test and rollback commands
below wait for the commander's approval.

v1.1 (M3-Fixes): the follow-up in section 6 is done in the same PR --
`tests/managed-files/requirements-windows.txt` now pins every 3.1.2 win_amd64 wheel
(cp310-cp315, incl. free-threaded; hashes re-read from the PyPI JSON API by M3-Fixes), so
the proposed command uses that file instead of a temporary one-line file. Sections 1 and
4 describe the file as it was before this PR.

**Intent**: **Purpose**: Preserve the evaluation of pywinpty for running the interactive
pty test cases locally on the commander's Windows workstation, and the proposed install,
test and rollback commands for the Phase 2 decision. **Scope**: provenance, official
source, maintenance, licence, how CI's windows job gets it, this workstation's Python
facts, local install options, hard blocks and yellow flags, recommendation. NOT the CI
adoption itself (S2-Winpty, 2026-11-01, recorded in
`tests/managed-files/requirements-windows.txt` and `plans/ci-platform-targeting.md`). NOT
integration code (setup scripts, installer steps, `build-deploy.sh`). NOT registry data
(`/tool-registry` skill). **Audience**: the orchestrator M3-Fixes, the commander at the
Phase 2 gate, and agents re-evaluating pywinpty.

Method: web sources read with the chrome-devtools MCP (PyPI JSON API, PyPI project page,
pypistats, the upstream CHANGELOG), GitHub facts with `gh api`, local facts with read-only
commands (`python --version`, `python -m pip show`, `python -m pip index versions`,
`uv python list`, an empty `uv venv` in scratch to see which executables it creates).
Nothing was installed or downloaded.

## Summary

1. **No hard block.** Same verdict as the CI evaluation of 2026-11-01 (S2-Winpty). The CI
   pin, 3.1.2, is still the latest release (2026-10-28); both CI hashes match PyPI.
2. **The CI requirements file does not install on this workstation.** It pins only the
   cp312 and cp313 win_amd64 wheels; this workstation's `python3` is CPython 3.14.6, which
   needs the cp314 wheel, whose hash is not in the file. Under `--require-hashes` pip
   rejects the cp314 wheel (expected; not run, installs are forbidden before the gate).
3. **The test suites call `python3` from PATH** (Git Bash and pwsh alike). On this machine
   that is PyManager's `python3.exe` -> `pythoncore-3.14-64` 3.14.6. A venv does not help:
   a Windows venv (uv 0.13.8, probed) has `python.exe` but no `python3.exe`.
4. **Recommended: a user-site install (`pip install --user`) of the cp314 win_amd64 wheel,
   hash-pinned.** Both 3.14 interpreters on this machine (PyManager 3.14.6 and uv 3.14.10)
   share the user site `%APPDATA%\Python\Python314\site-packages`, so it survives a PATH
   order change and a 3.14 patch upgrade. Follow-up: add the cp314 hashes to
   `requirements-windows.txt` so CI and local share one pinned file.
5. **Yellow flags** (unchanged in kind from 2026-11-01): sole maintainer on a personal
   account; 164 stars; plus, new here: upstream recommends conda first; no PyPI
   provenance attestations; no SECURITY.md.

## 1. What CI does today

| Item | Value | Source |
|---|---|---|
| Runner | `windows-2022` | `.github/workflows/check.yml`, job `windows` |
| Python | 3.12 via `actions/setup-python@v7.0.0` | check.yml, step "Set up Python 3.12" |
| Install | `python -m pip install --require-hashes -r tests/managed-files/requirements-windows.txt` (pwsh) | check.yml, step "Install Windows test dependencies (pywinpty, hash-pinned)" |
| Probe | `python tests/managed-files/winpty-probe.py "$(cygpath -w "$BASH")"` | check.yml, step "Windows runner probe" |
| Pin | `pywinpty==3.1.2` with 2 hashes | `tests/managed-files/requirements-windows.txt` |
| Decision | Commander, 2026-11-01: "Adopt, spike first"; S2-Winpty /tool-eval: no hard block, yellow flags (sole maintainer on a personal account, 164 stars) | requirements-windows.txt header; `plans/ci-platform-targeting.md` order 6, batch B6 ("done: pywinpty 3.1.2, hash-pinned, CI-only") |
| Release note | v0.75.0: "installed only on the CI runner (evaluated 2026-11-01: adopted with yellow flags, sole maintainer and low adoption)" | `RELEASE_NOTES.md` |

The S2-Winpty evaluation itself was never written to `reference/evaluations/` (no file
existed before this one); its conclusions survive only in the requirements-file header,
the plan and the release note. This file is the first evaluation document for pywinpty.

### Hash check (PyPI JSON API, read 2026-11-13)

Source: https://pypi.org/pypi/pywinpty/3.1.2/json (read in the browser).

| Hash in requirements-windows.txt | PyPI file | Match |
|---|---|---|
| `220e30a8cccd7f0be3356d4e3e56fdcda2ae45edc1de526b440c4031fe9308da` | `pywinpty-3.1.2-cp312-cp312-win_amd64.whl` | yes |
| `d968dc4300b497f048318387781ed9931dc0038815f25b4f642a1749448769cb` | `pywinpty-3.1.2-cp313-cp313-win_amd64.whl` | yes |

Files of 3.1.2 not covered by the requirements file (17 files on PyPI, all uploaded
2026-10-28, none yanked): cp310, cp311 (amd64, arm64); cp312, cp313 arm64; cp314
(amd64, arm64); cp314t (free-threaded); cp315, cp315t; the sdist. The one this
workstation needs:

| File | sha256 |
|---|---|
| `pywinpty-3.1.2-cp314-cp314-win_amd64.whl` | `980af688956fe78c87882682732e6eea45aa0b8d10a9628812e95878264d5204` |

`python -m pip debug --verbose` on this machine lists `cp314-cp314-win_amd64` among the
compatible tags.

## 2. Provenance and maintenance

| Check | Finding | Source |
|---|---|---|
| Package | `pywinpty` 3.1.2, "Pseudo terminal support for Windows from Python." | PyPI JSON |
| Latest version | 3.1.2 (released 2026-10-28); `pip index versions pywinpty` lists 3.1.2 first | PyPI JSON; local command |
| Author / PyPI maintainers | Edgar Margffoy (andfoy@gmail.com); PyPI shows "1 maintainer": `andfoy` | PyPI JSON; https://pypi.org/project/pywinpty/ |
| Repository | https://github.com/andfoy/pywinpty (linked from PyPI "Repository") | PyPI JSON `project_urls` |
| Owner type | `User` (personal account); not a fork (`fork: false`); created 2017-06-02; not archived | `gh api repos/andfoy/pywinpty` |
| Lineage | Description: "Copyright © 2017–2022 Spyder Project Contributors Copyright © 2022– Edgar Andrés Margffoy Tuay" | PyPI project page |
| Stars / forks / open issues | 164 / 35 / 25 | `gh api` |
| Last push / last commits | 2026-10-28 ("Release v3.1.2", "Merge pull request #592 ... bump-winpty-rs-1.0.8") | `gh api .../commits` |
| Releases | v3.1.2 2026-10-28, v3.1.1 2026-10-27, v3.1.0 2026-10-15, v3.0.5 2026-06-10, v3.0.4 2026-06-10, v3.0.3 2026-02-04 | `gh api .../releases` |
| Contributors | andfoy 782, dependabot[bot] 121, goanpeca 16, ccordoba12 15, ngoldbaum 8, others <= 5 | `gh api .../contributors` |
| Licence | MIT (`LICENSE.txt`; classifier "OSI Approved :: MIT License") | `gh api .../license`; PyPI JSON |
| Security advisories | 0 repository advisories; 0 GitHub global advisories for pip/pywinpty; PyPI `vulnerabilities: []` | `gh api`; PyPI JSON |
| SECURITY.md | absent (404) | `gh api .../contents/SECURITY.md` |
| PyPI provenance | "No provenance found. None of the files in this release were uploaded with provenance metadata." | PyPI project page, "Provenance" |
| Dependencies | none (`requires_dist: null`); `requires_python >=3.10` | PyPI JSON |
| Adoption | 2,452,362 downloads last month (526,638 last week) | https://pypistats.org/packages/pywinpty |
| Dependants | `terminado` 0.18.1 requires `pywinpty>=1.1.0; os_name == 'nt'` | https://pypi.org/pypi/terminado/json |
| Classifiers | "Development Status :: 5 - Production/Stable", "Operating System :: Microsoft :: Windows", "Programming Language :: Rust" | PyPI JSON |

### Official install methods

PyPI project description (verbatim): "You can install this library by using conda or pip
package managers, as it follows: Using conda (Recommended): `conda install pywinpty` Using
pip: `pip install pywinpty`". Building from source needs a Rust toolchain
(`x86_64-pc-windows-msvc`) and maturin.

| Method | Official? | Elevation | Fits aitools | Note |
|---|---|---|---|---|
| conda | yes, "Recommended" | no | no | aitools manages no conda; adding conda for one test library is out of proportion |
| pip, binary wheel | yes, documented | no | yes | pip is the documented non-conda path; wheels exist for cp310-cp315 amd64/arm64 |
| pip, sdist (Rust build) | yes, "Building from source" | no | no | needs Rust + maturin; avoided with `--only-binary=:all:` and the wheel hash |

### Relevant upstream changes since the CI evaluation

CHANGELOG (https://raw.githubusercontent.com/andfoy/pywinpty/main/CHANGELOG.md), "Version
3.1.2 (2026/10/28)": "Require winpty-rs 1.0.8, which makes EOF detection work and fixes
spawning an executable whose path contains a space." "Closing a PTY no longer waits out a
fixed five seconds." "**Still not fixed:** the output *truncation* half of #565 is
cpython#86210". No release after 3.1.2 as of 2026-11-13, so the CI pin is current.

Open upstream issue that the test suites already work around: #564 "Producer-dependent
poor throughput and tiny read fragments for large output on ConPTY" (open, updated
2026-03-30). `tests/managed-files/test-managed-files.sh` skips its ~330 KB diff case on
Windows for this reason, so one SKIP line remains on Windows by design.

## 3. This workstation (read-only facts, 2026-11-13)

| Fact | Value |
|---|---|
| `python` (pwsh, first on PATH) | `C:\Program Files\PyManager\python.exe` -> `C:\Users\jdpal\AppData\Local\Python\pythoncore-3.14-64\python.exe`, 3.14.6, AMD64, `win-amd64` |
| `python3` (pwsh and Git Bash, first on PATH) | `C:\Program Files\PyManager\python3.exe` -> the same 3.14.6 interpreter |
| Other `python3` on PATH | `...\Microsoft\WindowsApps\python3.exe` (second), `C:\Users\jdpal\.local\bin\python3.exe` (third; uv shim -> uv CPython 3.14.10) |
| pip | 26.1.2 (pythoncore-3.14-64); no `pip.exe` on PATH; `pip config list` empty; no `PIP_*` variables. The update notice printed "25.3 -> 26.3" (inconsistent with 26.1.2; cause unknown, not material) |
| pywinpty | not installed (`pip show pywinpty`: "Package(s) not found"; `import winpty`: ModuleNotFoundError, in pwsh and Git Bash) |
| User site | `C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages` (enabled; directory does not exist yet). The same path for PyManager 3.14.6, the uv shim 3.14.10 and uv's `cpython-3.14.10` |
| `EXTERNALLY-MANAGED` marker | absent in pythoncore-3.14-64; present in uv's `cpython-3.14.10` |
| uv | 0.13.8 (winget package `astral-sh.uv`) |
| Git Bash | `C:\Program Files\Git\usr\bin\bash.exe`, bash 5.3.15 |
| uv venv contents | `Scripts\python.exe`, `pythonw.exe`, activate scripts; **no `python3.exe`** (probe venv in scratch, uv 0.13.8, CPython 3.14.10) |

### What the test runner needs

Every pty suite decides on the interpreter named `python3` on PATH:

- bash suites: `command -v python3`, then on Windows `python3 -c 'import winpty'`; failure
  sets `HAVE_PTY=false` and prints a `SKIP ... pywinpty not installed` line
  (`tests/managed-files/test-managed-files.sh`, `test-adopt-push.sh`,
  `tests/profile/test-user-init.sh`, `tests/hookin/test-hookin.sh`,
  `tests/deploy-harness/test-deploy-harness.sh`,
  `tests/deploy-harness-mdm/test-deploy-harness-mdm.sh`, `tests/claude-mdm/test-claude-mdm.sh`,
  `tests/rules-fanout/test-rules-fanout.sh`, `tests/rules-fanout-cursor/test-rules-fanout-cursor.sh`,
  `tests/skills-fanout/test-skills-fanout.sh`, `tests/skills-legacy/test-skills-legacy.sh`).
- PowerShell suites: `Get-Command python3`, then `python3 -c "import winpty"`, and run
  `python3 $pty ...` (`tests/managed-files/test-managed-files.ps1`; `test-adopt-push.ps1`).
- `pty-run.py` itself imports `winpty.PtyProcess` and prints the CI install command when
  the import fails.

So pywinpty must be importable by whatever `python3` resolves to in the shell that runs
the suite. Today that is PyManager's 3.14.6.

## 4. Local install options

| # | Option | Works with `python3` on PATH? | Hash-pinned? | Elevation | Survives | Assessment |
|---|---|---|---|---|---|---|
| A | `python -m pip install --user --only-binary=:all: --require-hashes -r <file with the cp314 hash>` | yes: user site is read by PyManager 3.14.6 and uv 3.14.10 alike | yes | no | 3.14 patch upgrades; a PATH-order change between the two 3.14 interpreters | **recommended** |
| A' | as A, into pythoncore-3.14-64's own `site-packages` (no `--user`) | yes, for PyManager 3.14.6 only | yes | no (per-user install dir) | lost if PyManager reinstalls 3.14; invisible to uv 3.14.10 | weaker than A |
| A0 | `python -m pip install --require-hashes -r tests/managed-files/requirements-windows.txt` as it stands | n/a | yes | no | n/a | **fails here** (no cp314 hash in the file; expected, not run) |
| B | `uv venv` + `uv pip install --require-hashes -r ...`, activated before the tests | no: a Windows venv has no `python3.exe`, so `python3` still resolves to PyManager | yes | no | yes | rejected without integration code (the suites would need to call `python` or a `$PYTHON` variable) |
| B' | `uv venv --python 3.12` to mirror CI | no (same `python3` problem); also downloads a 3.12 runtime | yes | no | yes | rejected |
| C | `uv pip install --system` into uv's 3.14.10 | not first on PATH; uv's interpreter carries `EXTERNALLY-MANAGED` | yes | no | yes | rejected |
| D | conda | would need a conda install | n/a | no | n/a | rejected (no managed conda) |

Weighed against the evaluation principles (`shared/rules/tool-evaluation.md`, ranked):
1) official endorsement: pip is documented upstream, conda is "Recommended" (disclosed
yellow flag); 2) provenance: PyPI file hash verified today against the JSON API; no PyPI
attestations exist to check; 3) latest stable: 3.1.2 is latest; 4-5) cross-platform: n/a,
Windows-only by design (POSIX uses stdlib `pty`); 6) automation: one pip command, same
pin as CI; 7) maintenance: active (3 releases in October 2026), sole maintainer; 8) build
time: none (binary wheel only).

Version skew to disclose: CI runs the cp312 wheel on Python 3.12; the workstation would run
the cp314 wheel on 3.14.6. Same release, different build; the CI probe results
(`pty-run.py` docstring: Git Bash sees a terminal and `/dev/tty`, pwsh needs CR) were
measured on 3.12 only.

## 5. Hard blocks and yellow flags (`reference/tool-evaluation-criteria.md`)

Hard blocks: none.

| Hard block | Result |
|---|---|
| Unverified publisher | n/a (PyPI); the PyPI author, PyPI maintainer and GitHub owner are the same person, `andfoy` |
| Repo inactive 2+ years | no: last push 2026-10-28 |
| Known security advisories | none found (repo, GitHub advisory database, PyPI) |
| Personal fork when official exists | no: it is the original repository, not a fork |
| Typosquatting | no: the name `terminado` depends on |
| Excessive permissions | no: a library that spawns console processes as the current user |

I'd suggest pywinpty 3.1.2 for this, but note:
- ⚠️ Sole maintainer on a personal account (`andfoy`: 782 commits; the next human contributor has 16; PyPI "1 maintainer")
- ⚠️ Low GitHub adoption (164 stars, below the 500 threshold), against high real use (2.45M downloads/month; a Windows dependency of `terminado`)
- ⚠️ Upstream recommends conda; pip is the documented second method
- ⚠️ No PyPI provenance attestations and no SECURITY.md (no signed build chain to verify beyond the PyPI hash)
- ⚠️ Open ConPTY throughput issue #564 (already worked around by one Windows SKIP in `test-managed-files.sh`)
Want to proceed, or should I look for alternatives?

Health flags (per platform): Windows **yellow** (sole maintainer; personal account; no
provenance attestations). macOS / Linux **n/a** (stdlib `pty`).

Alternative without a new dependency, for the record: aitools issue #72's preferred
direction 1 (an input seam so menus read scripted keystrokes without a terminal). PR #139
(merged 2026-11-01) chose pywinpty instead for CI; #72 is still OPEN on GitHub.

## 6. Recommendation

Install pywinpty 3.1.2 into the Python 3.14 user site, wheel only, hash-pinned with the
cp314 win_amd64 hash read from PyPI on 2026-11-13. Then add the 3.1.2 hashes for
cp314 (and the other win_amd64/arm64 wheels) to `tests/managed-files/requirements-windows.txt`
so the canonical command in `pty-run.py`'s error message works on every supported
interpreter; after that change the local command becomes
`python -m pip install --user --require-hashes -r tests/managed-files/requirements-windows.txt`.

### Proposed install command (pwsh, from the aitools checkout root; awaiting approval; not run)

```powershell
python -m pip install --user --only-binary=:all: --require-hashes -r tests/managed-files/requirements-windows.txt
```

(v1.0 proposed a temporary one-line requirements file with the cp314 hash; v1.1 uses the
repo file, which now carries that hash.)

Expected: `Successfully installed pywinpty-3.1.2` into
`C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages`.

### Test commands (pwsh, from the worktree or main checkout root)

```powershell
python3 -c "import winpty, sys; print(winpty.__file__, sys.executable)"
python tests\managed-files\winpty-probe.py 'C:\Program Files\Git\usr\bin\bash.exe'
bash tests/managed-files/test-managed-files.sh > $env:TEMP\mf-sh.log 2>&1; "exit $LASTEXITCODE"
pwsh -NoProfile -File tests/managed-files/test-managed-files.ps1 > $env:TEMP\mf-ps.log 2>&1; "exit $LASTEXITCODE"
```

Pass criteria: the import prints a path under `Roaming\Python\Python314\site-packages`;
the probe's section 3 shows `[git-bash CR]` with `T0=yes`, `DEVTTY=yes`, `GOT[abc]` and
`[pwsh CR]` with `GOT[abc]` (exit 0); both suite logs end with exit 0 and contain no
`SKIP interactive cases` line (the bash log keeps one expected
`SKIP display, diff over 64 KB` line, issue #564). Each suite runs every case in its own
temp HOME.

### Rollback

```powershell
python -m pip uninstall -y pywinpty
```

After rollback the pty suites return to `SKIP ... pywinpty not installed` on this machine.

### Caveat

If PyManager's default runtime moves to 3.15, `python3` changes interpreter and user site
(`Python315`), and the suites SKIP again (visibly, with the reason) until the cp315 wheel
is installed.

## 7. Registry

No tool-registry entry recommended. The registry tracks managed tools that
`aitools install` delivers to users (setup scripts, installer steps, Managed CLI Tools
rows); pywinpty is a test-only Python library on CI and developer machines, never deployed
to an endpoint, with its pin and provenance in `requirements-windows.txt` and this file.
`shared/rules/tool-lifecycle.md` "Bundled dependency graduation" would apply only if the
commander makes local Windows pty runs a project requirement (a standing order, or a
check that fails without it).

## 8. Unknowns

- pip's exact error for option A0 on 3.14 (expected a hash mismatch or "no matching
  distribution" under `--require-hashes`; not run, installs forbidden before the gate).
- Whether the ConPTY probe results measured on CI (3.12, windows-2022) hold on this
  workstation (3.14.6, Windows 11 Pro for Workstations 10.0.26300); the test commands
  answer it.
- Whether the latest CI run on main shows the interactive cases running (no SKIP line) on
  windows; not checked here. Issue #72's "Done when" depends on it.

## Sources

- https://pypi.org/pypi/pywinpty/3.1.2/json (browser, 2026-11-13)
- https://pypi.org/project/pywinpty/ (browser, 2026-11-13)
- https://pypistats.org/packages/pywinpty (browser, 2026-11-13; the `/api/` URL failed with ERR_NAME_NOT_RESOLVED, the HTML page loaded on retry)
- https://pypi.org/pypi/terminado/json (browser, 2026-11-13)
- https://raw.githubusercontent.com/andfoy/pywinpty/main/CHANGELOG.md (browser, 2026-11-13)
- `gh api repos/andfoy/pywinpty` (+ `/releases`, `/commits`, `/contributors`, `/license`, `/security-advisories`, `/contents/SECURITY.md`, `/issues/564`); `gh api advisories?ecosystem=pip&affects=pywinpty`
- `gh issue view 72 --repo nobul-tech/aitools`; `gh pr view 139 --repo nobul-tech/aitools`
- Repo: `tests/managed-files/requirements-windows.txt`, `pty-run.py`, `winpty-probe.py`, `test-managed-files.sh`, `test-managed-files.ps1`; `.github/workflows/check.yml` (windows job); `plans/ci-platform-targeting.md`; `RELEASE_NOTES.md`
