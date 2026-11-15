# S2-Winpty: /tool-eval of pywinpty as the Windows backend for pty-run.py

Version 1.0, 2026-10-31. Author: S2-Winpty (delegate of Session Commander e99e5ef9-9).
Mission order: commander, 2026-11-01: "Evaluate it now".
Research only: nothing installed, no repo or registry file written.

## 1. Verdict

**Adopt with yellow flags**, as a CI-only test dependency on the `windows-2022` job,
pinned to `pywinpty==3.1.2` (with hashes). No hard block found.

Wiring it in is conditional on a short spike on the runner first. Three fit
questions cannot be answered from documentation (section 8, risks R1 to R3): whether
Git Bash's `[ -t 0 ]` and `/dev/tty` work inside a ConPTY, whether
`[Environment]::UserInteractive` is true on a hosted runner, and how ConPTY handles
LF compared with CR on input. If any of these fails, the package is still sound, but
pty-run.py cannot exercise those menus on Windows. That is a fit problem, not an
evaluation problem.

Pin 3.1.2 or later. Do not take an older version. 3.1.2 fixes two bugs this harness
would hit directly: EOF detection on ConPTY (`iseof()` never returned True before)
and spawning an executable whose path contains a space. Both `C:\Program Files\Git\bin\bash.exe`
and `C:\Program Files\PowerShell\7\pwsh.exe` contain a space (source: upstream
CHANGELOG.md, "Version 3.1.2 (2026/10/28)").

## 2. Hard-block check

| Hard block | Result | Evidence (source) |
|---|---|---|
| Unverified publisher | PASS (with a note) | PyPI lists 1 maintainer, `andfoy`; Author/Maintainer "Edgar Margffoy" (pypi.org/project/pywinpty, read with chrome-devtools 2026-10-31). PyPI `project_urls.Repository` = `https://github.com/andfoy/pywinpty`, owned by the same login (`gh api repos/andfoy/pywinpty`). Note: PyPI has no verified badge for packages. Uploads come from the public `windows_release.yml` workflow with `twine upload` and a stored token (`TWINE_PASSWORD: secrets.MATURIN_PASSWORD`), not Trusted Publishing. There is no PEP 740 attestation: `https://pypi.org/integrity/pywinpty/3.1.2/pywinpty-3.1.2-cp312-cp312-win_amd64.whl/provenance` returns 404 "No provenance available" |
| Repo inactive 2+ years | PASS | Last push 2026-10-28T22:46:56Z; last commit 6162321 on 2026-10-28 (`gh api repos/andfoy/pywinpty`, `/commits`) |
| Known security advisories | PASS (none found) | OSV `POST https://api.osv.dev/v1/query {"package":{"name":"pywinpty","ecosystem":"PyPI"}}` returned `{}`. GitHub `gh api "/advisories?ecosystem=pip&affects=pywinpty" --jq length` returned `0`. The PyPI JSON `vulnerabilities` field is `[]`. Native dependency: OSV query for crate `winpty-rs` (crates.io) returned `{}` |
| Personal fork when official exists | PASS | `fork: false`. The original org repo `spyder-ide/pywinpty` now redirects to `andfoy/pywinpty`: `gh api repos/spyder-ide/pywinpty` returns `full_name: andfoy/pywinpty`. The README states "Copyright © 2017–2022 Spyder Project Contributors / Copyright © 2022– Edgar Andrés Margffoy Tuay". This is the canonical repo, transferred from the org to its maintainer, not a fork |
| Typosquatting | PASS | This is the original name: repo created 2017-06-02, 52 releases on PyPI since then. It is the name Jupyter depends on: `terminado 0.18.1` requires `pywinpty>=1.1.0; os_name == 'nt'`, and `jupyter_server 2.21.1` requires `pywinpty!=3.0.4,>=2.0.1; os_name == "nt"` (PyPI JSON `requires_dist`). The near-miss `winpty` does not exist on PyPI (`https://pypi.org/pypi/winpty/json` returns 404) |
| Excessive/unexplained permissions | PASS | A library with no install hooks. Wheels are prebuilt, so pip runs no build code. Note: the wheel bundles native binaries, ConPTY from Microsoft's NuGet package (pinned to 1.25.260930003 since 3.1.1) and winpty from conda-forge (CHANGELOG 3.1.1; `windows_release.yml` "Copy winpty binaries" and `check_wheel.py --has-conpty --has-winpty`). This is explained by the package's purpose |

## 3. Yellow flags (disclosed, not decided)

I'd suggest pywinpty for this, but note:
- Sole maintainer on a personal account. `andfoy` has 782 commits; the next human
  contributor has 16 (`goanpeca`), then `ccordoba12` 15 and `dependabot[bot]` 121
  (`gh api repos/andfoy/pywinpty/contributors`). PyPI shows "1 maintainer". There is
  no org backing since the move away from spyder-ide.
- Low adoption by the stars criterion: 164 stars, below the 500 threshold
  (`gh api repos/andfoy/pywinpty`). Download adoption is high, though: 1,937,963
  downloads last month and 621,785 last week (`https://pypistats.org/api/packages/pywinpty/recent`,
  2026-10-31). It is also a Windows dependency of `jupyter_server` and `terminado`.
  By practical adoption this flag is weak.
- Not flagged: no release in 12+ months (latest 3.1.2, 2026-10-28), no licence
  (MIT; GitHub `license.spdx_id: MIT`; PyPI classifier "OSI Approved :: MIT License"),
  archived (`archived: false`), excessive permissions (see section 2).

Additional risk signals (not criteria flags; see section 8): heavy release churn,
one broken release, and no signed provenance.

## 4. Publisher and repo facts

| Fact | Value | Source |
|---|---|---|
| Canonical repo | https://github.com/andfoy/pywinpty (spyder-ide/pywinpty redirects here) | `gh api repos/andfoy/pywinpty`, `gh api repos/spyder-ide/pywinpty` |
| Owner | `andfoy`, type User, "Edgar Andrés Margffoy Tuay", account since 2012-06-21, 221 followers | `gh api users/andfoy` |
| Stars / forks / open issues | 164 / 35 / 13 open issues (the API's `open_issues_count` 25 includes PRs) | `gh api repos/andfoy/pywinpty`; `gh issue list --state open` |
| Last commit | 2026-10-28T22:46:40Z, 6162321 "Back to work" | `gh api repos/andfoy/pywinpty/commits` |
| Last release | v3.1.2, GitHub 2026-10-28T22:47:15Z; PyPI upload 2026-10-28T22:48:55Z | `gh api .../releases`; PyPI JSON |
| Release cadence | 25 releases 2022-01 to 2026-10. In 2026: 3.0.3 (Feb 4), 3.0.4 and 3.0.5 (Jun 10), 3.1.0 (Oct 15), 3.1.1 (Oct 27), 3.1.2 (Oct 28) | PyPI JSON `releases` |
| Licence | MIT. Native crate winpty-rs 1.0.8: `MIT OR Apache-2.0` | GitHub API; crates.io API `/api/v1/crates/winpty-rs` |
| Python support | `requires_python >=3.10`; classifier "Operating System :: Microsoft :: Windows" (Windows only; macOS and Linux keep stdlib `pty`) | PyPI JSON `info` |
| Build | Rust (PyO3 0.30.1) + maturin; CI on GitHub Actions `windows-latest` | README; CHANGELOG 3.1.0; `windows_release.yml` |
| Security contact | Tidelift | README "Security contact information" |

## 5. Advisories

None found. Queries used (2026-10-31):
- `curl -s -X POST https://api.osv.dev/v1/query -d '{"package":{"name":"pywinpty","ecosystem":"PyPI"}}'` returned `{}`
- `curl -s -X POST https://api.osv.dev/v1/query -d '{"package":{"name":"winpty-rs","ecosystem":"crates.io"}}'` returned `{}`
- `gh api "/advisories?ecosystem=pip&affects=pywinpty" --jq length` returned `0`
- PyPI JSON `https://pypi.org/pypi/pywinpty/json` field `vulnerabilities` is `[]`

## 6. Install on the CI runner; wheel availability

Method catalog (Windows only; the package is Windows-only):

| Method | Official? | Fit for CI |
|---|---|---|
| `pip install pywinpty` (PyPI wheels) | Yes, in the README "Using pip" | Best fit. Prebuilt wheels, no compiler, works with `actions/setup-python` |
| `conda install pywinpty` (conda-forge) | Yes, the README marks it "Recommended" | Needs a miniconda setup step, and conda-forge builds a separate artifact. My inference: the "Recommended" label serves conda users and the winpty C library link; the PyPI wheels already bundle winpty and ConPTY |
| Build from source (Rust + maturin) | Yes | Not needed; slow; needs a Rust toolchain |

Wheel availability for 3.1.2 (PyPI JSON `urls`): `win_amd64` and `win_arm64` for
cp310, cp311, cp312, cp313, cp314, cp314t, cp315, cp315t, plus an sdist. No compiler
is needed on the runner for CPython 3.10 to 3.15.

Recommended CI steps (Windows job only; not wired in, the commander decides):

```yaml
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - name: Install pywinpty (pty backend for interactive tests)
        shell: pwsh
        run: python -m pip install --require-hashes -r tests/managed-files/requirements-windows.txt
```

with `requirements-windows.txt`:

```
pywinpty==3.1.2 \
    --hash=sha256:220e30a8cccd7f0be3356d4e3e56fdcda2ae45edc1de526b440c4031fe9308da
```

That hash is `pywinpty-3.1.2-cp312-cp312-win_amd64.whl` (2,107,962 bytes). For
cp313 it is `d968dc4300b497f048318387781ed9931dc0038815f25b4f642a1749448769cb`
(PyPI JSON `digests.sha256`). Without a requirements file:
`python -m pip install pywinpty==3.1.2`.

Pin the Python version explicitly. I do not know which Python the `windows-2022`
image puts on PATH by default, nor whether a `python3` command exists there. Today
the Windows job (check.yml lines 620+) has no `setup-python` step, and both test
suites invoke `python3` (test-managed-files.sh:37, :83; test-managed-files.ps1:26, :78).

Not run: the playbook's trial installation (Step 5). This mission forbids installing,
so the first CI run is the trial.

## 7. API fit and sketch

Documented API (README "Package usage"; `winpty/ptyprocess.py`; `winpty/_winpty.pyi`
on main, 2026-10-31):
- `PtyProcess.spawn(argv, cwd=None, env=None, dimensions=(24, 80), backend=None)`.
  argv is a list. `argv[0]` is resolved with `shutil.which` against `env['PATH']`,
  and the rest is joined with `subprocess.list2cmdline`.
- `write(s)` returns the bytes written. `read(size)` returns `str` and raises
  `EOFError('Pty is closed')` at EOF. `readline()`, `isalive()`, `exitstatus`
  (`PTY.get_exitstatus() -> Optional[int]`), `pid`, `terminate(force)`, `kill(sig)`,
  `close()`, and `sendeof()`, which writes `\x04`.
- `fileobj` is a loopback TCP socket fed by a reader thread. `select.select` works on
  sockets on Windows, so pty-run.py's select-and-quiet loop keeps its shape.
- Low-level `winpty.PTY(cols, rows)` with `spawn(appname, cmdline, cwd, env)`,
  `read(blocking=False)`, `iseof()` (reliable from 3.1.2 on) and `cancel_io()` is an
  alternative that avoids the thread and the socket.

Sketch of the Windows branch of pty-run.py (an illustration, not tested):

```python
import select, shutil, subprocess, time
from winpty import PtyProcess  # pywinpty==3.1.2

def run_windows(cmd: list[str], keys: bytes, timeout: float) -> tuple[int, str]:
    exe = shutil.which(cmd[0]) or cmd[0]          # caller should pass Git Bash's absolute path (R4)
    proc = PtyProcess.spawn([exe, *cmd[1:]], dimensions=(50, 250))  # wide: limit ConPTY reflow (R5)
    lines = keys.replace(b"\n", b"\r").decode("latin-1").splitlines(keepends=True)  # Enter = CR (R3)
    out: list[str] = []; last_out = time.monotonic(); sent_at = -1
    deadline = time.monotonic() + timeout
    while proc.isalive():
        if time.monotonic() > deadline:            # kill the whole tree, not just the pid (R6)
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
            return 124, "".join(out)
        r, _, _ = select.select([proc.fileobj], [], [], 0.05)
        if r:
            try:
                data = proc.read(65536)
            except EOFError:
                break
            if data:
                out.append(data); last_out = time.monotonic()
        n = sum(map(len, out))
        if lines and time.monotonic() - last_out > 0.4 and n != sent_at:
            proc.write(lines.pop(0)); sent_at = n
    status = proc.exitstatus                        # may be None briefly after exit: poll a little
    return (status if status is not None else 1), "".join(out)
```

The drain loop and the `--log` write stay as they are. Write the log as UTF-8,
because `read()` returns `str`.

## 8. Risks

| # | Risk | Severity for this use | Mitigation |
|---|---|---|---|
| R1 | Git Bash (MSYS2) inside a ConPTY: unknown whether `[ -t 0 ]` is true and whether `/dev/tty` opens, which is what `tty_interactive` in `scripts/aitools-lib.sh` requires. If either fails, the bash menus take the non-interactive branch and the interactive cases fail as tests | High (decides whether the bash cases can run) | Spike: run `bash -c '[ -t 0 ] && echo T0; (printf "" > /dev/tty) && echo TTY'` under pywinpty on windows-2022 |
| R2 | `Test-InteractiveConsole` (`scripts/aitools-lib.ps1`) also requires `[Environment]::UserInteractive`. Unknown whether that is true for a step on a GitHub-hosted Windows runner. If false, the PS1 menus never prompt under any pty | High (decides whether the PS1 cases can run) | Spike: print `[Environment]::UserInteractive` and `[Console]::IsInputRedirected` under pywinpty |
| R3 | Line endings. pty-run.py sends `\n`, but on a console Enter is CR; the README example writes `\r\n`. Unknown how ConPTY's input parser treats a bare LF for `[Console]::ReadLine()` and for MSYS `read`. `\x04` is not EOF on a Windows console (the PS1 suite already avoids sending it, test-managed-files.ps1:146) | Medium | Translate `\n` to `\r` on Windows; keep the EOF cases on the existing `[Console]::SetIn` path |
| R4 | `shutil.which("bash")` can resolve `C:\Windows\System32\bash.exe` (the WSL shim) before Git Bash, depending on PATH order (aitools cross-platform rule, "Windows: managed bash") | Medium | Pass Git Bash's absolute path from the test, or resolve it explicitly |
| R5 | ConPTY re-renders the screen instead of passing raw bytes through: cursor moves, line wraps at the column width, and possibly OSC title sequences (`\e]0;...\a`) that the suite's Perl strip (CSI only, test-managed-files.sh:87) does not remove. Assertions on terminal output may need adjusting. Upstream also has open #564, poor throughput for large output on ConPTY | Medium | Wide dimensions; extend the strip to OSC; prefer asserting on files and deploy.log over the screen text |
| R6 | Timeout: `PtyProcess.terminate`/`kill` call `os.kill` on the child pid only, which on Windows is TerminateProcess of one process. A grandchild such as pwsh started from bash can survive and hold the runner | Low to medium | `taskkill /T /F /PID` on timeout |
| R7 | Release quality and churn. 3.0.4 shipped wheels without the WinPTY DLL and without any arm64 binaries (CHANGELOG 3.0.5); `jupyter_server` excludes `!=3.0.4`. The 3.1.1 notes needed a dated correction. Three releases landed between Oct 15 and Oct 28, and 3.1.2 changes `iseof()` behaviour | Medium | Exact pin plus hashes; upgrade deliberately, not by range |
| R8 | Supply chain: one maintainer, token-based upload, no PEP 740 attestation (section 2) | Low (CI-only, test-only, hash-pinned) | Hash pinning makes a re-uploaded or replaced artifact fail the install |
| R9 | Quoting: argv is joined with `subprocess.list2cmdline`. That is correct for MSVCRT-style parsers (python, pwsh) but wrong for `cmd.exe` (open #531, "unexpected quote escaping in spawn"). pty-run's commands are `bash <file>` and `pwsh -NoProfile -File <file>` | Low | Never route through `cmd /c` |
| R10 | `PtyProcess` opens a 127.0.0.1 TCP listener per process (ptyprocess.py `__init__`). Fine on hosted runners; a hardened host firewall could block it | Low | Use the low-level `PTY` API if that ever matters |

Alternatives (one line each): conda-forge `pywinpty` (same upstream, adds a conda
step); a stdlib-only `ctypes` wrapper over `CreatePseudoConsole` (no dependency, but
a few hundred lines of Win32 handle and pipe code to own; the gap to pywinpty is not
small).

## 9. Conflicts and process notes

- CONFLICT: /tool-eval "Documenting research" (write `reference/evaluations/<tool>-<platform>-<date>.md`) and "Hand off to /tool-registry" vs the prompt ("do NOT write any registry or repo file") -- resolved by tier 2 (prompt): report written only to this scratch file; no registry handoff.
- CONFLICT: the playbook's Step 5 (trial installation is mandatory) vs the prompt ("Do not install pywinpty or any package") -- resolved by tier 2 (prompt): no trial. The first CI spike is the trial. The registry entry must not claim verification before that spike.
- Web sources: the PyPI project page (maintainer count) was read with chrome-devtools. README, CHANGELOG, `ptyprocess.py`, `_winpty.pyi` and `windows_release.yml` came from raw.githubusercontent.com (static files) and `gh api`, as the prompt allowed. Before anything here is recorded in the registry (a protected file), re-verify the install section with chrome-devtools (web-sources rule).
- The GitHub issue search index was stale: it showed #583, #565 and #519 as open although the 3.1.2 CHANGELOG lists them as fixed. Issue counts above use `gh issue list` (live).

## 10. Sources

- PyPI JSON: https://pypi.org/pypi/pywinpty/json (2026-10-31)
- PyPI page: https://pypi.org/project/pywinpty/ (chrome-devtools, 2026-10-31)
- PyPI provenance: https://pypi.org/integrity/pywinpty/3.1.2/pywinpty-3.1.2-cp312-cp312-win_amd64.whl/provenance (404)
- GitHub: `gh api repos/andfoy/pywinpty`, `/releases`, `/commits`, `/contributors`, `repos/spyder-ide/pywinpty`, `users/andfoy`, `repos/andfoy/winpty-rs`, `/license`
- Upstream files (main): README.md, CHANGELOG.md, winpty/ptyprocess.py, winpty/_winpty.pyi, .github/workflows/windows_release.yml
- OSV: https://api.osv.dev/v1/query; GitHub advisories: `gh api /advisories?ecosystem=pip&affects=pywinpty`
- Dependents: PyPI JSON for terminado, jupyter_server
- Downloads: https://pypistats.org/api/packages/pywinpty/recent
- crates.io: https://crates.io/api/v1/crates/winpty-rs
- Local: /Users/new-jose/repos/aitools/tests/managed-files/pty-run.py, test-managed-files.sh, test-managed-files.ps1, scripts/aitools-lib.sh (`tty_interactive`), scripts/aitools-lib.ps1 (`Test-InteractiveConsole`), .github/workflows/check.yml (windows job)
