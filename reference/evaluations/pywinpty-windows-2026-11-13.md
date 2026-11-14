# Evaluation: pywinpty as a local Windows test dependency — Windows 11 workstation — 2026-11-13

Version 1.3 (2026-11-14). Authors: v1.0 M3-Fixes-D (delegate of M3-Fixes, Session
Commander 87795dc3-e); v1.1 M3-Fixes; v1.2 M4-Winpty (written by its delegate
M4-F-Registry); v1.3 M4-Winpty. Phase 2 gate: **approved** by the commander on 2026-11-14 (RFI fa81-7:
"yes, i stated i approved it"); pywinpty 3.1.2 installed on this workstation the same day
(section 6, "Phase 2 result").

v1.3 (M4-Winpty, 2026-11-14): the PEP 668 question (section 4 "Finding", section 8
unknown 4) is decided -- commander, RFI fa81-9: "fix pep, add it to same branch commit,
watch ci/cd, fix any errors, merge when ready" (option (b)). For an EXTERNALLY-MANAGED
interpreter `setup-pywinpty.ps1` now runs `pip install --target <that interpreter's user
site> --upgrade --only-binary=:all: --require-hashes -r scripts/requirements-pywinpty.txt`
(pip skips its PEP 668 check for `--target`: `pip/_internal/commands/install.py`,
`check_externally_managed()` runs only when `target_dir`, `prefix_path` and `root_path` are
None), removes stale `pywinpty-*.dist-info` of other versions, and verifies by import; it
still never passes `--break-system-packages` and never writes into the interpreter's
install tree (WARN + ACTION when the user site is disabled or inside that tree). Verified
against uv CPython 3.14.10 in an isolated APPDATA: install "(installed, --target)",
verified re-run, a seeded `pywinpty-3.1.1.dist-info` replaced, `PYTHONNOUSERSITE=1` ->
WARN; uv's `Lib\site-packages` unchanged.

v1.2 (M4-Winpty, 2026-11-14): the commander approved Phase 2 and ordered adoption:
"/tool-adopt pywinpty.  we will need setup-pywinpty.ps1.  document its source of truth in
registry via /tool-registry.  mark windows/linux as N/A." (RFI fa81-5 answered "yes":
macOS and Linux n/a, Windows supported) and "we should support pywinpty through all 3
methods of deployment/install" (RFI fa81-8). Changes: the install ran and passed (section
6, "Phase 2 result"); the pin moved from `tests/managed-files/requirements-windows.txt` to
`scripts/requirements-pywinpty.txt` (commit 6feada2), the single source of truth for the
version and the wheel hashes; `scripts/setup-pywinpty.ps1` / `.sh` install it on the three
deployment paths (section 6, "Integration"); a new finding on the aitools-managed Python
(section 4, "Finding: the aitools-managed python3 refuses the install"); section 7 is
superseded by the commander's order (a registry entry now exists); the unknowns in section
8 are updated. Sections 1 to 4 keep their 2026-11-13 facts; statements about that state
say "then".

v1.1 (M3-Fixes): the follow-up in section 6 is done in the same PR --
`tests/managed-files/requirements-windows.txt` (then; `scripts/requirements-pywinpty.txt`
since v1.2) pins every 3.1.2 win_amd64 wheel (cp310-cp315, incl. free-threaded; hashes
re-read from the PyPI JSON API by M3-Fixes), so the proposed command uses that file
instead of a temporary one-line file. Sections 1 and 4 describe the file as it was before
that PR.

**Intent**: **Purpose**: Preserve the evaluation of pywinpty as a managed Windows test
library -- the evidence behind its install method and health flags, and the record of the
Phase 2 decision and its result. **Scope**: provenance, official source, maintenance,
licence, how CI's windows job got it, this workstation's Python facts, install options,
hard blocks and yellow flags, recommendation, the Phase 2 result. NOT the CI adoption
itself (S2-Winpty, 2026-11-01, `plans/ci-platform-targeting.md`). NOT the pin (version and
hashes: `scripts/requirements-pywinpty.txt`). NOT integration code
(`scripts/setup-pywinpty.ps1` / `.sh`, installer Step 15b, `build-deploy.sh`). NOT
registry data (`/tool-registry` skill, entry `pywinpty`). **Audience**: the orchestrator
M4-Winpty, the commander reviewing the adoption, and agents re-evaluating pywinpty or
reviewing its yellow flags.

Method: web sources read with the chrome-devtools MCP (PyPI JSON API, PyPI project page,
pypistats, the upstream CHANGELOG), GitHub facts with `gh api`, local facts with read-only
commands (`python --version`, `python -m pip show`, `python -m pip index versions`,
`uv python list`, an empty `uv venv` in scratch to see which executables it creates).
Nothing was installed or downloaded.

## Summary

1. **No hard block.** Same verdict as the CI evaluation of 2026-11-01 (S2-Winpty). The CI
   pin, 3.1.2, is still the latest release (2026-10-28); both CI hashes match PyPI.
2. **The CI requirements file did not install on this workstation (then; fixed in v1.1).**
   It pinned only the cp312 and cp313 win_amd64 wheels; this workstation's `python3` is CPython 3.14.6, which
   needs the cp314 wheel, whose hash is not in the file. Under `--require-hashes` pip
   rejects the cp314 wheel (expected; not run, installs are forbidden before the gate).
3. **The test suites call `python3` from PATH** (Git Bash and pwsh alike). On this machine
   that is PyManager's `python3.exe` -> `pythoncore-3.14-64` 3.14.6. A venv does not help:
   a Windows venv (uv 0.13.8, probed) has `python.exe` but no `python3.exe`.
4. **Recommended: a user-site install (`pip install --user`) of the cp314 win_amd64 wheel,
   hash-pinned.** Both 3.14 interpreters on this machine (PyManager 3.14.6 and uv 3.14.10)
   share the user site `%APPDATA%\Python\Python314\site-packages`, so it survives a PATH
   order change and a 3.14 patch upgrade. Follow-up: add the cp314 hashes to
   `requirements-windows.txt` so CI and local share one pinned file (done in v1.1; the
   file is `scripts/requirements-pywinpty.txt` since v1.2). Installed 2026-11-14 (v1.2).
5. **Yellow flags** (unchanged in kind from 2026-11-01): sole maintainer on a personal
   account; 164 stars; plus, new here: upstream recommends conda first; no PyPI
   provenance attestations; no SECURITY.md.

## 1. What CI did on 2026-11-13

Since v1.2 the windows job installs pywinpty through `scripts/setup-pywinpty.ps1` with the
pin `scripts/requirements-pywinpty.txt` (M4-Winpty brief, 2026-11-14). The table records
the state when this evaluation was written.

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
the suite. On this workstation on 2026-11-13 that was PyManager's 3.14.6; on a machine
where aitools Step 15 owns `python3` it is the uv-managed CPython (section 4, "Finding").

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

### Finding: the aitools-managed python3 refuses the install (v1.2)

Verified read-only by M4-Winpty on 2026-11-14 (source: M4-Winpty message to
M4-F-Registry). It corrects the assumption of sections 3 and 4 that this workstation's
`python3` (PyManager 3.14.6, first on PATH) is the relevant interpreter on every machine:

- aitools Step 15 (`setup-python.ps1`, `uv python install --default`) makes `python` /
  `python3` the uv-managed CPython: shim `%USERPROFILE%\.local\bin\python3.exe` ->
  `%APPDATA%\uv\python\cpython-3.14-windows-x86_64-none\python.exe`, 3.14.10.
- That interpreter carries `EXTERNALLY-MANAGED`.
  `python3 -m pip install --dry-run --user --only-binary=:all: --require-hashes -r scripts/requirements-pywinpty.txt`
  exits 1 with "error: externally-managed-environment ... This Python installation is
  managed by uv and should not be modified." (PEP 668). Option C above fails for the same
  reason.
- Its user site (`%APPDATA%\Python\Python314\site-packages`, `ENABLE_USER_SITE` True) is
  shared with any non-managed CPython 3.14, so a `--user` install made by a
  python.org/PyManager interpreter is importable by the uv `python3` (option A still
  serves the suites).
- v1.2 (then): `setup-pywinpty.ps1` reported WARN "python externally managed" + ACTION
  and never passed `--break-system-packages`; the endpoint case was open.
- v1.3 (decided, commander RFI fa81-9, 2026-11-14): for such an interpreter the script
  installs with `pip install --target <its user site> --upgrade ...` (see the v1.3
  changelog at the top); WARN "managed python, no user site" + ACTION remains only when
  the user site is disabled or inside the install tree. Still never
  `--break-system-packages`.

Version skew to disclose: CI runs the cp312 wheel on Python 3.12; the workstation would run
the cp314 wheel on 3.14.6. Same release, different build; the CI probe results
(`pty-run.py` docstring: Git Bash sees a terminal and `/dev/tty`, pwsh needs CR) were
measured on 3.12 only (v1.2: the probe on 3.14.6 confirmed them; section 6, "Phase 2
result").

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
(then; `scripts/requirements-pywinpty.txt` since v1.2) so the canonical command in
`pty-run.py`'s error message works on every supported interpreter; after that change the
local command becomes
`python -m pip install --user --require-hashes -r tests/managed-files/requirements-windows.txt`.
(v1.1 added the win_amd64 hashes only; win_arm64 is still not pinned.)

### Install command (pwsh, from the aitools checkout root; approved and run 2026-11-14)

As approved and run (the pin was then at its old path):

```powershell
python -m pip install --user --only-binary=:all: --require-hashes -r tests/managed-files/requirements-windows.txt
```

Current form (the pin's path since v1.2; run by `scripts/setup-pywinpty.ps1`):

```powershell
python -m pip install --user --only-binary=:all: --require-hashes -r scripts/requirements-pywinpty.txt
```

(v1.0 proposed a temporary one-line requirements file with the cp314 hash; v1.1 used the
repo file, which carries that hash.)

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

### Phase 2 result (2026-11-14, verified by M4-Winpty)

Approved by the commander (RFI fa81-7: "yes, i stated i approved it"). Run from
`C:\Users\jdpal\repos\aitools` on main:

- Install: "Downloading pywinpty-3.1.2-cp314-cp314-win_amd64.whl (2.1 MB) ...
  Successfully installed pywinpty-3.1.2", exit 0.
- Import: `python3 -c "import winpty..."` ->
  `C:\Users\jdpal\AppData\Roaming\Python\Python314\site-packages\winpty\__init__.py`,
  interpreter `C:\Users\jdpal\AppData\Local\Python\pythoncore-3.14-64\python.exe`
  (PyManager `python3.exe`), version 3.1.2.
- `winpty-probe.py` section 3: `[git-bash CR] exit=0 out=['T0=yes', 'DEVTTY=yes', 'abc', 'GOT[abc]']`,
  `[git-bash LF] exit=0 ... 'GOT[abc]'`,
  `[pwsh CR] exit=0 out=['REDIRECTED=False', 'USERINTERACTIVE=True', 'abc', 'GOT[abc]']`;
  probe exit 0.
- `tests/managed-files/test-managed-files.sh`: 79 passed, 0 failed, 3 skipped (chmod;
  "display, diff over 64 KB", #564; "claude.md adopt round trip: setup-user-claude.sh does
  not run on Windows"); no pywinpty SKIP. `test-managed-files.ps1`: 56 passed, 0 failed,
  0 skipped.
- Pin re-check: the hash -> file mapping re-read from
  https://pypi.org/pypi/pywinpty/3.1.2/json (raw JSON via python urllib, 2026-11-14): the
  8 pinned hashes are exactly the win_amd64 wheels cp310, cp311, cp312, cp313, cp314,
  cp314t, cp315, cp315t; the 8 win_arm64 wheels and the sdist are not pinned; latest
  version 3.1.2.

The pass criteria above hold for the import, the probe and the SKIP lines; the suites'
exit codes are not in the M4-Winpty brief (0 failed in both).

### Integration (v1.2, M4-Winpty)

- Pin: `scripts/requirements-pywinpty.txt`, the single source of truth for the version and
  the wheel hashes, with a machine-readable `# wheel-tags:` line read by
  `setup-pywinpty.ps1`.
- `scripts/setup-pywinpty.ps1` (Windows): resolves `python3`, then `python`; WARN on no
  Python, an interpreter tag the pin does not cover, or an `EXTERNALLY-MANAGED` or venv
  interpreter; never `--break-system-packages`; runs the install command above; verifies
  by import. `scripts/setup-pywinpty.sh` (macOS/Linux): OK row `n/a (<platform>)`, stdlib
  `pty`.
- Three deployment paths (commander, RFI fa81-8): dev, `aitools install` "Step 15b:
  pywinpty" right after Step 15 Python; MDM, a `build-deploy.sh` copy block pair with the
  pin embedded in the generated `setup-pywinpty.ps1` (`$AitoolsEmbeddedPywinptyPin`);
  package, the `build-package.sh` payload `scripts/` -> `aitools-install.ps1` -> Step 15b.
  CI's windows job installs through `setup-pywinpty.ps1`.
- Tests: `tests/pywinpty/`.

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

**Superseded (v1.2).** The commander's order of 2026-11-14 ("/tool-adopt pywinpty. ...
document its source of truth in registry via /tool-registry. mark windows/linux as N/A.")
overrides the recommendation below: pywinpty now has a registry entry, written through the
`/tool-registry` skill (Windows supported, macOS and Linux n/a, the pin file named as the
source of truth for the version and hashes). As a library it gets no Managed CLI Tools row
(session-commander decision, `shared/rules/tool-lifecycle.md` "Managed libraries"). The
v1.1 text is kept below as the record.

v1.1: No tool-registry entry recommended. The registry tracks managed tools that
`aitools install` delivers to users (setup scripts, installer steps, Managed CLI Tools
rows); pywinpty is a test-only Python library on CI and developer machines, never deployed
to an endpoint, with its pin and provenance in `requirements-windows.txt` and this file.
`shared/rules/tool-lifecycle.md` "Bundled dependency graduation" would apply only if the
commander makes local Windows pty runs a project requirement (a standing order, or a
check that fails without it).

## 8. Unknowns

Updated in v1.2.

1. pip's exact error for option A0 on 3.14 (expected a hash mismatch or "no matching
   distribution" under `--require-hashes`). **Still unknown**: A0 was never run, and v1.1
   removed its cause (the pin covers cp314), so the error was never observed.
2. Whether the ConPTY probe results measured on CI (3.12, windows-2022) hold on this
   workstation (3.14.6, Windows 11 Pro for Workstations 10.0.26300). **Answered: yes**
   (section 6, "Phase 2 result": `GOT[abc]` for git-bash CR, git-bash LF and pwsh CR).
3. Whether the latest CI run on main shows the interactive cases running (no SKIP line) on
   windows. **Answered: yes** for the last green main run, job 132196438940: it showed
   `GOT[abc]` and no pty SKIP (source: M4-Winpty brief, 2026-11-14). Issue #72's "Done
   when" depends on it.
4. New (v1.2): how an endpoint whose only CPython is the aitools/uv-managed one gets
   pywinpty (section 4, "Finding"). Answered in v1.3: `pip --target <its user site>`
   (commander, RFI fa81-9, 2026-11-14).

## Sources

- https://pypi.org/pypi/pywinpty/3.1.2/json (browser, 2026-11-13)
- https://pypi.org/project/pywinpty/ (browser, 2026-11-13)
- https://pypistats.org/packages/pywinpty (browser, 2026-11-13; the `/api/` URL failed with ERR_NAME_NOT_RESOLVED, the HTML page loaded on retry)
- https://pypi.org/pypi/terminado/json (browser, 2026-11-13)
- https://raw.githubusercontent.com/andfoy/pywinpty/main/CHANGELOG.md (browser, 2026-11-13)
- `gh api repos/andfoy/pywinpty` (+ `/releases`, `/commits`, `/contributors`, `/license`, `/security-advisories`, `/contents/SECURITY.md`, `/issues/564`); `gh api advisories?ecosystem=pip&affects=pywinpty`
- `gh issue view 72 --repo nobul-tech/aitools`; `gh pr view 139 --repo nobul-tech/aitools`
- v1.2: https://pypi.org/pypi/pywinpty/3.1.2/json (raw JSON via python urllib, 2026-11-14, M4-Winpty); M4-Winpty brief and message to M4-F-Registry (install, probe, suite and CI results; the uv-managed python3 finding), 2026-11-14; `scripts/requirements-pywinpty.txt`
- Repo (v1.1): `tests/managed-files/requirements-windows.txt` (then), `pty-run.py`, `winpty-probe.py`, `test-managed-files.sh`, `test-managed-files.ps1`; `.github/workflows/check.yml` (windows job); `plans/ci-platform-targeting.md`; `RELEASE_NOTES.md`
