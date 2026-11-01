#!/usr/bin/env python3
"""winpty-probe.py -- print the Windows runner facts the test suites depend on.

Diagnostic for plans/ci-platform-targeting.md (B3/B6). Changes nothing; prints:
  1. HOME isolation: what pwsh's $HOME, $env:USERPROFILE and
     [Environment]::GetFolderPath('UserProfile') are when USERPROFILE and HOME
     are overridden to a temp dir (do the PS1 scripts follow the override?).
  2. Which Python commands exist (python3 vs python).
  3. ConPTY through pywinpty: does Git Bash see a terminal ([ -t 0 ],
     /dev/tty), does pwsh ([Console]::IsInputRedirected,
     [Environment]::UserInteractive), and is Enter "\\r" or "\\n" (ReadLine /
     read -r results for each).
Usage: python tests/managed-files/winpty-probe.py <git-bash.exe path>
Exit: 0 (facts printed), 1 if pywinpty cannot be imported or spawning fails.
Platform: Windows only (CI windows job). Safe to re-run.
"""
from __future__ import annotations

import os
import re
import select
import shutil
import subprocess
import sys
import tempfile
import time

ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")


def section(title: str) -> None:
    print(f"\n=== {title}", flush=True)


def run_pty(argv: list[str], keys: str, timeout: float = 20.0) -> tuple[object, str]:
    from winpty import PtyProcess
    proc = PtyProcess.spawn(argv, dimensions=(50, 250))
    out: list[str] = []
    last = time.monotonic()
    sent = False
    deadline = time.monotonic() + timeout
    while proc.isalive() and time.monotonic() < deadline:
        r, _, _ = select.select([proc.fileobj], [], [], 0.05)
        if r:
            try:
                data = proc.read(65536)
            except EOFError:
                break
            if data:
                out.append(data)
                last = time.monotonic()
        if not sent and time.monotonic() - last > 0.8:
            proc.write(keys)
            sent = True
    if proc.isalive():
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True)
        return "timeout", ANSI.sub("", "".join(out))
    for _ in range(40):
        if proc.exitstatus is not None:
            break
        time.sleep(0.05)
    return proc.exitstatus, ANSI.sub("", "".join(out))


def main() -> int:
    bash = sys.argv[1] if len(sys.argv) > 1 else (shutil.which("bash") or "bash")
    pwsh = shutil.which("pwsh") or "pwsh"
    print(f"python: {sys.executable} {sys.version.split()[0]}")
    print(f"bash:   {bash}")
    print(f"pwsh:   {pwsh}")

    section("1. HOME isolation in pwsh")
    tmp = tempfile.mkdtemp(prefix="probe-home-")
    env = dict(os.environ, USERPROFILE=tmp, HOME=tmp)
    ps = ("Write-Output ('HOME=' + $HOME); Write-Output ('USERPROFILE=' + $env:USERPROFILE); "
          "Write-Output ('GetFolderPath=' + [Environment]::GetFolderPath('UserProfile'))")
    r = subprocess.run([pwsh, "-NoProfile", "-Command", ps], env=env, capture_output=True, text=True)
    print(f"override: {tmp}")
    print(r.stdout.strip() or r.stderr.strip())
    follows = f"HOME={tmp}" in r.stdout
    print(f"RESULT: pwsh $HOME follows the USERPROFILE override: {'yes' if follows else 'NO'}")

    section("2. Python commands")
    print(f"python3 -> {shutil.which('python3')}")
    print(f"python  -> {shutil.which('python')}")
    print(f"py      -> {shutil.which('py')}")

    section("3. ConPTY via pywinpty")
    try:
        import winpty  # noqa: F401
    except ImportError as e:
        print(f"RESULT: cannot import winpty: {e}")
        return 1
    bash_script = ('if [ -t 0 ]; then echo T0=yes; else echo T0=no; fi; '
                   'if (exec </dev/tty) 2>/dev/null; then echo DEVTTY=yes; else echo DEVTTY=no; fi; '
                   'read -r x; printf "GOT[%s]\\n" "$x"')
    ps_script = ('Write-Output ("REDIRECTED=" + [Console]::IsInputRedirected); '
                 'Write-Output ("USERINTERACTIVE=" + [Environment]::UserInteractive); '
                 '$l = [Console]::ReadLine(); Write-Output ("GOT[" + $l + "]")')
    for name, argv in (("git-bash", [bash, "-c", bash_script]),
                       ("pwsh", [pwsh, "-NoProfile", "-Command", ps_script])):
        for label, keys in (("CR", "abc\r"), ("LF", "abc\n")):
            try:
                status, text = run_pty(argv, keys)
            except Exception as e:  # noqa: BLE001 -- diagnostic: report and go on
                print(f"[{name} {label}] spawn failed: {type(e).__name__}: {e}")
                continue
            lines = [ln for ln in text.replace("\r", "\n").split("\n") if ln.strip()]
            print(f"[{name} {label}] exit={status} out={lines[-6:]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
